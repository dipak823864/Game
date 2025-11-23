import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:my_editor/main.dart';
import 'package:my_editor/models.dart';
import 'package:my_editor/utils/camera.dart';

void main() {
  testWidgets('Neon Runner 3D Logic & Integration Test', (WidgetTester tester) async {
    // 1. Initialize Game
    await tester.pumpWidget(const MyApp());

    final dynamic gameState = tester.state(find.byType(GamePage));
    final NeonRunnerGame game = gameState.game;

    // Start Game
    game.start();
    await tester.pump();

    // 2. Test 3D Movement (Vector3)
    print("Initial Position: ${game.player.position}");
    expect(game.player.position.x, 0.0);

    // Move Right
    game.player.moveRight();
    // Simulate frames for lerp
    for (int i = 0; i < 30; i++) {
       game.update(); // Manual update for precise control in this logic test block
       await tester.pump(const Duration(milliseconds: 16));
    }

    print("Position after Move Right: ${game.player.position}");
    expect(game.player.position.x, greaterThan(0.0)); // Should be moving towards +4
    expect(game.player.position.x, lessThanOrEqualTo(4.0));

    // 3. Test Perspective Projection (Camera)
    // Create two identical cubes at different Z depths
    Camera cam = Camera(
      position: Vector3(0, 6, 14),
      target: Vector3(0, 2, -10),
      up: Vector3(0, 1, 0),
    );
    Size screenSize = const Size(800, 600);

    Vector3 nearObjPos = Vector3(0, 0, 0); // Nearer to camera (Camera Z=14)
    Vector3 farObjPos = Vector3(0, 0, -20); // Further

    // Project top-right corner of a 1x1x1 cube centered at pos
    Vector3 offset = Vector3(0.5, 0.5, 0);

    Offset? pNear = cam.project(nearObjPos + offset, screenSize);
    Offset? pFar = cam.project(farObjPos + offset, screenSize);
    Offset? centerNear = cam.project(nearObjPos, screenSize);
    Offset? centerFar = cam.project(farObjPos, screenSize);

    if (pNear != null && centerNear != null && pFar != null && centerFar != null) {
      double sizeNear = (pNear - centerNear).distance;
      double sizeFar = (pFar - centerFar).distance;

      print("Size Near: $sizeNear, Size Far: $sizeFar");
      expect(sizeNear, greaterThan(sizeFar)); // Perspective check: Nearer should look bigger
    } else {
      fail("Projection failed (clipped)");
    }

    // 4. Test 3D Collision (AABB)
    game.start(); // Reset
    // Spawn obstacle at player position
    game.obstacles.add(Obstacle(
      position: Vector3(0, 1, 0),
      size: Vector3(1, 1, 1),
      type: CollisionType.solid,
      lane: 0
    ));

    // Run update to trigger collision
    game.update();
    expect(game.status, GameStatus.gameOver);
  });
}
