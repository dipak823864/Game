import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'models.dart';
import 'utils/camera.dart';

class GamePainter extends CustomPainter {
  final NeonRunnerGame game;
  final Camera camera;

  GamePainter(this.game) : camera = Camera(
      position: v.Vector3(0, 6, 14),
      target: v.Vector3(0, 2, -10),
      up: v.Vector3(0, 1, 0),
  );

  @override
  void paint(Canvas canvas, Size size) {
    // Fill Background
    final Rect bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint bgPaint = Paint()..color = const Color(0xFF050510);
    canvas.drawRect(bgRect, bgPaint);

    camera.updateAspectRatio(size.width, size.height);

    if (game.status == GameStatus.menu) {
      _drawText(canvas, size, "NEON RUNNER", 40, Colors.cyan, 0, -50);
      _drawText(canvas, size, "Tap to Start", 20, Colors.white, 0, 50);
      return;
    }

    // Matrices
    final v.Matrix4 viewMatrix = camera.viewMatrix;
    final v.Matrix4 projectionMatrix = camera.projectionMatrix;
    final v.Matrix4 viewProjection = projectionMatrix * viewMatrix;

    // Viewport transformation
    // Normalized Device Coordinates (NDC) are -1 to 1.
    // Screen coords: x from 0 to width, y from 0 to height.
    v.Vector2 viewportCenter = v.Vector2(size.width / 2, size.height / 2);

    Offset? project(v.Vector3 worldPos) {
       v.Vector4 pos4 = v.Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
       v.Vector4 clipPos = viewProjection * pos4;

       // Clip check (simple w check for behind camera)
       if (clipPos.w <= 0) return null;

       // Perspective divide
       double ndcX = clipPos.x / clipPos.w;
       double ndcY = clipPos.y / clipPos.w;

       // Viewport transform
       // In flutter, y is down. In NDC, y is up. So we invert Y.
       double screenX = viewportCenter.x + (ndcX * viewportCenter.x);
       double screenY = viewportCenter.y - (ndcY * viewportCenter.y);

       return Offset(screenX, screenY);
    }

    // Draw Road Grid
    final Paint lanePaint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw road segments
    // Since segments are dynamic, we just draw long lines for lanes + horizontal markers from segments?
    // Actually, let's draw the grid based on segments.
    // Road segments are at -10 intervals.

    for (var segment in game.roadSegments) {
       // Draw horizontal line for this segment?
       // Road width is roughly 3 lanes * 4 width = 12. plus sidewalks. say 14.
       double z = segment.position.z;

       // Don't draw if behind camera too much
       if (z > 20) continue;

       Offset? pLeft = project(v.Vector3(-7, 0, z));
       Offset? pRight = project(v.Vector3(7, 0, z));

       if (pLeft != null && pRight != null) {
          canvas.drawLine(pLeft, pRight, lanePaint);
       }
    }

    // Longitudinal lines
    for (double x = -6; x <= 6; x += 4) {
       // Draw a line from far to near
       // We can approximate by taking points along the Z axis
       List<Offset> points = [];
       for (double z = -200; z <= 20; z += 10) {
           Offset? p = project(v.Vector3(x, 0, z));
           if (p != null) points.add(p);
       }
       if (points.length > 1) {
           canvas.drawPoints(v.PointMode.polygon, points, lanePaint);
       }
    }


    // Render Objects (Painter's Algorithm)
    List<RenderItem> renderList = [];

    // Add Obstacles
    for (var obs in game.obstacles) {
        renderList.add(RenderItem(obs.position, obs));
    }

    // Add Player
    if (game.status != GameStatus.playing && game.status != GameStatus.gameOver) {
       // Menu usually, but handled above.
    } else {
        renderList.add(RenderItem(game.player.position, game.player));
    }

    // Sort by Z (furthest first, i.e., most negative Z)
    // Wait, in our coordinate system, camera is at Z=14, looking at -10.
    // So smaller Z (more negative) is further away.
    // We want to draw smallest Z first.
    renderList.sort((a, b) => a.position.z.compareTo(b.position.z));

    for (var item in renderList) {
        if (item.object is Player) {
            _drawPlayer(canvas, item.object as Player, project);
        } else if (item.object is Obstacle) {
            _drawObstacle(canvas, item.object as Obstacle, project);
        }
    }

    // HUD
    _drawHUD(canvas, size);

    if (game.status == GameStatus.gameOver) {
       canvas.drawRect(bgRect, Paint()..color = Colors.red.withOpacity(0.3));
       _drawText(canvas, size, "CRASHED", 50, Colors.red, 0, -50);
       _drawText(canvas, size, "Score: ${game.score}", 30, Colors.white, 0, 20);
       _drawText(canvas, size, "Tap to Retry", 20, Colors.white, 0, 70);
    }
  }

  void _drawPlayer(Canvas canvas, Player player, Offset? Function(v.Vector3) project) {
      // 3D Box for player
      // Size roughly 1x1x1?
      // Use player's position as center bottom or center?
      // Player pos is center x, bottom y?, z.
      // In models.dart: "y = 0.5 (fuselage) ... position.y = 1 (base)".
      // Let's assume position is the pivot point.

      _drawBox(canvas, project, player.position, v.Vector3(1, 0.5, 2), Colors.cyan, true);
      // Wings/Fins? Simplified for now.
  }

  void _drawObstacle(Canvas canvas, Obstacle obs, Offset? Function(v.Vector3) project) {
      Color color = Colors.grey;
      bool wireframe = false;

      switch (obs.type) {
          case CollisionType.solid: color = Colors.red; break;
          case CollisionType.jump: color = Colors.orange; break;
          case CollisionType.duck: color = Colors.yellow; break;
          case CollisionType.coin: color = Colors.amber; wireframe = true; break;
      }

      _drawBox(canvas, project, obs.position, obs.size, color, wireframe);
  }

  void _drawBox(Canvas canvas, Offset? Function(v.Vector3) project, v.Vector3 center, v.Vector3 size, Color color, bool wireframe) {
      // Calculate 8 corners
      double hw = size.x / 2;
      double hh = size.y / 2;
      double hd = size.z / 2;

      List<v.Vector3> corners = [
          v.Vector3(-hw, -hh, -hd), v.Vector3(hw, -hh, -hd),
          v.Vector3(hw, hh, -hd), v.Vector3(-hw, hh, -hd),
          v.Vector3(-hw, -hh, hd), v.Vector3(hw, -hh, hd),
          v.Vector3(hw, hh, hd), v.Vector3(-hw, hh, hd),
      ];

      List<Offset?> projected = [];
      for (var c in corners) {
          projected.add(project(center + c));
      }

      // If any point is null (behind camera), we skip drawing this object properly or handle clipping.
      // Simple culling: if all null, skip.
      if (projected.every((p) => p == null)) return;

      // For partial clipping, it's complex. We will skip if any is null for simplicity of this custom engine.
      if (projected.any((p) => p == null)) return;

      List<Offset> pts = projected.cast<Offset>();

      Paint paint = Paint()
        ..color = color
        ..style = wireframe ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 2;

      Paint strokePaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      // Faces
      // Front: 4,5,6,7
      // Back: 0,1,2,3
      // Left: 0,4,7,3
      // Right: 1,5,6,2
      // Top: 3,7,6,2
      // Bottom: 0,4,5,1

      List<List<int>> faces = [
         [0, 1, 2, 3], // Back
         [0, 4, 5, 1], // Bottom
         [0, 4, 7, 3], // Left
         [1, 5, 6, 2], // Right
         [3, 7, 6, 2], // Top
         [4, 5, 6, 7], // Front
      ];

      // Crude backface culling or just draw all if wireframe?
      // For solid, we should draw back to front relative to camera, but we already sorted objects.
      // For faces within an object, we can just draw all or check normal.
      // Let's just draw all for now, maybe sorted by their center Z?
      // Since objects are convex, drawing back faces then front faces works.
      // But calculating that is hard.
      // Let's just draw them.

      for (var face in faces) {
          Path path = Path();
          path.moveTo(pts[face[0]].dx, pts[face[0]].dy);
          path.lineTo(pts[face[1]].dx, pts[face[1]].dy);
          path.lineTo(pts[face[2]].dx, pts[face[2]].dy);
          path.lineTo(pts[face[3]].dx, pts[face[3]].dy);
          path.close();

          if (!wireframe) {
             canvas.drawPath(path, paint);
             canvas.drawPath(path, strokePaint);
          } else {
             canvas.drawPath(path, paint);
          }
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class RenderItem {
  v.Vector3 position;
  Object object;
  RenderItem(this.position, this.object);
}
