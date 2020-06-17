import 'package:flutter/rendering.dart';
import 'package:kraken/element.dart';
import 'package:kraken/rendering.dart';
import 'package:kraken/css.dart';

// CSS Positioned Layout: https://drafts.csswg.org/css-position/

enum CSSPositionType {
  static,
  relative,
  absolute,
  fixed,
  sticky,
}

CSSPositionType resolvePositionFromStyle(CSSStyleDeclaration style) {
  return resolveCSSPosition(style['position']);
}

CSSPositionType resolveCSSPosition(String input) {
  switch (input) {
    case 'relative':
      return CSSPositionType.relative;
    case 'absolute':
      return CSSPositionType.absolute;
    case 'fixed':
      return CSSPositionType.fixed;
    case 'sticky':
      return CSSPositionType.sticky;
  }
  return CSSPositionType.static;
}

void applyRelativeOffset(Offset relativeOffset, RenderBox renderBox, CSSStyleDeclaration style) {
  BoxParentData boxParentData = renderBox?.parentData;
  if (boxParentData != null) {
    Offset styleOffset;
    // Text node does not have relative offset
    if (renderBox is! RenderTextBox && style != null) {
      styleOffset = getRelativeOffset(style);
    }

    if (relativeOffset != null) {
      if (styleOffset != null) {
        boxParentData.offset = relativeOffset.translate(styleOffset.dx, styleOffset.dy);
      } else {
        boxParentData.offset = relativeOffset;
      }
    } else {
      boxParentData.offset = styleOffset;
    }
  }
}

Offset getRelativeOffset(CSSStyleDeclaration style) {
  CSSPositionType position = resolvePositionFromStyle(style);
  if (position == CSSPositionType.relative) {
    double dx;
    double dy;
    if (style.contains('left')) {
      dx = CSSLength.toDisplayPortValue(style['left']);
    } else if (style.contains('right')) {
      var _dx = CSSLength.toDisplayPortValue(style['right']);
      if (_dx != null) dx = -_dx;
    }

    if (style.contains('top')) {
      dy = CSSLength.toDisplayPortValue(style['top']);
    } else if (style.contains('bottom')) {
      var _dy = CSSLength.toDisplayPortValue(style['bottom']);
      if (_dy != null) dy = -_dy;
    }

    if (dx != null || dy != null) {
      return Offset(dx ?? 0, dy ?? 0);
    }
  }
  return null;
}

void layoutPositionedChild(Element parentElement, RenderBox parent, RenderBox child) {
  BoxConstraints parentConstraints = parentElement.renderDecoratedBox.constraints;
  double width = parentConstraints.minWidth;
  double height = parentConstraints.minHeight;

  final RenderLayoutParentData childParentData = child.parentData;

  // Default to no constraints. (0 - infinite)
  BoxConstraints childConstraints = const BoxConstraints();

  Size trySize = parentConstraints.biggest;
  Size parentSize = trySize.isInfinite ? parentConstraints.smallest : trySize;

  // if child has no width, calculate width by left and right.
  if (childParentData.width == 0.0 && childParentData.left != null && childParentData.right != null) {
    childConstraints = childConstraints.tighten(width: parentSize.width - childParentData.left - childParentData.right);
  }
  // if child has not height, should be calculate height by top and bottom
  if (childParentData.height == 0.0 && childParentData.top != null && childParentData.bottom != null) {
    childConstraints =
      childConstraints.tighten(height: parentSize.height - childParentData.top - childParentData.bottom);
  }

  child.layout(childConstraints, parentUsesSize: true);

}

void setPositionedChildOffset(Element parentElement, RenderBox parent, RenderBox child, Size parentSize) {
  BoxConstraints parentConstraints = parentElement.renderDecoratedBox.constraints;
  double width = parentSize.width;
  double height = parentSize.height;

  final RenderLayoutParentData childParentData = child.parentData;
  // Calc x,y by parentData.
  double x, y;

  EdgeInsetsGeometry padding = parentElement.renderPadding.padding;
  EdgeInsets resolvedPadding = padding.resolve(TextDirection.ltr);

  // Offset to global coordinate system of base
  if (childParentData.position == CSSPositionType.absolute || childParentData.position == CSSPositionType.fixed) {
    Offset baseOffset =
      childParentData.renderPositionHolder.localToGlobal(Offset.zero) - parent.localToGlobal(Offset.zero);

    // Positioned element is positioned relative to the edge of
    // padding box of containing block
    // https://www.w3.org/TR/CSS2/visudet.html#containing-block-details
    double top = childParentData.top != null ? (childParentData.top - resolvedPadding.top) :
      baseOffset.dy;
    if (childParentData.top == null && childParentData.bottom != null) {
      top = height - child.size.height - (childParentData.bottom ?? 0);
    }

    double left = childParentData.left != null ? (childParentData.left - resolvedPadding.left):
      baseOffset.dx;
    if (childParentData.left == null && childParentData.right != null) {
      left = width - child.size.width - (childParentData.right ?? 0);
    }

    x = left;
    y = top;
  }

  childParentData.offset = Offset(x ?? 0, y ?? 0);
}
