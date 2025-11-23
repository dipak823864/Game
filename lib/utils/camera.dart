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

  // Projects a 3D point in world space to 2D screen coordinates.
  // Returns null if the point is behind the camera (clipped).
  Offset? project(Vector3 worldPoint, Size screenSize) {
    // Standard OpenGL pipeline: Clip = P * V * World
    Vector4 clipSpace = (projectionMatrix * viewMatrix) * Vector4(worldPoint.x, worldPoint.y, worldPoint.z, 1.0);

    // Perspective Division: NDC = Clip / w
    if (clipSpace.w == 0) return null; // Avoid division by zero
    double ndcX = clipSpace.x / clipSpace.w;
    double ndcY = clipSpace.y / clipSpace.w;
    double ndcZ = clipSpace.z / clipSpace.w;

    // Clipping: In OpenGL, visible Z is [-1, 1].
    // If w < 0, it's behind the camera.
    if (clipSpace.w < 0) return null;

    // Check if outside viewing frustum (optional, but good for performance/bugs)
    // if (ndcZ < -1.0 || ndcZ > 1.0) return null;

    // Viewport Transformation: NDC [-1, 1] -> Screen [0, width/height]
    // Note: Y in Flutter/Screen is Down. Y in NDC is Up.
    // So we flip Y.

    double screenX = (ndcX + 1.0) / 2.0 * screenSize.width;
    double screenY = (1.0 - ndcY) / 2.0 * screenSize.height;

    return Offset(screenX, screenY);
  }
}
