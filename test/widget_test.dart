import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_editor/main.dart';
import 'package:my_editor/models.dart';
import 'package:my_editor/game_painter.dart';

void main() {
  testWidgets('Neon Runner Game Logic Test', (WidgetTester tester) async {
    // 1. Pump the game widget
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    final pageFinder = find.byType(NeonRunnerPage);
    expect(pageFinder, findsOneWidget);

    final NeonRunnerPageState state = tester.state(pageFinder);
    final NeonRunnerGame game = state.game;

    // Initial State
    expect(game.state, GameState.MENU);

    // 2. Start Game via Tap
    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    expect(game.state, GameState.PLAYING);
    expect(game.obstacles.length, greaterThan(0)); // Obstacles should spawn

    // 3. Simulate Time Passing (Game Loop)
    // We cannot easily pump frames for Ticker in test environment without manual control,
    // but we can call game.update() manually to verify logic.

    double initialZ = game.obstacles[0].z;
    game.update();
    expect(game.obstacles[0].z, greaterThan(initialZ)); // Objects move +Z

    // 4. Test Controls
    // Move Right
    game.moveRight();
    expect(game.player.lane, 1);

    // Move Left
    game.moveLeft();
    expect(game.player.lane, 0);

    // Jump
    game.jump();
    expect(game.player.isJumping, true);
    expect(game.player.velocityY, GameConfig.jumpForce);

    // Simulate Gravity
    double initialY = game.player.y;
    game.update();
    expect(game.player.y, greaterThan(initialY)); // Moved up

    // 5. Test Score Accumulation
    double initialScore = game.score;
    // Simulate many updates
    for(int i=0; i<100; i++) {
      game.update();
    }
    expect(game.score, greaterThan(initialScore));

    // 6. Test Collision (Simulated)
    // Force spawn an obstacle at player position
    game.player.reset(); // Reset player
    game.obstacles.clear();
    game.obstacles.add(Obstacle(
      x: 0,
      y: 0,
      z: 0,
      type: CollisionType.SOLID,
      lane: 0
    ));

    game.update(); // Should detect collision
    expect(game.state, GameState.GAME_OVER);
  });
}
