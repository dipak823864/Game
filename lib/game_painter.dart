import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;
import 'models.dart';
import 'utils/camera.dart';
import 'game_engine.dart'; // To access GameEngine class if needed for types

class GamePainter extends CustomPainter {
  final GameEngine game;
  late final Camera camera;

  GamePainter(this.game) {
    camera = Camera(
      position: vmath.Vector3(0, 6, 14),
      target: vmath.Vector3(0, 2, -10),
      up: vmath.Vector3(0, 1, 0),
      fov: 60,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Fill Background
    final Rect bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint bgPaint = Paint()..color = const Color(0xFF050510);
    canvas.drawRect(bgRect, bgPaint);

    camera.aspectRatio = size.width / size.height;

    List<Renderable> renderables = [];

    // Lane Lines
    for (int i = -2; i <= 2; i++) {
       double x = i * 4.0 - 2.0;
       renderables.add(LineRenderable(
         start: vmath.Vector3(x, 0, -200),
         end: vmath.Vector3(x, 0, 20),
         color: Colors.cyan.withOpacity(0.5),
         thickness: 1
       ));
    }

    // Obstacles
    for (var obs in game.obstacles) {
      renderables.add(CubeRenderable(
        position: obs.position,
        size: obs.size,
        color: _getColor(obs.type),
      ));
    }

    // Player
    if (game.status != GameStatus.gameOver) {
      renderables.add(CubeRenderable(
        position: game.player.position,
        size: game.player.size,
        color: Colors.white,
        borderColor: Colors.cyan
      ));
    }

    // Z-Sort
    renderables.sort((a, b) => a.center.z.compareTo(b.center.z));

    // Draw
    for (var r in renderables) {
      r.draw(canvas, camera, size);
    }
  }

  Color _getColor(CollisionType type) {
    switch (type) {
      case CollisionType.solid: return Colors.red;
      case CollisionType.jump: return Colors.orange;
      case CollisionType.duck: return Colors.yellow;
      case CollisionType.coin: return Colors.amber;
      default: return Colors.white;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

abstract class Renderable {
  vmath.Vector3 get center;
  void draw(Canvas canvas, Camera camera, Size screenSize);
}

class LineRenderable extends Renderable {
  final vmath.Vector3 start;
  final vmath.Vector3 end;
  final Color color;
  final double thickness;

  LineRenderable({required this.start, required this.end, required this.color, this.thickness = 1.0});

  @override
  vmath.Vector3 get center => (start + end) * 0.5;

  @override
  void draw(Canvas canvas, Camera camera, Size screenSize) {
    Offset? p1 = camera.project(start, screenSize);
    Offset? p2 = camera.project(end, screenSize);

    if (p1 != null && p2 != null) {
      canvas.drawLine(p1, p2, Paint()..color = color..strokeWidth = thickness);
    }
  }
}

class CubeRenderable extends Renderable {
  final vmath.Vector3 position;
  final vmath.Vector3 size;
  final Color color;
  final Color? borderColor;

  CubeRenderable({required this.position, required this.size, required this.color, this.borderColor});

  @override
  vmath.Vector3 get center => position;

  @override
  void draw(Canvas canvas, Camera camera, Size screenSize) {
    double w = size.x / 2;
    double h = size.y / 2;
    double d = size.z / 2;

    List<vmath.Vector3> localVerts = [
      vmath.Vector3(-w, -h, -d), // 0
      vmath.Vector3(w, -h, -d),  // 1
      vmath.Vector3(w, h, -d),   // 2
      vmath.Vector3(-w, h, -d),  // 3
      vmath.Vector3(-w, -h, d),  // 4
      vmath.Vector3(w, -h, d),   // 5
      vmath.Vector3(w, h, d),    // 6
      vmath.Vector3(-w, h, d),   // 7
    ];

    List<Offset?> projected = localVerts.map((v) => camera.project(position + v, screenSize)).toList();

    List<List<int>> faces = [
      [1, 0, 3, 2], // Back
      [0, 4, 7, 3], // Left
      [5, 1, 2, 6], // Right
      [4, 0, 1, 5], // Bottom
      [3, 7, 6, 2], // Top
      [4, 5, 6, 7], // Front
    ];

    Paint paint = Paint()..color = color;
    Paint border = Paint()..color = borderColor ?? Colors.black.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1;

    for (var face in faces) {
      if (face.any((i) => projected[i] == null)) continue;

      Path path = Path();
      path.moveTo(projected[face[0]]!.dx, projected[face[0]]!.dy);
      path.lineTo(projected[face[1]]!.dx, projected[face[1]]!.dy);
      path.lineTo(projected[face[2]]!.dx, projected[face[2]]!.dy);
      path.lineTo(projected[face[3]]!.dx, projected[face[3]]!.dy);
      path.close();

      canvas.drawPath(path, paint);
      canvas.drawPath(path, border);
    }
  }
}
