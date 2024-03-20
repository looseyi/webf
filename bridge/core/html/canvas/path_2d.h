/*
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef WEBF_CORE_HTML_CANVAS_CANVAS_PATH_2D_H_
#define WEBF_CORE_HTML_CANVAS_CANVAS_PATH_2D_H_

#include "bindings/qjs/script_wrappable.h"
#include "core/binding_object.h"
#include "core/geometry/dom_matrix.h"

namespace webf {

class Path2D : public BindingObject {
  DEFINE_WRAPPERTYPEINFO();

 public:
  using ImplType = Path2D*;
  static Path2D* Create(ExecutingContext* context, ExceptionState& exception_state);
  Path2D() = delete;

  explicit Path2D(ExecutingContext* context, ExceptionState& exception_state);

  void addPath(Path2D* path, DOMMatrix* dom_matrix, ExceptionState& exception_state);
  
  NativeValue HandleCallFromDartSide(const AtomicString& method,
                                    int32_t argc,
                                    const NativeValue* argv,
                                    Dart_Handle dart_object) override;

  private:
};  // namespace webf

}

#endif  // WEBF_CORE_HTML_CANVAS_CANVAS_PATH_2D_H_a