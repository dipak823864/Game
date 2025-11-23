import 'dart:math';
import 'package:vector_math/vector_math_64.dart';

enum GameStatus { menu, playing, gameOver }
enum CollisionType { solid, jump, duck, coin }

class GameConfig {
  static const double laneWidth = 4.0;
  static const double startSpeed = 0.6;
  static const double maxSpeed = 2.8;
  static const double speedIncrement = 0.0002;
  static const double jumpForce = 0.38;
  static const double gravity = 0.020;
  static const double playerBaseY = 1.0;
}

class Player {
  Vector3 position = Vector3(0, GameConfig.playerBaseY, 0);
  Vector3 size = Vector3(1, 1, 1); // Width, Height, Depth

  int currentLane = 0; // -1, 0, 1
  double velocityY = 0;
  bool isJumping = false;
  bool isRolling = false;
  int rollTimer = 0;

  void jump() {
    if (!isJumping) {
      isJumping = true;
      velocityY = GameConfig.jumpForce;
      isRolling = false;
    }
  }

  void roll() {
    if (!isJumping && !isRolling) {
      isRolling = true;
      rollTimer = 40;
    }
  }

  void moveLeft() {
    if (currentLane > -1) currentLane--;
  }

  void moveRight() {
    if (currentLane < 1) currentLane++;
  }

  void update() {
    // X Movement (Lerp)
    double targetX = currentLane * GameConfig.laneWidth;
    position.x += (targetX - position.x) * 0.3;
    if ((position.x - targetX).abs() < 0.05) position.x = targetX;

    // Y Movement (Jump)
    if (isJumping) {
      position.y += velocityY;
      velocityY -= GameConfig.gravity;

      if (position.y <= GameConfig.playerBaseY) {
        position.y = GameConfig.playerBaseY;
        isJumping = false;
        velocityY = 0;
      }
    } else {
      // Roll Logic
      if (isRolling) {
        rollTimer--;
        size.y = 0.5; // Squish
        if (rollTimer <= 0) {
          isRolling = false;
          size.y = 1.0;
        }
      } else {
        size.y = 1.0;
      }
    }
  }

  Aabb3 get bounds {
    // AABB centered at x,z but base at y=position.y?
    // Usually position is center or base. Let's assume position is BASE center for X/Z but Y is feet?
    // In TS code: `this.player.position.set(0, 1, 0);` and geometry is around it.
    // Let's assume position is Center of the bounding box for simplicity in logic,
    // OR position is feet position and we extend up.
    // Config: playerBaseY = 1.0. If position.y = 1.0, that's the center?
    // TS: fuselage.position.y = 0.5. Player Group at 1.0.
    // Let's treat 'position' as the center of the object.

    return Aabb3.minMax(
      position - (size * 0.5),
      position + (size * 0.5)
    );
  }
}

class Obstacle {
  Vector3 position;
  Vector3 size;
  CollisionType type;
  bool active = true;
  int lane;

  Obstacle({
    required this.position,
    required this.size,
    required this.type,
    required this.lane,
  });

  Aabb3 get bounds {
    return Aabb3.minMax(
      position - (size * 0.5),
      position + (size * 0.5)
    );
  }
}

class NeonRunnerGame {
  GameStatus status = GameStatus.menu;
  Player player = Player();
  List<Obstacle> obstacles = [];
  double gameSpeed = GameConfig.startSpeed;
  double distanceTraveled = 0;
  int score = 0;
  int lastSafeLane = 0;

  void start() {
    status = GameStatus.playing;
    score = 0;
    distanceTraveled = 0;
    gameSpeed = GameConfig.startSpeed;
    player = Player();
    obstacles.clear();
    lastSafeLane = 0;
  }

  void update() {
    if (status != GameStatus.playing) return;

    // Update Speed and Score
    gameSpeed = min(GameConfig.maxSpeed, gameSpeed + GameConfig.speedIncrement);
    distanceTraveled += gameSpeed;
    score = (distanceTraveled * 10).floor();

    // Update Player
    player.update();

    // Update Obstacles
    for (int i = obstacles.length - 1; i >= 0; i--) {
      Obstacle obs = obstacles[i];
      // Objects move towards positive Z (towards camera)
      // Camera is at +Z looking at -Z?
      // In TS code: Camera at (0, 6, 14). LookAt (0, 2, -10).
      // Obstacles move +Z. Player is at 0.
      // So obstacles come from negative Z to positive Z.

      obs.position.z += gameSpeed;

      // Collision Detection (AABB Intersect)
      if (obs.active) {
        // Simple AABB check
        if (player.bounds.intersectsWithAabb3(obs.bounds)) {
           if (obs.type == CollisionType.coin) {
             score += 500;
             obs.active = false;
           } else {
             // Logic check for Jump/Duck overrides AABB if properly executed
             // Actually, physical intersection usually means death unless special case.
             // TS Logic: "Precise hitboxes... if Jump && y > 1.2 safe".
             // We can check type.

             bool safe = false;
             if (obs.type == CollisionType.jump && player.position.y > 1.2) { // Jump over
                // The AABB check might fail if we are high enough.
                // Wait, if AABB intersects, it means we touched it.
                // If we are high enough, AABB y-min > Obstacle y-max.
                // So intersectsWithAabb3 would return FALSE.
                // So if it returns TRUE, we hit it.
                // UNLESS the 'jump' obstacle is just the base, and we clear the base.
                // But if 'Jump' type means "Energy Barrier", we might hit the top part?
                // TS: "Jump (Energy Barrier) - Must Jump OVER".
                // If we physically intersect, we die.
                // So logic is: if AABB intersects, it's a hit.
                // BUT, maybe the obstacle size accounts for the gap?
                // Let's keep it simple: Real 3D collision.
                // If bounding boxes touch, you crash.
                // So if Player jumps high, his Y increases. His AABB moves up.
                // If he clears the obstacle AABB, no intersection.

                safe = false; // If we intersected, we failed to jump high enough OR obstacle is too tall.
             }

             // Wait, for 'Jump' type, maybe the player *should* clear it.
             // If intersectsWithAabb3 is true, it means he didn't clear it.
             // So safe = false.

             // However, maybe the 'Jump' obstacle has a lower height than the visual?
             // Or maybe we treat it as: if type is Jump, checking AABB is correct.
             // If he jumps, he won't intersect.

             if (!safe) {
               status = GameStatus.gameOver;
             }
           }
        }
      }

      // Remove if passed camera (Camera Z is 14)
      if (obs.position.z > 20) {
        obstacles.removeAt(i);
      }
    }

    // Spawning Logic
    const double spawnZ = -180;
    double minGap = 50 + (gameSpeed * 30);

    // Check if we need to spawn (find the furthest obstacle, which is lowest Z)
    double lowestZ = 0;
    if (obstacles.isNotEmpty) {
       // Obstacles are sorted? No.
       // We iterate to find min Z.
       lowestZ = obstacles.fold(0.0, (min, obs) => obs.position.z < min ? obs.position.z : min);
    }

    // If no obstacles or the furthest one has moved closer than (spawnZ + gap)
    if (obstacles.isEmpty || lowestZ > (spawnZ + minGap)) {
      spawnObstacleRow(spawnZ);
    }
  }

  void spawnObstacleRow(double z) {
    List<int> possibleLanes = [lastSafeLane];
    if (lastSafeLane > -1) possibleLanes.add(lastSafeLane - 1);
    if (lastSafeLane < 1) possibleLanes.add(lastSafeLane + 1);

    int safeLaneIdx = possibleLanes[Random().nextInt(possibleLanes.length)];
    lastSafeLane = safeLaneIdx;

    for (int laneIdx = -1; laneIdx <= 1; laneIdx++) {
      double x = laneIdx * GameConfig.laneWidth;

      if (laneIdx == safeLaneIdx) {
        if (Random().nextDouble() < 0.3) {
          spawnCoin(x, z, laneIdx);
        }
      } else {
        if (Random().nextDouble() < 0.8) {
          spawnObstacle(x, z, laneIdx);
        }
      }
    }
  }

  void spawnCoin(double x, double z, int laneIdx) {
    obstacles.add(Obstacle(
      position: Vector3(x, 1.5, z),
      size: Vector3(0.5, 0.5, 0.1),
      type: CollisionType.coin,
      lane: laneIdx,
    ));
  }

  void spawnObstacle(double x, double z, int laneIdx) {
    double r = Random().nextDouble();
    CollisionType type = CollisionType.solid;
    Vector3 size = Vector3(3.6, 4.0, 3.6);
    double y = 2.0; // Center Y

    if (r < 0.25) {
      type = CollisionType.jump;
      // Low barrier
      size = Vector3(3.5, 0.8, 0.5);
      y = 0.5;
    } else if (r < 0.5) {
      type = CollisionType.duck;
      // High barrier (Overhead)
      size = Vector3(3.8, 1.0, 1.0);
      y = 3.0;
    }

    obstacles.add(Obstacle(
      position: Vector3(x, y, z),
      size: size,
      type: type,
      lane: laneIdx,
    ));
  }
}
