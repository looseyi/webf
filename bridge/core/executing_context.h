/*
 * Copyright (C) 2021 Alibaba Inc. All rights reserved.
 * Author: Kraken Team.
 */

#ifndef KRAKENBRIDGE_JS_CONTEXT_H
#define KRAKENBRIDGE_JS_CONTEXT_H

#include <quickjs/list.h>
#include <quickjs/quickjs.h>
#include <atomic>
#include <cassert>
#include <cmath>
#include <cstring>
#include <locale>
#include <memory>
#include <mutex>
#include <unordered_map>
#include "bindings/qjs/garbage_collected.h"
#include "bindings/qjs/rejected_promises.h"
#include "bindings/qjs/script_value.h"
#include "bindings/qjs/binding_initializer.h"
#include "foundation/macros.h"
#include "foundation/ui_command_buffer.h"

#include "dart_methods.h"
#include "executing_context_data.h"
#include "frame/dom_timer_coordinator.h"
#include "frame/module_listener_container.h"
#include "frame/module_callback_coordinator.h"

namespace kraken {

struct NativeByteCode {
  uint8_t* bytes;
  int32_t length;
};

class ExecutionContext;
class Document;

using JSExceptionHandler = std::function<void(ExecutionContext* context, const char* message)>;

std::string jsAtomToStdString(JSContext* ctx, JSAtom atom);

static inline bool isNumberIndex(const std::string& name) {
  if (name.empty())
    return false;
  char f = name[0];
  return f >= '0' && f <= '9';
}

struct PromiseContext {
  void* data;
  ExecutionContext* context;
  JSValue resolveFunc;
  JSValue rejectFunc;
  JSValue promise;
  list_head link;
};

bool isContextValid(int32_t contextId);

class ExecutionContextGCTracker : public GarbageCollected<ExecutionContextGCTracker> {
 public:
  static JSClassID contextGcTrackerClassId;

  void trace(GCVisitor* visitor) const override;
  void dispose() const override;

 private:
};

// An environment in which script can execute. This class exposes the common
// properties of script execution environments on the kraken.
// Window : Document : ExecutionContext = 1 : 1 : 1 at any point in time.
class ExecutionContext {
 public:
  ExecutionContext() = delete;
  ExecutionContext(int32_t contextId, const JSExceptionHandler& handler, void* owner);
  ~ExecutionContext();

  bool evaluateJavaScript(const uint16_t* code, size_t codeLength, const char* sourceURL, int startLine);
  bool evaluateJavaScript(const char16_t* code, size_t length, const char* sourceURL, int startLine);
  bool evaluateJavaScript(const char* code, size_t codeLength, const char* sourceURL, int startLine);
  bool evaluateByteCode(uint8_t* bytes, size_t byteLength);
  bool isValid() const;
  JSValue global();
  JSContext* ctx();
  static JSRuntime* runtime();
  FORCE_INLINE int32_t getContextId() const { return contextId; };
  void* getOwner();
  bool handleException(JSValue* exc);
  bool handleException(ScriptValue* exc);
  void reportError(JSValueConst error);
  void drainPendingPromiseJobs();
  void defineGlobalProperty(const char* prop, JSValueConst value);
  ExecutionContextData* contextData();
  uint8_t* dumpByteCode(const char* code, uint32_t codeLength, const char* sourceURL, size_t* bytecodeLength);

  // Gets the DOMTimerCoordinator which maintains the "active timer
  // list" of tasks created by setTimeout and setInterval. The
  // DOMTimerCoordinator is owned by the ExecutionContext and should
  // not be used after the ExecutionContext is destroyed.
  DOMTimerCoordinator* timers();

  // Gets the ModuleListeners which registered by `kraken.addModuleListener API`.
  ModuleListenerContainer* moduleListeners();

  // Gets the ModuleCallbacks which from the 4th parameter of `kraken.invokeModule` function.
  ModuleCallbackCoordinator* moduleCallbacks();

  FORCE_INLINE Document* document() { return m_document; };
  FORCE_INLINE UICommandBuffer* uiCommandBuffer() { return &m_commandBuffer; };
  FORCE_INLINE std::unique_ptr<DartMethodPointer>& dartMethodPtr() { return m_dartMethodPtr; }

  void trace(GCVisitor* visitor);

  std::chrono::time_point<std::chrono::system_clock> timeOrigin;
  std::unordered_map<std::string, void*> constructorMap;

  int32_t uniqueId;
  struct list_head node_job_list;
  struct list_head module_job_list;
  struct list_head module_callback_job_list;
  struct list_head promise_job_list;
  struct list_head native_function_job_list;

  static void dispatchGlobalUnhandledRejectionEvent(ExecutionContext* context, JSValueConst promise, JSValueConst error);
  static void dispatchGlobalRejectionHandledEvent(ExecutionContext* context, JSValueConst promise, JSValueConst error);
  static void dispatchGlobalErrorEvent(ExecutionContext* context, JSValueConst error);

  // Bytecodes which registered by kraken plugins.
  static std::unordered_map<std::string, NativeByteCode> pluginByteCode;

 private:
  static void promiseRejectTracker(JSContext* ctx, JSValueConst promise, JSValueConst reason, JS_BOOL is_handled, void* opaque);

  int32_t contextId;
  JSExceptionHandler _handler;
  void* owner;
  JSValue globalObject{JS_NULL};
  bool ctxInvalid_{false};
  JSContext* m_ctx{nullptr};
  Document* m_document{nullptr};
  DOMTimerCoordinator m_timers;
  ModuleListenerContainer m_moduleListeners;
  ModuleCallbackCoordinator m_moduleCallbacks;
  ExecutionContextGCTracker* m_gcTracker{nullptr};
  ExecutionContextData m_data{this};
  UICommandBuffer m_commandBuffer{this};
  std::unique_ptr<DartMethodPointer> m_dartMethodPtr = std::make_unique<DartMethodPointer>();
  RejectedPromises m_rejectedPromise;
};

// The read object's method or properties via Proxy, we should redirect this_val from Proxy into target property of
// proxy object.
static JSValue handleCallThisOnProxy(JSContext* ctx, JSValueConst this_val, int argc, JSValueConst* argv, int data_len, JSValueConst* data) {
  JSValue f = data[0];
  JSValue result;
  if (JS_IsProxy(this_val)) {
    result = JS_Call(ctx, f, JS_GetProxyTarget(this_val), argc, argv);
  } else {
    // If this_val is undefined or null, this_val should set to globalThis.
    if (JS_IsUndefined(this_val) || JS_IsNull(this_val)) {
      this_val = JS_GetGlobalObject(ctx);
      result = JS_Call(ctx, f, this_val, argc, argv);
      JS_FreeValue(ctx, this_val);
    } else {
      result = JS_Call(ctx, f, this_val, argc, argv);
    }
  }
  return result;
}

class ObjectProperty {
  KRAKEN_DISALLOW_COPY_ASSIGN_AND_MOVE(ObjectProperty);

 public:
  ObjectProperty() = delete;

  // Define an property on object with a JSValue.
  explicit ObjectProperty(ExecutionContext* context, JSValueConst thisObject, const char* property, JSValue value) : m_value(value) {
    JS_DefinePropertyValueStr(context->ctx(), thisObject, property, value, JS_PROP_ENUMERABLE);
  }

  JSValue value() const { return m_value; }

 private:
  JSValue m_value{JS_NULL};
};

// Property define helpers
void installFunctionProperty(ExecutionContext* context, JSValueConst thisObject, const char* functionName, JSCFunction function, int argc);
void installPropertyGetterSetter(ExecutionContext* context, JSValueConst thisObject, const char* property, JSCFunction getterFunction, JSCFunction setterFunction);
void installPropertyGetter(ExecutionContext* context, JSValueConst thisObject, const char* property, JSCFunction getterFunction);

class JSValueHolder {
 public:
  JSValueHolder() = delete;
  explicit JSValueHolder(JSContext* ctx, JSValue value) : m_value(value), m_ctx(ctx){};
  ~JSValueHolder() { JS_FreeValue(m_ctx, m_value); }
  inline void value(JSValue value) {
    if (!JS_IsNull(m_value)) {
      JS_FreeValue(m_ctx, m_value);
    }
    m_value = JS_DupValue(m_ctx, value);
  };
  inline JSValue value() const { return JS_DupValue(m_ctx, m_value); }

 private:
  JSContext* m_ctx{nullptr};
  JSValue m_value{JS_NULL};
};

std::unique_ptr<ExecutionContext> createJSContext(int32_t contextId, const JSExceptionHandler& handler, void* owner);

void buildUICommandArgs(JSContext* ctx, JSValue key, NativeString& args_01);

// JS array operation utilities.
void arrayPushValue(JSContext* ctx, JSValue array, JSValue val);
void arrayInsert(JSContext* ctx, JSValue array, uint32_t start, JSValue targetValue);
int32_t arrayGetLength(JSContext* ctx, JSValue array);
int32_t arrayFindIdx(JSContext* ctx, JSValue array, JSValue target);
void arraySpliceValue(JSContext* ctx, JSValue array, uint32_t start, uint32_t deleteCount);
void arraySpliceValue(JSContext* ctx, JSValue array, uint32_t start, uint32_t deleteCount, JSValue replacedValue);

// JS object operation utilities.
JSValue objectGetKeys(JSContext* ctx, JSValue obj);

}  // namespace kraken

#endif  // KRAKENBRIDGE_JS_CONTEXT_H
