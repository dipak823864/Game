import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:my_editor/main.dart';
import 'package:my_editor/models.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  testWidgets('Neon Runner 3D Logic Integration Test', (WidgetTester tester) async {
    // 1. Initialize Game
    await tester.pumpWidget(const MyApp());

    // Tap to start
    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    // Access state
    final GamePageState gameState = tester.state(find.byType(GamePage));
    final NeonRunnerGame game = gameState.game;

    expect(game.status, GameStatus.playing);

    // 2. Check Vector3 Movement (Player)
    // Initial Position
    Vector3 initialPos = game.player.position.clone();
    expect(initialPos.x, 0.0);
    expect(initialPos.y, GameConfig.playerBaseY);
    expect(initialPos.z, 0.0);

    // Move Right
    game.player.moveRight();

    // Simulate frames
    // Player lerps to x = 4.0
    for(int i=0; i<60; i++) {
        game.update(); // Manual update for precise logic testing without widget pump reliance
    }

    expect(game.player.position.x, closeTo(4.0, 0.1));

    // Move Left twice (to -4.0)
    game.player.moveLeft();
    game.player.moveLeft();

    for(int i=0; i<60; i++) {
        game.update();
    }
    expect(game.player.position.x, closeTo(-4.0, 0.1));

    // 3. Perspective Check (Logic only)
    // Verify that objects far away (more negative Z) are projected smaller?
    // This is a rendering test, hard to test in widget test without inspecting Painter output.
    // Instead, we check the Projection Matrix logic via unit test in this file.

    // 4. Collision Detection (3D AABB)
    // Reset player
    game.player.position.x = 0;
    game.player.currentLane = 0;
    game.obstacles.clear();
    game.status = GameStatus.playing;

    // Spawn obstacle at Z = -10 (In front)
    // Dimensions: Solid is 3.6 wide, 4.0 high, 3.6 deep.
    // Center at (-10) Z.
    // Player at (0) Z.
    // Obstacles move +Z.

    game.obstacles.add(Obstacle(
        x: 0,
        y: 2.0,
        z: -10,
        type: CollisionType.solid,
        lane: 0
    ));

    // Run updates until collision
    bool crashed = false;
    for(int i=0; i<100; i++) {
        game.update();
        if (game.status == GameStatus.gameOver) {
            crashed = true;
            break;
        }
    }

    expect(crashed, isTrue);
  });

  test('Camera Projection Matrix Sanity Check', () {
      // Perspective projection makes things smaller as they get further.
      // In our setup, camera is at Z=14. Looking at -Z.
      // Point A at Z=0 (Dist 14).
      // Point B at Z=-14 (Dist 28).
      // Projected X/Y for B should be closer to center (0,0) than A.

      // We need to instantiate Camera, but it's in a flutter package.
      // We can replicate logic or import.
      // Ideally we'd test the `Camera` class directly.
      // But we can just do a math check here if we want.
      // Or we can rely on `vector_math` library correctness.

      // Let's verify our usage:
      final matrix = makePerspectiveMatrix(60 * degrees2Radians, 1.0, 0.1, 400.0);
      final view = makeViewMatrix(Vector3(0, 6, 14), Vector3(0, 2, -10), Vector3(0, 1, 0));
      final vp = matrix * view;

      Vector4 transform(Vector3 v) {
          Vector4 v4 = Vector4(v.x, v.y, v.z, 1.0);
          return vp * v4;
      }

      Vector4 pNear = transform(Vector3(2, 0, 0));
      Vector4 pFar = transform(Vector3(2, 0, -50));

      // Perspective divide
      Offset toScreen(Vector4 v) => Offset(v.x / v.w, v.y / v.w);

      Offset sNear = toScreen(pNear);
      Offset sFar = toScreen(pFar);

      // Far object should appear closer to center (smaller X value in NDC)
      expect(sFar.dx.abs(), lessThan(sNear.dx.abs()));
  });
}
