import 'package:vector_math/vector_math_64.dart';

class Camera {
  Vector3 position;
  Vector3 target;
  Vector3 up;

  double fovYRadians;
  double aspectRatio;
  double nearPlane;
  double farPlane;

  Camera({
    required this.position,
    required this.target,
    required this.up,
    this.fovYRadians = 60 * degrees2Radians, // 60 degrees
    this.aspectRatio = 1.0,
    this.nearPlane = 0.1,
    this.farPlane = 400.0,
  });

  Matrix4 get viewMatrix {
    return makeViewMatrix(position, target, up);
  }

  Matrix4 get projectionMatrix {
    return makePerspectiveMatrix(fovYRadians, aspectRatio, nearPlane, farPlane);
  }

  void updateAspectRatio(double width, double height) {
    if (height != 0) {
      aspectRatio = width / height;
    }
  }
}
