/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include "ui_command_buffer.h"
#include "core/dart_methods.h"
#include "core/executing_context.h"
#include "foundation/logging.h"
#include "include/webf_bridge.h"

namespace webf {

UICommandBuffer::UICommandBuffer(ExecutingContext* context)
    : context_(context), buffer_((UICommandItem*)malloc(sizeof(UICommandItem) * MAXIMUM_UI_COMMAND_SIZE)) {}

UICommandBuffer::~UICommandBuffer() {
  free(buffer_);
}

void UICommandBuffer::addCommand(UICommand type,
                                 std::unique_ptr<SharedNativeString>&& args_01,
                                 void* nativePtr,
                                 void* nativePtr2,
                                 bool request_ui_update) {
  UICommandItem item{static_cast<int32_t>(type), args_01.get(), nativePtr, nativePtr2};
  addCommand(item, request_ui_update);
}

void UICommandBuffer::addCommand(const UICommandItem& item, bool request_ui_update) {
  WEBF_LOG(VERBOSE) << " DART ISOLATE CONTEXT: " << context_->dartIsolateContext();
  if (UNLIKELY(!context_->dartIsolateContext()->valid())) {
    return;
  }

  if (size_ >= max_size_) {
    buffer_ = (UICommandItem*)realloc(buffer_, sizeof(UICommandItem) * max_size_ * 2);
    max_size_ = max_size_ * 2;
  }

#if FLUTTER_BACKEND
  if (UNLIKELY(request_ui_update && !update_batched_ && context_->IsContextValid())) {
    WEBF_LOG(VERBOSE) << context_->dartMethodPtr();

    context_->dartMethodPtr()->requestBatchUpdate(context_->is_dedicated(), context_->contextId());
    update_batched_ = true;
  }
#endif

  buffer_[size_] = item;
  size_++;
}

UICommandItem* UICommandBuffer::data() {
  return buffer_;
}

int64_t UICommandBuffer::size() {
  return size_;
}

bool UICommandBuffer::empty() {
  return size_ == 0;
}

void UICommandBuffer::clear() {
  size_ = 0;
  memset(buffer_, 0, sizeof(buffer_));
  update_batched_ = false;
}

}  // namespace webf
