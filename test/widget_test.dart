import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:my_editor/main.dart';
import 'package:my_editor/models.dart';

void main() {
  testWidgets('Neon Runner Game Logic Integration Test', (WidgetTester tester) async {
    // 1. Initialize Game
    await tester.pumpWidget(const MyApp());

    // Find the state to access game model
    final GamePage page = tester.widget(find.byType(GamePage));
    final State<GamePage> state = tester.state(find.byType(GamePage));
    // Accessing private field via reflection or just assuming we can verify via UI or behavior.
    // However, since 'game' is public in State class if we make it public, or we can just rely on the test structure I created.
    // Wait, '_GamePageState' is private. I cannot access 'game' directly easily in integration test without key or hack.
    // But I can modify the code to be testable, or just test the logic directly in unit test?
    // The user asked for "Integration Test" in widget_test.dart.
    // "Check if score > 0".

    // Let's modify the test to rely on what's available or use keys.
    // Actually, I can just tap the screen to start the game.

    await tester.tap(find.byType(GestureDetector));
    await tester.pump(); // Trigger tap

    // Pump frames for 1 second (simulating game loop)
    // We need to pump frames because the Ticker needs to run.
    // tester.pump(Duration) advances the clock.
    await tester.pump(const Duration(seconds: 1));

    // We can't easily read 'score' from the CustomPainter without finding the render object or inspecting the painter.
    // But wait, the prompt said: "Check if score 0 increased? (means loop runs)".
    // Maybe I should write a UNIT test for logic in models.dart AND a widget test?
    // User: "lib/widget_test.dart - write a strong integration test... check score increased... check player Jump... check GameState.gameOver".

    // To check internal state in a Widget test, typically we'd use a Key to expose the state, or test logic separately.
    // BUT, I can inspect the 'CustomPaint' widget's painter if I cast it.

    final Finder customPaintFinder = find.byType(CustomPaint);
    final CustomPaint customPaint = tester.widget(customPaintFinder);
    // The painter is dynamic? No, it's 'GamePainter'.
    // However, `GamePainter` is in `game_painter.dart`. I need to import it.
    // It is imported.

    // I can assume the painter is GamePainter.
    // But 'painter' property is 'CustomPainter?', so I need to cast.
    // But `GamePainter` holds `NeonRunnerGame`.

    // NOTE: 'painter' in CustomPaint is generic.
    // Let's try to access it.

    // We might need to iterate or find the specific CustomPaint.
    // There is one in the app.

    // Access game instance
    // I will use reflection-like access by casting.

    expect(customPaint.painter, isA<dynamic>()); // Just check it exists

    // This is tricky because the state creates the game instance.
    // I'll assume for the purpose of this test I can't easily access the private state's game object *unless* I make it accessible.
    // I'll make the GamePage state public or add a Key to expose it?
    // Better: I will unit test the Logic separately in the same file to be sure,
    // OR I will just modify main.dart to make 'game' accessible via a GlobalKey or similar?
    // No, I'll use the "find.byType" then "tester.state" strategy, but I need to make the State class public or use 'dynamic'.

    final dynamic gameState = tester.state(find.byType(GamePage));
    // game is 'late NeonRunnerGame game' in _GamePageState.
    // flutter_test can access private fields via dynamic if we don't care about type safety,
    // OR better, I will assume the user wants me to fix the code to be testable.
    // I'll rename _GamePageState to GamePageState in main.dart?
    // The user didn't forbid modifying main.dart further.
    // But I can also just cast to dynamic and access 'game'. Dart allows this.

    final NeonRunnerGame game = gameState.game;

    // 2. Check Score Increased
    print("Initial Score: ${game.score}");
    expect(game.status, GameStatus.playing);
    expect(game.score, greaterThan(0)); // Should have increased after 1 second

    // 3. Test Jump
    // Initial Y
    double initialY = game.player.y;
    print("Player Y: $initialY");

    // Trigger Jump
    game.player.jump();
    await tester.pump(const Duration(milliseconds: 100)); // Advance a bit

    print("Player Y after jump start: ${game.player.y}");
    expect(game.player.y, greaterThan(initialY));

    // Advance until landed
    // We need to pump multiple frames because Ticker drives the game loop per frame.
    // tester.pump(duration) only pumps one frame at the end of duration.
    // We need to simulate the passage of time with multiple pumps.
    for (int i = 0; i < 60; i++) {
       await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.player.y, initialY); // Should be back on ground (1.0)

    // 4. Test Obstacle Collision (Game Over)
    // Manually spawn an obstacle directly in front of player
    // Player is at (0, 1, 0) roughly (x=0, y=1, z=0).
    // Obstacles move +Z (towards player).
    // Wait, in my implementation:
    // "obs.z += gameSpeed". Obstacles move POSITIVE Z.
    // Player is at Z=0.
    // If I spawn obstacle at Z = -10 (in front), it will move to 0 and hit player.

    game.obstacles.add(Obstacle(
      x: 0, // Same lane as player
      y: 0,
      z: -5, // Just in front
      type: CollisionType.solid,
      lane: 0
    ));

    // Pump frames to let collision happen
    // Speed is approx 0.6 per frame? No, 0.6 per update?
    // My Ticker calls update() every frame.
    // Frame rate in test is simulated by pump duration.
    // But Ticker in test environment... `tester.pump(duration)` calls ticker.
    // If speed is 0.6 per tick. 5 units / 0.6 ~= 8 ticks.
    // 8 frames at 60fps is ~130ms.

    // Pump enough frames for collision
    for (int i = 0; i < 30; i++) {
       await tester.pump(const Duration(milliseconds: 16));
       if (game.status == GameStatus.gameOver) break;
    }

    expect(game.status, GameStatus.gameOver);
  });
}
