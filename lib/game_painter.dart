import 'package:flutter/material.dart';
import 'models.dart';
import 'dart:math';

class GamePainter extends CustomPainter {
  final NeonRunnerGame game;

  GamePainter(this.game);

  @override
  void paint(Canvas canvas, Size size) {
    // Fill Background
    final Rect bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint bgPaint = Paint()
      ..color = const Color(0xFF050510); // Fog color
    canvas.drawRect(bgRect, bgPaint);

    if (game.status == GameStatus.menu) {
      _drawText(canvas, size, "NEON RUNNER", 40, Colors.cyan, 0, -50);
      _drawText(canvas, size, "Tap to Start", 20, Colors.white, 0, 50);
      return;
    }

    // Horizon line usually at center y or slightly above
    final double horizonY = size.height * 0.4;
    final double centerX = size.width / 2;

    // Projection Function
    Offset project(double x, double y, double z) {
      // Camera params
      // Camera at (0, 6, 14) looking at (0, 2, -10).
      // Simplified: World moves relative to camera.
      // Objects at z=0 are at player position.
      // Objects at z < 0 are far away.
      // Objects at z > 0 are behind/passing player.

      // We want perspective.
      // Scale factor `s = f / (z_depth)`.
      // Let's assume camera is at z_cam = 20 relative to player at 0.
      // So distance = 20 - z.
      // If z = -100, dist = 120. Scale small.
      // If z = 0, dist = 20. Scale normal.
      // If z = 15, dist = 5. Scale huge.

      const double fov = 300.0;
      const double cameraDist = 20.0;
      const double cameraHeight = 5.0; // Camera height offset

      double dist = cameraDist - z;
      if (dist < 1.0) dist = 1.0; // Clip near plane

      double scale = fov / dist;

      double screenX = centerX + (x * scale);
      // y is height from ground.
      // Screen Y needs to map Ground(0) to some baseline, taking camera height into account.
      // ground_y_screen = horizonY + (cameraHeight * scale) ?
      // No, usually: y_screen = cy - (y - camY) * scale
      // Let's say horizon is at vanishing point.
      // Vanishing point is where z -> -infinity, so scale -> 0.
      // y_screen = horizonY + ((y - cameraHeight) * scale) (if y is up)
      // Since canvas Y is down, we invert.
      double screenY = horizonY - ((y - cameraHeight) * scale);

      return Offset(screenX, screenY);
    }

    // Draw Ground Grid / Road
    // We can draw lines for lanes.
    final Paint lanePaint = Paint()
      ..color = Colors.cyan.withOpacity(0.5)
      ..strokeWidth = 2;

    for (int i = -1; i <= 2; i++) { // Lane lines at -1.5, -0.5, 0.5, 1.5 * laneWidth (borders)
       // Actually config says laneWidth = 4. Lanes are -1, 0, 1.
       // Borders are at -6, -2, 2, 6.
       // Wait, center of lane 0 is 0. Width 4. So -2 to 2.
       // Lane -1 is -4. Width 4. So -6 to -2.
       // Lane 1 is 4. Width 4. So 2 to 6.
       double lineX = (i * 4.0) - 2.0;

       Offset p1 = project(lineX, 0, -200); // Far
       Offset p2 = project(lineX, 0, 20);   // Near
       canvas.drawLine(p1, p2, lanePaint);
    }

    // Draw Objects
    // Sort by Z (far to near) so near objects draw on top
    // Obstacles have Z from -180 to 15.
    // Player is at Z=0.

    // Create a list of renderables to sort
    List<RenderObject> renderables = [];

    // Add Obstacles
    for (var obs in game.obstacles) {
      renderables.add(RenderObject(type: 'obs', z: obs.z, obj: obs));
    }

    // Add Player
    // If Game Over, player might be invisible or exploded, but let's draw
    if (game.status != GameStatus.gameOver) {
       renderables.add(RenderObject(type: 'player', z: game.player.z, obj: game.player));
    }

    // Sort: Smallest Z (most negative, furthest) first.
    renderables.sort((a, b) => a.z.compareTo(b.z));

    for (var r in renderables) {
      if (r.type == 'player') {
        _drawPlayer(canvas, game.player, project);
      } else {
        _drawObstacle(canvas, r.obj as Obstacle, project);
      }
    }

    // HUD
    _drawHUD(canvas, size);

    if (game.status == GameStatus.gameOver) {
      // Draw Red Overlay
      canvas.drawRect(bgRect, Paint()..color = Colors.red.withOpacity(0.3));
      _drawText(canvas, size, "CRASHED", 50, Colors.red, 0, -50);
      _drawText(canvas, size, "Score: ${game.score}", 30, Colors.white, 0, 20);
      _drawText(canvas, size, "Tap to Retry", 20, Colors.white, 0, 70);
    }
  }

  void _drawPlayer(Canvas canvas, Player p, Offset Function(double, double, double) project) {
    // Player is a box/capsule.
    // Dimensions roughly: width 1, height 1.
    // p.x, p.y, p.z(0).

    // Base point
    Offset base = project(p.x, p.y, p.z);

    // Simple representation: Circle or Rect depending on roll
    Paint paint = Paint()..color = Colors.white;
    Paint accent = Paint()..color = Colors.cyan;

    // Calculate scale at this Z
    // We can estimate scale by projecting a point 1 unit up/right
    Offset up = project(p.x, p.y + 1, p.z);
    double h = (base.dy - up.dy).abs();
    double w = h * 0.8;

    if (p.isRolling) {
       h = h * 0.5; // Squished
    }

    Rect playerRect = Rect.fromCenter(center: Offset(base.dx, base.dy - h/2), width: w, height: h);

    canvas.drawRect(playerRect, paint);
    canvas.drawRect(playerRect.deflate(w*0.2), accent);
  }

  void _drawObstacle(Canvas canvas, Obstacle obs, Offset Function(double, double, double) project) {
    Offset base = project(obs.x, obs.y, obs.z);
    Offset up = project(obs.x, obs.y + 2, obs.z); // Arbitrary height reference
    double h = (base.dy - up.dy).abs();
    double w = h;

    Paint p = Paint();

    switch (obs.type) {
      case CollisionType.solid:
        p.color = Colors.red;
        // Tall block
        Rect r = Rect.fromCenter(center: Offset(base.dx, base.dy - h/2), width: w, height: h);
        canvas.drawRect(r, p);
        break;
      case CollisionType.jump:
        p.color = Colors.orange;
        // Low barrier
        double bh = h * 0.3;
        Rect r2 = Rect.fromCenter(center: Offset(base.dx, base.dy - bh/2), width: w * 1.5, height: bh);
        canvas.drawRect(r2, p);
        break;
      case CollisionType.duck:
        p.color = Colors.yellow;
        // High barrier
        double bh2 = h * 0.3;
        // Float in air
        Offset high = project(obs.x, obs.y + 2.0, obs.z); // Say it's at y=2
        Rect r3 = Rect.fromCenter(center: high, width: w * 1.5, height: bh2);
        canvas.drawRect(r3, p);
        // Draw poles
        canvas.drawLine(Offset(r3.left, r3.bottom), Offset(r3.left, base.dy), Paint()..color=Colors.grey..strokeWidth=2);
        canvas.drawLine(Offset(r3.right, r3.bottom), Offset(r3.right, base.dy), Paint()..color=Colors.grey..strokeWidth=2);
        break;
      case CollisionType.coin:
        p.color = Colors.amber;
        canvas.drawCircle(Offset(base.dx, base.dy - h/2), w * 0.3, p);
        break;
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
    return true; // Always repaint for game loop
  }
}

class RenderObject {
  String type;
  double z;
  Object obj;
  RenderObject({required this.type, required this.z, required this.obj});
}
