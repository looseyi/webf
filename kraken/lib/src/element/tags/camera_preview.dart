/*
 * Copyright (C) 2019 Alibaba Inc. All rights reserved.
 * Author: Kraken Team.
 */

import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:kraken/element.dart';
import 'package:kraken/rendering.dart';
import 'package:kraken/css.dart';
import 'package:kraken_camera/camera.dart';

const String CAMERA_PREVIEW = 'CAMERA-PREVIEW';

final Map<String, dynamic> _defaultStyle = {
  WIDTH: ELEMENT_DEFAULT_WIDTH,
  HEIGHT: ELEMENT_DEFAULT_HEIGHT,
};

bool camerasDetected = false;
List<CameraDescription> cameras = [];

Future<CameraDescription> detectCamera(String lens) async {
  if (lens == null) lens = 'back';

  if (!camerasDetected) {
    try {
      // Obtain a list of the available cameras on the device.
      cameras = await availableCameras();
    } on CameraException catch (err) {
      // No available camera devices, need to fallback.
      print('Camera Exception $err');
    }
    camerasDetected = true;
  }

  for (CameraDescription description in cameras) {
    if (description.lensDirection == parseCameraLensDirection(lens)) {
      return description;
    }
  }

  return null;
}

class CameraPreviewElement extends Element {
  CameraPreviewElement(int targetId)
      : super(targetId: targetId, tagName: CAMERA_PREVIEW, defaultStyle: _defaultStyle, isIntrinsicBox: true) {
    sizedBox = RenderConstrainedBox(
      additionalConstraints: BoxConstraints.loose(Size(
        CSSLength.toDisplayPortValue(ELEMENT_DEFAULT_WIDTH),
        CSSLength.toDisplayPortValue(ELEMENT_DEFAULT_HEIGHT),
      )),
    );

    style.addStyleChangeListener(_propertyChangedListener);
    addChild(sizedBox);
  }

  bool enableAudio = false;
  bool isFallback = false;
  RenderConstrainedBox sizedBox;
  CameraDescription cameraDescription;
  TextureBox renderTextureBox;
  CameraController controller;
  List<VoidCallback> detectedFunc = [];

  void waitUntilReady(VoidCallback fn) {
    detectedFunc.add(fn);
  }

  void _invokeReady() {
    for (VoidCallback fn in detectedFunc) fn();
    detectedFunc = [];
  }

  /// Element attribute width
  double _width;
  double get width => _width;
  set width(double newValue) {
    if (newValue != null) {
      _width = newValue;
      sizedBox.additionalConstraints = BoxConstraints.expand(
        width: width,
        height: height ?? width / aspectRatio,
      );
    }
  }

  /// Element attribute height
  double _height;
  double get height => _height;
  set height(double newValue) {
    if (newValue != null) {
      _height = newValue;
      sizedBox.additionalConstraints = BoxConstraints.expand(
        width: width ?? height * aspectRatio,
        height: height,
      );
    }
  }

  double get aspectRatio {
    double _aspectRatio = 1.0;
    if (width != null && height != null) {
      _aspectRatio = width / height;
    } else if (controller != null) {
      _aspectRatio = controller.value.aspectRatio;
    }

    // sensorOrientation can be [0, 90, 180, 270],
    // while 90 / 270 is reverted to width and height.
    if ((cameraDescription?.sensorOrientation ?? 0 / 90) % 2 == 1) {
      _aspectRatio = 1 / _aspectRatio;
    }
    return _aspectRatio;
  }

  ResolutionPreset _resolutionPreset;
  ResolutionPreset get resolutionPreset => _resolutionPreset;
  set resolutionPreset(ResolutionPreset value) {
    if (_resolutionPreset != value) {
      _resolutionPreset = value;
      _initCamera();
    }
  }

  void _initCamera() async {
    if (cameraDescription != null) {
      TextureBox textureBox = await createCameraTextureBox(cameraDescription);
      _invokeReady();
      sizedBox.child = RenderAspectRatio(aspectRatio: aspectRatio, child: textureBox);
    }
  }

  void _initCameraWithLens(String lens) async {
    cameraDescription = await detectCamera(lens);
    if (cameraDescription == null) {
      isFallback = true;
      _invokeReady();
      sizedBox.child = _buildFallbackView('Camera Fallback View');
    } else {
      await _initCamera();
    }
  }

  RenderBox _buildFallbackView(String description) {
    assert(description != null);

    TextStyle style = getTextStyle(CSSStyleDeclaration()).copyWith(backgroundColor: Color(0xFFFFFFFF));
    return RenderFallbackViewBox(
      child: RenderParagraph(
        TextSpan(text: description, style: style),
        textDirection: TextDirection.ltr,
      ),
    );
  }

  Future<TextureBox> createCameraTextureBox(CameraDescription cameraDescription) async {
    this.cameraDescription = cameraDescription;
    await _createCameraController();
    return TextureBox(textureId: controller.textureId);
  }

  Future<void> _createCameraController({
    ResolutionPreset resoluton = ResolutionPreset.medium,
    bool enableAudio = false,
  }) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = CameraController(
      cameraDescription,
      resoluton,
      enableAudio: enableAudio,
    );

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (isConnected) {
        renderLayoutBox.markNeedsPaint();
      }
      if (controller.value.hasError) {
        print('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (err) {
      print('Error while initializing camera controller: $err');
    }
  }

  @override
  void setProperty(String key, value) async {
    super.setProperty(key, value);

    if (isFallback || controller != null) {
      _setProperty(key, value);
    } else {
      waitUntilReady(() {
        _setProperty(key, value);
      });
    }
  }

  void _propertyChangedListener(String key, String original, String present) {
    switch (key) {
      case 'width':
        // Trigger width setter to invoke rerender.
        width = CSSLength.toDisplayPortValue(present) ?? width;
        break;
      case 'height':
        // Trigger height setter to invoke rerender.
        height = CSSLength.toDisplayPortValue(present) ?? height;
        break;
      default:
    }
  }

  void _setProperty(String key, value) {
    if (key == 'resolution-preset') {
      resolutionPreset = getResolutionPreset(value);
    } else if (key == 'width') {
      // <camera-preview width="300" />
      // Width and height is united with pixel.
      value = value.toString() + 'px';
      width = CSSLength.toDisplayPortValue(value) ?? width;
    } else if (key == 'height') {
      value = value.toString() + 'px';
      height = CSSLength.toDisplayPortValue(value) ?? height;
    } else if (key == 'lens') {
      _initCameraWithLens(value);
    } else if (key == 'sensor-orientation') {
      _updateSensorOrientation(value);
    }
  }

  void _updateSensorOrientation(value) async {
    int sensorOrientation = CSSNumber(value.toString()).toInt();
    cameraDescription = cameraDescription.copyWith(sensorOrientation: sensorOrientation);
    await _initCamera();
  }
}

/// Returns the resolution preset from string.
ResolutionPreset getResolutionPreset(String preset) {
  switch (preset) {
    case 'max':
      return ResolutionPreset.max;
    case 'ultraHigh':
      return ResolutionPreset.ultraHigh;
    case 'veryHigh':
      return ResolutionPreset.veryHigh;
    case 'high':
      return ResolutionPreset.high;
    case 'low':
      return ResolutionPreset.low;
    case 'medium':
    default:
      return ResolutionPreset.medium;
  }
}