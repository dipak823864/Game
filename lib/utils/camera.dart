import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import 'dart:math' as math;

class Camera {
  Vector3 position;
  Vector3 target;
  Vector3 up;
  double fov;
  double aspectRatio;
  double near;
  double far;

  Camera({
    required this.position,
    required this.target,
    required this.up,
    this.fov = 60.0,
    this.aspectRatio = 1.0,
    this.near = 0.1,
    this.far = 400.0,
  });

  Matrix4 get viewMatrix {
    return makeViewMatrix(position, target, up);
  }

  Matrix4 get projectionMatrix {
    return makePerspectiveMatrix(math.pi * fov / 180.0, aspectRatio, near, far);
  }

  Offset? project(Vector3 worldPoint, Size screenSize) {
    Vector4 clipSpace = (projectionMatrix * viewMatrix) * Vector4(worldPoint.x, worldPoint.y, worldPoint.z, 1.0);

    if (clipSpace.w == 0) return null;
    double ndcX = clipSpace.x / clipSpace.w;
    double ndcY = clipSpace.y / clipSpace.w;

    if (clipSpace.w < 0) return null; // Behind camera

    double screenX = (ndcX + 1.0) / 2.0 * screenSize.width;
    double screenY = (1.0 - ndcY) / 2.0 * screenSize.height;

    return Offset(screenX, screenY);
  }
}
