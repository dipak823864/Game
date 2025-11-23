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
  // Player is stationary in Z relative to camera/world origin for collision logic usually, but here obstacles move relative to player.
  // In the TS code, player is at 0,1,0. Obstacles move +Z.

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
    // Using simple lerp
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
        if (rollTimer <= 0) {
          isRolling = false;
        }
      }
    }
  }
}

class Obstacle {
  Vector3 position;
  CollisionType type;
  bool active = true;
  int lane;

  // Dimensions for AABB
  Vector3 size;

  Obstacle({
    required double x,
    required double y,
    required double z,
    required this.type,
    required this.lane,
    Vector3? size,
  }) : position = Vector3(x, y, z),
       size = size ?? _getSizeForType(type);

  static Vector3 _getSizeForType(CollisionType type) {
    switch (type) {
      case CollisionType.coin:
        return Vector3(1.0, 1.0, 1.0);
      case CollisionType.solid:
         return Vector3(3.6, 4.0, 3.6);
      case CollisionType.jump:
         return Vector3(3.5, 1.5, 0.5); // Approximate
      case CollisionType.duck:
         return Vector3(3.8, 1.0, 1.0);
    }
  }
}

class RoadSegment {
  Vector3 position;
  RoadSegment(double z) : position = Vector3(0, 0, z);
}

class NeonRunnerGame {
  GameStatus status = GameStatus.menu;
  Player player = Player();
  List<Obstacle> obstacles = [];
  List<RoadSegment> roadSegments = [];
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
    roadSegments.clear();
    lastSafeLane = 0;

    // Init road
    for (int i = 0; i < 25; i++) {
        roadSegments.add(RoadSegment(-i * 10.0));
    }
  }

  void update() {
    if (status != GameStatus.playing) return;

    // Update Speed and Score
    gameSpeed = min(GameConfig.maxSpeed, gameSpeed + GameConfig.speedIncrement);
    distanceTraveled += gameSpeed;
    score = (distanceTraveled * 10).floor();

    // Update Player
    player.update();

    // Update Road
    for (var segment in roadSegments) {
        segment.position.z += gameSpeed;
        if (segment.position.z > 15) {
            segment.position.z -= 250;
        }
    }

    // Update Obstacles
    for (int i = obstacles.length - 1; i >= 0; i--) {
      Obstacle obs = obstacles[i];
      obs.position.z += gameSpeed; // Moving towards positive Z (towards camera/player)

      // Collision Detection
      if (obs.active) {
        // Player is at position (dynamic), z=0 (mostly).
        // Obstacle is at obs.position.

        double dx = (obs.position.x - player.position.x).abs();
        double dz = obs.position.z; // since player.z is 0

        // Using simple distance check as requested in Step 1, but user asked for AABB later in tests.
        // For now, keeping logic similar to TS port for gameplay consistency, upgrading to Vector3 access.

        // TS Logic: if (dz > -1.0 && dz < 1.0 && dx < 1.2)
        if (dz > -1.0 && dz < 1.0 && dx < 1.2) {
          if (obs.type == CollisionType.coin) {
             score += 500;
             obs.active = false;
          } else {
             bool safe = false;
             // Logic based on TS
             if (obs.type == CollisionType.jump && player.position.y > 1.2) {
               safe = true;
             } else if (obs.type == CollisionType.duck && player.isRolling) {
               safe = true;
             }

             if (!safe) {
               gameOver();
             }
          }
        }
      }

      // Remove if passed camera
      if (obs.position.z > 15) {
        obstacles.removeAt(i);
      }
    }

    // Spawning Logic
    const double spawnZ = -180;
    double minGap = 50 + (gameSpeed * 30);

    if (obstacles.isEmpty || obstacles.last.position.z > (spawnZ + minGap)) {
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
      x: x,
      y: 1.5,
      z: z,
      type: CollisionType.coin,
      lane: laneIdx,
    ));
  }

  void spawnObstacle(double x, double z, int laneIdx) {
    double r = Random().nextDouble();
    CollisionType type = CollisionType.solid;

    if (r < 0.25) {
      type = CollisionType.jump;
    } else if (r < 0.5) {
      type = CollisionType.duck;
    }

    obstacles.add(Obstacle(
      x: x,
      y: (type == CollisionType.jump) ? 0.25 : (type == CollisionType.duck ? 3.0 : 2.0), // Approximate centers based on TS
      z: z,
      type: type,
      lane: laneIdx,
    ));
  }

  void gameOver() {
    status = GameStatus.gameOver;
  }
}
