/*
 * Copyright (C) 2019-present Alibaba Inc. All rights reserved.
 * Author: Kraken Team.
 */
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:kraken/foundation.dart';
import 'package:kraken/rendering.dart';
import 'package:kraken/css.dart';

// CSS Box Model: https://drafts.csswg.org/css-box-4/
// CSS Backgrounds and Borders: https://drafts.csswg.org/css-backgrounds/

final RegExp _spaceRegExp = RegExp(r'\s+');

/// - background
/// - border
mixin CSSDecoratedBoxMixin {

  void updateRenderDecoratedBox(RenderBoxModel renderBoxModel, CSSStyleDeclaration style, String property) {
    CSSBoxDecoration cssBoxDecoration = renderBoxModel.cssBoxDecoration;

    if (cssBoxDecoration != null) {
      // Update by property
      if (property.startsWith(BACKGROUND)) {
        _updateBackground(renderBoxModel, style, property);
      } else if (property.endsWith('Radius')) {
        _updateBorderRadius(renderBoxModel, style, property);
      } else if (property.startsWith(BORDER)) {
        _updateBorder(renderBoxModel, style, property);
      } else if (property == BOX_SHADOW) {
        _updateBoxShadow(renderBoxModel, style, property);
      }
    } else {
      cssBoxDecoration = getCSSBoxDecoration(style);
      renderBoxModel.cssBoxDecoration = cssBoxDecoration;
      if (cssBoxDecoration == null) return;

      renderBoxModel.decoration = cssBoxDecoration.toBoxDecoration();
    }
  }

  void _updateBoxShadow(
    RenderBoxModel renderBoxModel,
    CSSStyleDeclaration style,
    String property) {

    List<BoxShadow> boxShadow = getBoxShadow(style);
    renderBoxModel.decoration = renderBoxModel.decoration.copyWith(boxShadow: boxShadow);
  }

  void _updateBackground(
      RenderBoxModel renderBoxModel,
      CSSStyleDeclaration style,
      String property) {
    
    BoxDecoration oldBox = renderBoxModel.decoration;

    if (property == BACKGROUND || property == BACKGROUND_COLOR) {
      Color bgColor = CSSBackground.getBackgroundColor(style);
      // If there has gradient, background color will not work
      if (bgColor != null && oldBox.gradient == null) {
        renderBoxModel.decoration = renderBoxModel.decoration.copyWith(color: bgColor);
      }
      if (property == BACKGROUND_COLOR) return;
    }

    DecorationImage decorationImage;
    Gradient gradient;

    List<CSSFunctionalNotation> methods = CSSFunction.parseFunction(style[BACKGROUND_IMAGE]);
    for (CSSFunctionalNotation method in methods) {
      if (method.name == URL) {
        decorationImage = CSSBackground.getDecorationImage(style, method);
      } else {
        gradient = CSSBackground.getBackgroundGradient(method);
      }
    }

    if (CSSBackground.hasScrollBackgroundImage(style)) {
      renderBoxModel.decoration = renderBoxModel.decoration.copyWith(gradient: gradient, image: decorationImage);
    } else if (CSSBackground.hasLocalBackgroundImage(style)) {
      // @TODO: support local background image
    }
  }

  static Map _borderRadiusMapping = {
    BORDER_TOP_LEFT_RADIUS: 0,
    BORDER_TOP_RIGHT_RADIUS: 1,
    BORDER_BOTTOM_LEFT_RADIUS: 2,
    BORDER_BOTTOM_RIGHT_RADIUS: 3
  };

  // Add border radius transition listener
  void _updateBorderRadius(
      RenderBoxModel renderBoxModel,
      CSSStyleDeclaration style,
      String property) {

      // topLeft topRight bottomRight bottomLeft
      int index = _borderRadiusMapping[property];

      if (index != null) {
        Radius newRadius = CSSBorderRadius.getRadius(style[property]);
        BorderRadius borderRaduis = renderBoxModel.decoration.borderRadius as BorderRadius;
        renderBoxModel.decoration = renderBoxModel.decoration.copyWith(borderRadius: BorderRadius.only(
          topLeft: index == 0 ? newRadius : borderRaduis.topLeft,
          topRight: index == 1 ? newRadius : borderRaduis.topRight,
          bottomRight: index == 2 ? newRadius : borderRaduis.bottomRight,
          bottomLeft: index == 3 ? newRadius : borderRaduis.bottomLeft,
        ));
      } else {
        List<Radius> borderRadius = _getBorderRadius(style);

        renderBoxModel.decoration = renderBoxModel.decoration.copyWith(borderRadius: BorderRadius.only(
          topLeft: borderRadius[0],
          topRight: borderRadius[1],
          bottomRight: borderRadius[2],
          bottomLeft: borderRadius[3],
        ));
      }
  }

  void _updateBorder(
      RenderBoxModel renderBoxModel,
      CSSStyleDeclaration style,
      String property) {

    Border border = renderBoxModel.decoration.border as Border;
    if (border != null) {
      BorderSide left =  border.left;
      BorderSide top =  border.top;
      BorderSide right =  border.right;
      BorderSide bottom =  border.bottom;
      bool updateAll = false;

      if (property.contains(LEFT)) {
        left = CSSBorderSide.getBorderSide(style, CSSBorderSide.LEFT);
      } else if (property.contains(TOP)) {
        top = CSSBorderSide.getBorderSide(style, CSSBorderSide.TOP);
      } else if (property.contains(RIGHT)) {
        right = CSSBorderSide.getBorderSide(style, CSSBorderSide.RIGHT);
      } else if (property.contains(BOTTOM)) {
        bottom = CSSBorderSide.getBorderSide(style, CSSBorderSide.BOTTOM);
      } else {
        updateAll = true;
      }

      if (!updateAll) {
        renderBoxModel.decoration = renderBoxModel.decoration.copyWith(border: Border(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ));
      }
    }

    // Update all border
    List<BorderSide> borderSides = _getBorderSides(style);

    renderBoxModel.decoration = renderBoxModel.decoration.copyWith(border: Border(
      left: borderSides[0],
      top: borderSides[1],
      right: borderSides[2],
      bottom: borderSides[3],
    ));
  }

  List<BorderSide> _getBorderSides(CSSStyleDeclaration style) {
    BorderSide leftSide = CSSBorderSide.getBorderSide(style, CSSBorderSide.LEFT);
    BorderSide topSide = CSSBorderSide.getBorderSide(style, CSSBorderSide.TOP);
    BorderSide rightSide = CSSBorderSide.getBorderSide(style, CSSBorderSide.RIGHT);
    BorderSide bottomSide = CSSBorderSide.getBorderSide(style, CSSBorderSide.BOTTOM);

    bool hasBorder = leftSide != null ||
        topSide != null ||
        rightSide != null ||
        bottomSide != null;

    return hasBorder ? [
      leftSide ?? CSSBorderSide.none,
      topSide ?? CSSBorderSide.none,
      rightSide ?? CSSBorderSide.none,
      bottomSide ?? CSSBorderSide.none] : null;
  }

  List<Radius> _getBorderRadius(CSSStyleDeclaration style) {
    // border radius add inorder topLeft topRight bottomLeft bottomRight
    Radius topLeftRadius = CSSBorderRadius.getRadius(style[BORDER_TOP_LEFT_RADIUS]);
    Radius topRightRadius = CSSBorderRadius.getRadius(style[BORDER_TOP_RIGHT_RADIUS]);
    Radius bottomRightRadius = CSSBorderRadius.getRadius(style[BORDER_BOTTOM_RIGHT_RADIUS]);
    Radius bottomLeftRadius = CSSBorderRadius.getRadius(style[BORDER_BOTTOM_LEFT_RADIUS]);

    bool hasBorderRadius = topLeftRadius != null ||
        topRightRadius != null ||
        bottomRightRadius != null ||
        bottomLeftRadius != null;

    return hasBorderRadius ? [
      topLeftRadius ?? CSSBorderRadius.none,
      topRightRadius ?? CSSBorderRadius.none,
      bottomRightRadius ?? CSSBorderRadius.none,
      bottomLeftRadius ?? CSSBorderRadius.none
    ] : null;
  }

  /// Shorted border property:
  ///   border：<line-width> || <line-style> || <color>
  ///   (<line-width> = <length> | thin | medium | thick), support length now.
  /// Seperated properties:
  ///   borderWidth: <line-width>{1,4}
  ///   borderStyle: none | hidden | dotted | dashed | solid | double | groove | ridge | inset | outset
  ///     (PS. Only support solid now.)
  ///   borderColor: <color>
  CSSBoxDecoration getCSSBoxDecoration(CSSStyleDeclaration style) {

    // Backgroud color
    Color bgColor = CSSBackground.getBackgroundColor(style);
    // Background image
    DecorationImage decorationImage;
    Gradient gradient;
    List<CSSFunctionalNotation> methods = CSSFunction.parseFunction(style[BACKGROUND_IMAGE]);
    for (CSSFunctionalNotation method in methods) {
      if (method.name == URL) {
        decorationImage = CSSBackground.getDecorationImage(style, method);
      } else {
        gradient = CSSBackground.getBackgroundGradient(method);
      }
    }

    List<Radius> borderRadius = _getBorderRadius(style);
    List<BoxShadow> boxShadow = getBoxShadow(style);
    List<BorderSide> borderSides = _getBorderSides(style);

    if (bgColor == null &&
        decorationImage == null &&
        gradient == null &&
        borderSides == null &&
        borderRadius == null &&
        boxShadow == null) {
      return null;
    }

    return CSSBoxDecoration(bgColor, decorationImage, gradient, borderSides, borderRadius, getBoxShadow(style));
  }

  /// Tip: inset not supported.
  List<BoxShadow> getBoxShadow(CSSStyleDeclaration style) {
    List<BoxShadow> boxShadow;
    if (style.contains(BOX_SHADOW)) {
      boxShadow = [];
      var shadows = CSSStyleProperty.getShadowValues(style[BOX_SHADOW]);
      if (shadows != null) {
        shadows.forEach((shadowDefinitions) {
          // Specifies the color of the shadow. If the color is absent, it defaults to currentColor.
          Color color = CSSColor.parseColor(shadowDefinitions[0] ?? style[COLOR]);
          double offsetX = CSSLength.toDisplayPortValue(shadowDefinitions[1]) ?? 0;
          double offsetY = CSSLength.toDisplayPortValue(shadowDefinitions[2]) ?? 0;
          double blurRadius = CSSLength.toDisplayPortValue(shadowDefinitions[3]) ?? 0;
          double spreadRadius = CSSLength.toDisplayPortValue(shadowDefinitions[4]) ?? 0;

          if (color != null) {
            boxShadow.add(BoxShadow(
              offset: Offset(offsetX, offsetY),
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
              color: color,
            ));
          }
        });
      }

      // Tips only debug.
      if (!PRODUCTION && boxShadow.isEmpty) {
        print('[Warning] Wrong style format with boxShadow: ${style[BOX_SHADOW]}');
        print('    Correct syntax: inset? && <length>{2,4} && <color>?');
      }
    }

    return boxShadow;
  }
}

class CSSBorderSide {
  // border default width 3.0
  static double defaultBorderWidth = 3.0;
  static Color defaultBorderColor = CSSColor.initial;
  static String LEFT = 'Left';
  static String RIGHT = 'Right';
  static String TOP = 'Top';
  static String BOTTOM = 'Bottom';

  static double getBorderWidth(String input) {
    // https://drafts.csswg.org/css2/#border-width-properties
    // The interpretation of the first three values depends on the user agent.
    // The following relationships must hold, however:
    // thin ≤ medium ≤ thick.
    double borderWidth;
    switch (input) {
      case THIN:
        borderWidth = 1;
        break;
      case MEDIUM:
        borderWidth = 3;
        break;
      case THICK:
        borderWidth = 5;
        break;
      default:
        borderWidth = CSSLength.toDisplayPortValue(input);
    }
    return borderWidth;
  }

  static bool isValidBorderStyleValue(String value) {
    return value == SOLID || value == NONE;
  }

  static bool isValidBorderWidthValue(String value) {
    return CSSLength.isLength(value) || value == THIN || value == MEDIUM || value == THICK;
  }

  static double getBorderSideWidth(CSSStyleDeclaration style, String side) {
    String property = 'border${side}Width';
    String value = style[property];
    return value.isEmpty ? defaultBorderWidth : getBorderWidth(value);
  }

  static Color getBorderSideColor(CSSStyleDeclaration style, String side) {
    String property = 'border${side}Color';
    String value = style[property] ?? style[COLOR]; // Use current color first
    return value.isEmpty ? defaultBorderColor : CSSColor.parseColor(value);
  }

  static EdgeInsets getBorderEdgeInsets(CSSStyleDeclaration style) {
    double left = 0.0;
    double top = 0.0;
    double bottom = 0.0;
    double right = 0.0;

    if (style[BORDER_LEFT_STYLE].isNotEmpty && style[BORDER_LEFT_STYLE] != NONE) {
      left = getBorderWidth(style[BORDER_LEFT_WIDTH]) ?? defaultBorderWidth;
    }

    if (style[BORDER_TOP_STYLE].isNotEmpty && style[BORDER_TOP_STYLE] != NONE) {
      top = getBorderWidth(style[BORDER_TOP_WIDTH]) ?? defaultBorderWidth;
    }

    if (style[BORDER_RIGHT_STYLE].isNotEmpty && style[BORDER_RIGHT_STYLE] != NONE) {
      right = getBorderWidth(style[BORDER_RIGHT_WIDTH]) ?? defaultBorderWidth;
    }

    if (style[BORDER_BOTTOM_STYLE].isNotEmpty && style[BORDER_BOTTOM_STYLE] != NONE) {
      bottom = getBorderWidth(style[BORDER_BOTTOM_WIDTH]) ?? defaultBorderWidth;
    }

    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  static BorderSide none = BorderSide(color: defaultBorderColor, width: 0.0, style: BorderStyle.none);

  static BorderSide getBorderSide(CSSStyleDeclaration style, String side) {
    BorderStyle borderStyle = CSSBorderStyle.getBorderSideStyle(style, side);
    double width = getBorderSideWidth(style, side);
    // Flutter will print border event if width is 0.0. So we needs to set borderStyle to none to prevent this.
    if (borderStyle == BorderStyle.none || width == 0.0) {
      return null;
    } else {
      return BorderSide(
          color: getBorderSideColor(style, side), width: getBorderSideWidth(style, side), style: borderStyle);
    }
  }
}

class CSSBorderRadius {
  static Radius none = Radius.zero;

  static Radius getRadius(String radius) {
    if (radius.isNotEmpty) {
      // border-top-left-radius: horizontal vertical
      List<String> values = radius.split(_spaceRegExp);

      if (values.length == 1) {
        double circular = CSSLength.toDisplayPortValue(values[0]);
        if (circular != null) return Radius.circular(circular);
      } else if (values.length == 2) {
        double x = CSSLength.toDisplayPortValue(values[0]);
        double y = CSSLength.toDisplayPortValue(values[1]);
        if (x != null && y != null) return Radius.elliptical(x, y);
      }
    }

    return null;
  }
}

class CSSBorderStyle {
  static BorderStyle defaultBorderStyle = BorderStyle.none;
  static BorderStyle getBorderSideStyle(CSSStyleDeclaration style, String side) {
    String property = 'border${side}Style';
    String value = style[property];
    return value.isEmpty ? defaultBorderStyle : getBorderStyle(value);
  }

  static BorderStyle getBorderStyle(String input) {
    BorderStyle borderStyle;
    switch (input) {
      case SOLID:
        borderStyle = BorderStyle.solid;
        break;
      case NONE:
        borderStyle = BorderStyle.none;
        break;
    }
    return borderStyle;
  }
}

class CSSBoxDecoration {
  Color color;
  DecorationImage image;
  Gradient gradient;
  // radius inorder topLeft topRight bottomRight bottomLeft
  List<Radius> radius;
  // side inorder left top right bottom
  List<BorderSide> borderSides;
  List<BoxShadow> boxShadow;

  CSSBoxDecoration(this.color, this.image, this.gradient, this.borderSides, this.radius, this.boxShadow);

  CSSBoxDecoration clone() {
    return CSSBoxDecoration(
        color,
        image,
        gradient,
        // side read inorder left top right bottom
        borderSides != null ? List.of(borderSides) : null,
        // radius read inorder topLeft topRight bottomLeft bottomRight
        radius != null ? List.of(radius) : null,
        boxShadow != null ? List.of(boxShadow) : null);
  }

  BoxDecoration toBoxDecoration() {
    if (gradient != null) {
      color = null;
    }

    Border border;
    if (borderSides != null) {
      // side read inorder left top right bottom
      border = Border(left: borderSides[0], top: borderSides[1], right: borderSides[2], bottom: borderSides[3]);
    }

    BorderRadius borderRadius;
    // Flutter border radius only works when border is uniform.
    if (radius != null && (border == null || border.isUniform)) {
      borderRadius = BorderRadius.only(
        topLeft: radius[0],
        topRight: radius[1],
        bottomRight: radius[2],
        bottomLeft: radius[3],
      );
    }

    return BoxDecoration(
        color: color,
        image: image,
        border: border,
        borderRadius: borderRadius,
        boxShadow: boxShadow,
        gradient: gradient);
  }

  @override
  String toString() {
    return 'CSSBoxDecoration(color: $color, image: $image, borderSides: $borderSides, radius: $radius, boxShadow: $boxShadow, gradient: $gradient)';
  }
}
