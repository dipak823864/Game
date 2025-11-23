import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'models.dart';

class GamePainter extends CustomPainter {
  final NeonRunnerGame game;
  final Animation<double> repaint;

  GamePainter({required this.game, required this.repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Background
    final Rect bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint bgPaint = Paint()..color = const Color(0xFF050510);
    canvas.drawRect(bgRect, bgPaint);

    // 2. Setup Perspective
    // Horizon line at roughly 1/3 of the screen from top?
    // Let's say horizon y = size.height * 0.3
    // Bottom of screen y = size.height
    // World x=0 is center of screen x

    final double horizonY = size.height * 0.3;
    final double centerX = size.width / 2;
    final double bottomY = size.height;

    // Projection Helper
    Offset project(double x, double y, double z) {
      // Camera is at (0, 6, 14) in React code
      // Objects are at z from -200 to +15.
      // Perspective formula:
      // scale = fov / (z + cameraZ)
      // screenX = x * scale + centerX
      // screenY = y * scale + centerY // Need to adjust for camera height

      const double cameraZ = 20.0; // Distance of camera from z=0
      const double cameraY = 6.0;  // Camera height
      const double fov = 400.0;    // Field of view factor

      // In React code, camera looks at (0, 2, -10).
      // Let's assume a simple perspective where Z decreases into distance.
      // But in our model, objects move +Z (towards camera).
      // So distance = cameraZ - z.

      double depth = cameraZ - z;
      if (depth < 0.1) depth = 0.1; // Clip near plane

      double scale = fov / depth;

      double screenX = centerX + (x * scale * 40); // Scale x by 40 to match lane width logic
      // Invert Y because screen Y goes down, world Y goes up
      double screenY = (size.height * 0.8) - ((y - 1) * scale * 40); // Base ground at y=1 (playerBaseY)
      // Adjust camera height effect:
      // If camera is high, ground looks lower.
      // Let's manually tune the Y to look like a road going into horizon.

      // Re-tuning:
      // Z = -200 (Far), Z = 10 (Close/Behind)
      // screenY for Z=-200 should be near horizonY.
      // screenY for Z=0 should be near bottom.

      return Offset(screenX, screenY);
    }

    // 3. Draw Road/Grid
    // Draw Ground Segments manually or just a grid
    // Grid lines every 10 units of Z
    final Paint gridPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Longitudinal lines (Lanes)
    for (int i = -2; i <= 2; i++) {
      double laneX = (i * GameConfig.laneWidth) - (GameConfig.laneWidth / 2); // Lane borders
      // Draw line from Z=-200 to Z=15
      Path lanePath = Path();
      bool started = false;
      for (double z = -200; z <= 20; z += 10) {
        // Offset z by (distanceTraveled % 10) to make it move?
        // Actually, just drawing static lines is fine if we draw cross lines moving.
        Offset p = project(laneX, 0, z);
        if (!started) {
          lanePath.moveTo(p.dx, p.dy);
          started = true;
        } else {
          lanePath.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(lanePath, gridPaint);
    }

    // Transverse lines (moving towards player)
    // We want lines to appear at intervals.
    // The world moves +gameSpeed.
    // We can simulate this by offsetting the z loop.
    double zOffset = game.distanceTraveled % 20.0; // grid interval 20
    for (double z = 20 - zOffset; z >= -200; z -= 20) {
       // Draw line across road width
       Offset p1 = project(-GameConfig.laneWidth * 1.5, 0, z);
       Offset p2 = project(GameConfig.laneWidth * 1.5, 0, z);
       canvas.drawLine(p1, p2, gridPaint);
    }

    // 4. Draw Obstacles (Sorted by Z far to near so they layer correctly)
    // Actually we should sort everything including player by Z.
    // But Player is always at Z=0.

    List<dynamic> renderQueue = [];
    renderQueue.addAll(game.obstacles);
    // Player wrapper
    renderQueue.add(game.player);

    // Sort: Smallest Z (farthest) first.
    // Player Z is 0.
    renderQueue.sort((a, b) {
      double za = (a is Player) ? 0.0 : (a as Obstacle).z;
      double zb = (b is Player) ? 0.0 : (b as Obstacle).z;
      return za.compareTo(zb);
    });

    for (var item in renderQueue) {
      if (item is Player) {
        _drawPlayer(canvas, item, project);
      } else if (item is Obstacle) {
        _drawObstacle(canvas, item, project);
      }
    }

    // 5. Particles
    for (var p in game.particles) {
      Offset pos = project(p.x, p.y, p.z);
      Paint pp = Paint()..color = Color(p.color).withOpacity(p.life.clamp(0.0, 1.0));
      canvas.drawCircle(pos, 2 * (400 / (20 - p.z)), pp); // Scale size by depth
    }

    // 6. UI HUD (Score, etc.)
    _drawHUD(canvas, size);

    if (game.state == GameState.MENU) {
      _drawMenu(canvas, size);
    } else if (game.state == GameState.GAME_OVER) {
      _drawGameOver(canvas, size);
    }
  }

  void _drawPlayer(Canvas canvas, Player p, Function project) {
    if (game.state == GameState.GAME_OVER) return; // Hidden on death

    Offset pos = project(p.x, p.y, 0.0);
    // Determine size based on depth (Z=0)
    // At Z=0, scale = 400/20 = 20.
    // Player height ~ 1.0 -> 20 pixels * scaling factor.

    double scale = 20.0;

    Paint bodyPaint = Paint()..color = Colors.cyan;
    Paint glowPaint = Paint()..color = Colors.cyanAccent..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // Draw shadow
    Offset shadowPos = project(p.x, 0, 0);
    canvas.drawOval(
      Rect.fromCenter(center: shadowPos, width: 40, height: 10),
      Paint()..color = Colors.black.withOpacity(0.5)
    );

    // Draw Ship Body
    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    // Rotation logic
    canvas.rotate(p.rotationZ * 0.5); // Bank
    if (p.isJumping) {
      canvas.rotate(-0.2); // Pitch up
    }

    // Simple shape
    Path shipPath = Path();
    shipPath.moveTo(0, -20);
    shipPath.lineTo(10, 10);
    shipPath.lineTo(0, 5);
    shipPath.lineTo(-10, 10);
    shipPath.close();

    canvas.drawPath(shipPath, glowPaint); // Glow
    canvas.drawPath(shipPath, bodyPaint); // Body

    canvas.restore();
  }

  void _drawObstacle(Canvas canvas, Obstacle obs, Function project) {
    if (!obs.active) return;

    Offset pos = project(obs.x, obs.y, obs.z);
    double depth = 20.0 - obs.z;
    if (depth < 0.1) return;
    double scale = 400.0 / depth;

    if (obs.type == CollisionType.COIN) {
       Paint coinPaint = Paint()..color = Colors.yellow;
       double r = 0.5 * scale * 30; // 0.5 radius
       // Spin effect
       double widthScale = math.cos(obs.rotationY).abs();

       canvas.drawOval(
         Rect.fromCenter(center: pos, width: r * widthScale * 2, height: r * 2),
         coinPaint
       );
    } else if (obs.type == CollisionType.SOLID) {
      // Box
      Paint boxPaint = Paint()..color = Colors.red.shade900;
      Paint border = Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 2;

      double w = 3.0 * scale * 20; // Width
      double h = 3.0 * scale * 20; // Height

      Rect r = Rect.fromCenter(center: pos, width: w, height: h);
      canvas.drawRect(r, boxPaint);
      canvas.drawRect(r, border);

    } else if (obs.type == CollisionType.JUMP) {
      // Low Barrier
      Paint paint = Paint()..color = Colors.purpleAccent;
      double w = 3.5 * scale * 20;
      double h = 0.5 * scale * 20;
      // It's on the ground, so y is low.
      Offset groundPos = project(obs.x, 0.5, obs.z); // Center y=0.5
      Rect r = Rect.fromCenter(center: groundPos, width: w, height: h);
      canvas.drawRect(r, paint);

    } else if (obs.type == CollisionType.DUCK) {
      // High Overhead
      Paint paint = Paint()..color = Colors.orangeAccent;
      double w = 3.8 * scale * 20;
      double h = 1.0 * scale * 20;
      Offset highPos = project(obs.x, 3.0, obs.z); // Center y=3.0
      Rect r = Rect.fromCenter(center: highPos, width: w, height: h);
      canvas.drawRect(r, paint);

      // Pillars
      Paint pillarPaint = Paint()..color = Colors.grey;
      Offset p1 = project(obs.x - 1.8, 1.5, obs.z);
      Offset p2 = project(obs.x + 1.8, 1.5, obs.z);
      double pH = 3.0 * scale * 20;
      double pW = 0.2 * scale * 20;
      canvas.drawRect(Rect.fromCenter(center: p1, width: pW, height: pH), pillarPaint);
      canvas.drawRect(Rect.fromCenter(center: p2, width: pW, height: pH), pillarPaint);
    }
  }

  void _drawHUD(Canvas canvas, Size size) {
     final textPainter = TextPainter(
       text: TextSpan(
         text: "SCORE\n${game.score.toInt().toString().padLeft(6, '0')}",
         style: TextStyle(
           color: Colors.white,
           fontSize: 24,
           fontWeight: FontWeight.bold,
           fontFamily: 'Courier'
         )
       ),
       textAlign: TextAlign.right,
       textDirection: TextDirection.ltr
     );
     textPainter.layout();
     textPainter.paint(canvas, Offset(size.width - textPainter.width - 20, 40));
  }

  void _drawMenu(Canvas canvas, Size size) {
    _drawCenteredText(canvas, size, "NEON RUNNER", 48, -50, Colors.white);
    _drawCenteredText(canvas, size, "TAP TO START", 24, 50, Colors.cyan);
  }

  void _drawGameOver(Canvas canvas, Size size) {
    // Semi-transparent overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.red.withOpacity(0.3)
    );

    _drawCenteredText(canvas, size, "CRASHED", 64, -50, Colors.red);
    _drawCenteredText(canvas, size, "FINAL SCORE: ${game.score.toInt()}", 32, 20, Colors.white);
    _drawCenteredText(canvas, size, "TAP TO RETRY", 24, 80, Colors.white);
  }

  void _drawCenteredText(Canvas canvas, Size size, String text, double fontSize, double yOffset, Color color) {
    final textPainter = TextPainter(
       text: TextSpan(
         text: text,
         style: TextStyle(
           color: color,
           fontSize: fontSize,
           fontWeight: FontWeight.bold,
           shadows: [Shadow(blurRadius: 10, color: color)]
         )
       ),
       textAlign: TextAlign.center,
       textDirection: TextDirection.ltr
     );
     textPainter.layout();
     textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2 + yOffset));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
