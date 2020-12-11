/*
 * Copyright (C) 2020 Alibaba Inc. All rights reserved.
 * Author: Kraken Team.
 */

#include "anchor_element.h"
#include "foundation/ui_command_queue.h"
#include "foundation/ui_command_callback_queue.h"

namespace kraken::binding::jsc {

JSAnchorElement::JSAnchorElement(JSContext *context) : JSElement(context) {}

std::unordered_map<JSContext *, JSAnchorElement *> JSAnchorElement::instanceMap {};

JSAnchorElement *JSAnchorElement::instance(JSContext *context) {
  if (instanceMap.count(context) == 0) {
    instanceMap[context] = new JSAnchorElement(context);
  }
  return instanceMap[context];
}

JSAnchorElement::~JSAnchorElement() {
  instanceMap.erase(context);
}

JSObjectRef JSAnchorElement::instanceConstructor(JSContextRef ctx, JSObjectRef constructor, size_t argumentCount,
                                                 const JSValueRef *arguments, JSValueRef *exception) {
  auto instance = new AnchorElementInstance(this);
  return instance->object;
}

JSAnchorElement::AnchorElementInstance::AnchorElementInstance(JSAnchorElement *jsAnchorElement)
  : ElementInstance(jsAnchorElement, "a", false), nativeAnchorElement(new NativeAnchorElement(nativeElement)) {
  std::string tagName = "a";
  NativeString args_01{};
  buildUICommandArgs(tagName, args_01);
  foundation::UICommandTaskMessageQueue::instance(context->getContextId())
    ->registerCommand(eventTargetId, UICommand::createElement, args_01, nativeAnchorElement);
}

JSValueRef JSAnchorElement::AnchorElementInstance::getProperty(std::string &name, JSValueRef *exception) {
  auto propertyMap = getAnchorElementPropertyMap();
  if (propertyMap.count(name) > 0) {
    auto property = propertyMap[name];
    switch (property) {
    case AnchorElementProperty::kHref:
      return JSValueMakeString(_hostClass->ctx, _href);
    case AnchorElementProperty::kTarget:
      return JSValueMakeString(_hostClass->ctx, _target);
    }
  }

  return ElementInstance::getProperty(name, exception);
}

void JSAnchorElement::AnchorElementInstance::setProperty(std::string &name, JSValueRef value, JSValueRef *exception) {
  auto propertyMap = getAnchorElementPropertyMap();
  auto property = propertyMap[name];
  if (property == AnchorElementProperty::kHref) {
    _href = JSValueToStringCopy(_hostClass->ctx, value, exception);
    JSStringRetain(_href);

    std::string hrefString = JSStringToStdString(_href);

    NativeString args_01{};
    NativeString args_02{};
    buildUICommandArgs(name, hrefString, args_01, args_02);
    foundation::UICommandTaskMessageQueue::instance(_hostClass->contextId)
      ->registerCommand(eventTargetId, UICommand::setProperty, args_01, args_02, nullptr);
  } else if (property == AnchorElementProperty::kTarget) {
    _target = JSValueToStringCopy(_hostClass->ctx, value, exception);
    JSStringRetain(_target);

    NativeString args_01{};
    NativeString args_02{};
    buildUICommandArgs(name, _target, args_01, args_02);
    foundation::UICommandTaskMessageQueue::instance(_hostClass->contextId)
      ->registerCommand(eventTargetId, UICommand::setProperty, args_01, args_02, nullptr);
  } else {
    ElementInstance::setProperty(name, value, exception);
  }
}

void JSAnchorElement::AnchorElementInstance::getPropertyNames(JSPropertyNameAccumulatorRef accumulator) {
  ElementInstance::getPropertyNames(accumulator);

  for (auto &property : getAnchorElementPropertyNames()) {
    JSPropertyNameAccumulatorAddName(accumulator, property);
  }
}

std::array<JSStringRef, 2> &JSAnchorElement::AnchorElementInstance::getAnchorElementPropertyNames() {
  static std::array<JSStringRef, 2> propertyNames{
    JSStringCreateWithUTF8CString("href"),
    JSStringCreateWithUTF8CString("target"),
  };
  return propertyNames;
}
const std::unordered_map<std::string, JSAnchorElement::AnchorElementInstance::AnchorElementProperty> &
JSAnchorElement::AnchorElementInstance::getAnchorElementPropertyMap() {
  static const std::unordered_map<std::string, AnchorElementProperty> propertyMap{
    {"href", AnchorElementProperty::kHref}, {"target", AnchorElementProperty::kTarget}};
  return propertyMap;
}

JSAnchorElement::AnchorElementInstance::~AnchorElementInstance() {
  ::foundation::UICommandCallbackQueue::instance(contextId)->registerCallback([](void *ptr) {
    delete reinterpret_cast<NativeAnchorElement *>(ptr);
  }, nativeAnchorElement);
  if (_target != nullptr) JSStringRelease(_target);
  if (_href != nullptr) JSStringRelease(_href);
}

} // namespace kraken::binding::jsc