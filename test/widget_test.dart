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

    // Initial State Verification
    expect(game.state, GameState.MENU);
    expect(game.score, 0);

    // 2. Start Game via Tap
    // Tapping the GestureDetector triggers _handleTap -> game.start()
    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    expect(game.state, GameState.PLAYING);
    expect(game.obstacles.length, greaterThan(0), reason: "Obstacles should spawn on start");
    expect(game.player.lane, 0);

    // 3. Simulate Time Passing (Game Loop Integration)
    // Ticker does not run automatically in testWidgets without proper pumping.
    // However, since Ticker logic inside main.dart calls game.update(),
    // and we cannot easily mock Ticker elapsed time in a simple widget test without 'tester.pump(duration)',
    // we will rely on manual updates for precise logic verification, OR use pump with duration.

    // Let's try pumping time to see if Ticker fires.
    // Note: In some test environments, Tickers started by createTicker might need specific handling.
    // Ideally we manually drive logic for deterministic testing.

    double initialZ = game.obstacles[0].z;
    game.update(); // Manually driving one frame
    expect(game.obstacles[0].z, greaterThan(initialZ), reason: "Obstacles should move +Z towards player");

    // 4. Test Player Movement (Logic)
    // Swipe Right
    game.moveRight();
    expect(game.player.lane, 1);

    // Swipe Left to Center
    game.moveLeft();
    expect(game.player.lane, 0);

    // Jump
    expect(game.player.isJumping, false);
    game.jump();
    expect(game.player.isJumping, true);
    expect(game.player.velocityY, GameConfig.jumpForce);

    // Simulate Gravity Effect
    double initialY = game.player.y; // 1.0
    game.update();
    expect(game.player.y, greaterThan(initialY), reason: "Player should move up when jumping");

    // 5. Collision & Game Over
    // Force a collision scenario
    game.start(); // Reset
    game.obstacles.clear();
    // Place a SOLID obstacle at Player's position (x=0, z=0)
    game.obstacles.add(Obstacle(
      x: 0,
      y: 0,
      z: 0.0,
      type: CollisionType.SOLID,
      lane: 0
    ));

    game.update(); // This frame should detect collision

    expect(game.state, GameState.GAME_OVER, reason: "Hitting a SOLID obstacle should trigger Game Over");

    // 6. Score Verification
    // Reset and check score accumulation
    game.start();
    double startScore = game.score;
    // Simulate running for a bit
    for(int i=0; i<50; i++) game.update();

    expect(game.score, greaterThan(startScore), reason: "Score should increase as distance traveled increases");
  });
}
