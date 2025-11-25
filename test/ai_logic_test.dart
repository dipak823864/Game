import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:my_editor/models.dart';
import 'package:my_editor/game_engine.dart';

void main() {
  test('AI Logic Verification', () {
    // 1. Setup
    final game = GameEngine();
    game.start();
    game.toggleAutoPilot(true);

    // 2. Scenario: Deadly Obstacle in Current Lane (0)
    // Place solid obstacle at z=-50 (approaching)
    game.obstacles.add(Obstacle(
      position: Vector3(0, 2, -50),
      size: Vector3(3.6, 4.0, 3.6),
      type: CollisionType.solid,
      lane: 0,
    ));

    // 3. Execute AI Logic
    game.updateAI();

    // 4. Assertions
    print("AI Action: ${game.aiState.action}");
    print("Target Lane: ${game.aiState.targetLane}");

    expect(game.aiState.targetLane, isNot(0)); // Should switch lane
    expect(game.aiState.action, equals(AIAction.dodge));
  });

  test('AI Jump Logic Verification', () {
    final game = GameEngine();
    game.start();
    game.toggleAutoPilot(true);

    // Scenario: Jumpable Obstacle
    // Place it closer (z=-15) so timeToImpact (15/0.6 = 25 frames) is within reaction window (27.5 frames)
    game.obstacles.add(Obstacle(
      position: Vector3(0, 0.5, -15),
      size: Vector3(3.5, 0.8, 0.5),
      type: CollisionType.jump,
      lane: 0,
    ));

    game.updateAI();

    print("AI Action: ${game.aiState.action}");

    expect(game.aiState.action, equals(AIAction.jump));
    expect(game.player.isJumping, isTrue);
  });
}
