import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;
import 'models.dart';
import 'utils/camera.dart';

class GamePainter extends CustomPainter {
  final NeonRunnerGame game;
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

    if (game.status == GameStatus.menu) {
      _drawText(canvas, size, "NEON RUNNER 3D", 40, Colors.cyan, 0, -50);
      _drawText(canvas, size, "Tap to Start", 20, Colors.white, 0, 50);
      return;
    }

    // 1. Collect all renderables
    List<Renderable> renderables = [];

    // Road Segments (Grid)
    // Draw infinite grid lines?
    // Let's create visual segments like in TS code.
    // Ground Segments move with z.
    // But for performance in Painter, let's just draw lane lines.
    // We can draw 3D lines.

    // Lane Lines
    for (int i = -2; i <= 2; i++) {
       // i=-2 => left border (-6), i=-1 => left lane sep (-2), 0 => right lane sep (2), 1 => right border (6)?
       // Lane width 4. Lanes: -1 (x=-4), 0 (x=0), 1 (x=4).
       // Borders: -6, -2, 2, 6.
       double x = i * 4.0 - 2.0;

       // Create a long line from very far (-200) to near (+20).
       renderables.add(LineRenderable(
         start: vmath.Vector3(x, 0, -200),
         end: vmath.Vector3(x, 0, 20),
         color: Colors.cyan.withOpacity(0.5),
         thickness: 2
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

    // 2. Sort by Depth (Painter's Algorithm)
    // We need to sort by distance from camera.
    // Z is not enough if camera rotates, but here camera is fixed.
    // Far objects (lower Z) should be drawn first?
    // Wait, camera is at Z=14. Looking at -Z.
    // Objects at -100 are far. Objects at 10 are near.
    // So we draw smallest Z first (most negative).

    renderables.sort((a, b) => a.center.z.compareTo(b.center.z));

    // 3. Draw
    for (var r in renderables) {
      r.draw(canvas, camera, size);
    }

    _drawHUD(canvas, size);

    if (game.status == GameStatus.gameOver) {
      canvas.drawRect(bgRect, Paint()..color = Colors.red.withOpacity(0.3));
      _drawText(canvas, size, "CRASHED", 50, Colors.red, 0, -50);
      _drawText(canvas, size, "Score: ${game.score}", 30, Colors.white, 0, 20);
      _drawText(canvas, size, "Tap to Retry", 20, Colors.white, 0, 70);
    }
  }

  Color _getColor(CollisionType type) {
    switch (type) {
      case CollisionType.solid: return Colors.red;
      case CollisionType.jump: return Colors.orange;
      case CollisionType.duck: return Colors.yellow;
      case CollisionType.coin: return Colors.amber;
    }
  }

  void _drawHUD(Canvas canvas, Size size) {
    if (game.status == GameStatus.playing) {
      _drawText(canvas, size, "${game.score}", 30, Colors.white, size.width/2 - 50, -size.height/2 + 50);
    }
  }

  void _drawText(Canvas canvas, Size size, String text, double fontSize, Color color, double xOffset, double yOffset) {
    TextSpan span = TextSpan(style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, fontFamily: 'Courier'), text: text);
    TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2 + xOffset, (size.height - tp.height) / 2 + yOffset));
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
    // 8 vertices
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

    // Faces: indices
    // Front: 4,5,6,7
    // Back: 1,0,3,2
    // Top: 3,7,6,2
    // Bottom: 4,0,1,5
    // Left: 0,4,7,3
    // Right: 5,1,2,6

    // Simple naive draw: Draw all faces?
    // Or Backface culling?
    // Painter's algorithm sorts objects. But self-sorting of faces is needed for transparency or correct look.
    // For a simple solid cube, we can just draw visible faces based on normal...
    // Or just draw Back -> Front faces.
    // Since we look generally from +Z and +Y, we see Front, Top, Right/Left.
    // We rarely see Bottom or Back unless we jump high or pass it.

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
      // Check if all points are projected (not clipped)
      // Ideally we clip properly, but for now just skip if any point is null
      if (face.any((i) => projected[i] == null)) continue;

      Path path = Path();
      path.moveTo(projected[face[0]]!.dx, projected[face[0]]!.dy);
      path.lineTo(projected[face[1]]!.dx, projected[face[1]]!.dy);
      path.lineTo(projected[face[2]]!.dx, projected[face[2]]!.dy);
      path.lineTo(projected[face[3]]!.dx, projected[face[3]]!.dy);
      path.close();

      // Backface Culling (2D Cross Product)
      // (p1-p0) x (p2-p1) z-component
      Offset p0 = projected[face[0]]!;
      Offset p1 = projected[face[1]]!;
      Offset p2 = projected[face[2]]!;

      double cross = (p1.dx - p0.dx) * (p2.dy - p1.dy) - (p1.dy - p0.dy) * (p2.dx - p1.dx);

      // If cross > 0, it's clockwise? or CCW?
      // Standard is CCW for front face.
      // If result is positive/negative depending on coordinate system.
      // Screen Y is down.
      // Let's test visually or just draw everything for now (simplest "Game Engine").
      // Actually, sorted faces is better.
      // Let's just draw them. Painter's algo on objects handles most.
      // Self-occlusion is handled by backface culling implicitly if we did it, but without it, we might see "inside" the cube if transparent.
      // Since it's solid color, drawing back faces then front faces is safer.
      // The order in 'faces' list matters.
      // Back, Left, Right, Bottom, Top, Front seems okay for typical camera angle.

      canvas.drawPath(path, paint);
      canvas.drawPath(path, border);
    }
  }
}
