import 'dart:math';

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
  double x = 0;
  double y = GameConfig.playerBaseY;
  double z = 0; // Player is stationary in Z relative to camera/world origin for collision logic usually, but here obstacles move relative to player.
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
    x += (targetX - x) * 0.3; // Using the non-autopilot lerp factor from TS
    if ((x - targetX).abs() < 0.05) x = targetX;

    // Y Movement (Jump)
    if (isJumping) {
      y += velocityY;
      velocityY -= GameConfig.gravity;

      if (y <= GameConfig.playerBaseY) {
        y = GameConfig.playerBaseY;
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
  double x;
  double y;
  double z;
  CollisionType type;
  bool active = true;
  int lane;

  Obstacle({
    required this.x,
    required this.y,
    required this.z,
    required this.type,
    required this.lane,
  });
}

class NeonRunnerGame {
  GameStatus status = GameStatus.menu;
  Player player = Player();
  List<Obstacle> obstacles = [];
  double gameSpeed = GameConfig.startSpeed;
  double distanceTraveled = 0;
  int score = 0;
  int lastSafeLane = 0;

  // Callback for score/gameover if needed, but we can just poll the state

  void start() {
    status = GameStatus.playing;
    score = 0;
    distanceTraveled = 0;
    gameSpeed = GameConfig.startSpeed;
    player = Player();
    obstacles.clear();
    lastSafeLane = 0;

    // Initial spawn? The TS code spawns continuously.
    // "spawnZ = -180".
    // TS: spawnObstacleRow(spawnZ) if lastObs > (spawnZ + minGap)
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
      obs.z += gameSpeed; // Moving towards positive Z (towards camera/player)

      // Collision Detection
      if (obs.active) {
        // Player is at x (dynamic), z=0.
        // Obstacle is at obs.x, obs.z.

        double dx = (obs.x - player.x).abs();
        double dz = obs.z; // since player.z is 0

        // TS Logic: if (dz > -1.0 && dz < 1.0 && dx < 1.2)
        if (dz > -1.0 && dz < 1.0 && dx < 1.2) {
          if (obs.type == CollisionType.coin) {
             score += 500;
             obs.active = false; // "Collected"
             // visual effect skipped for logic
          } else {
             bool safe = false;
             if (obs.type == CollisionType.jump && player.y > 1.2) {
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
      if (obs.z > 15) {
        obstacles.removeAt(i);
      }
    }

    // Spawning Logic
    const double spawnZ = -180;
    double minGap = 50 + (gameSpeed * 30);

    // Check if we need to spawn
    // If no obstacles, or last obstacle is closer than (spawnZ + minGap)
    // Note: Obstacles are at negative Z moving to positive Z.
    // The "last obstacle" is the one most negative (furthest away).
    // In TS: obstacles.push() adds to end. So lastObs is the newest one spawned.
    // If lastObs.z > (spawnZ + minGap), we spawn new row at spawnZ.
    // Since spawnZ is -180, and obstacles move +, lastObs.z increases.
    // Example: spawn at -180. Gap 60. Wait until lastObs reaches -120. Then spawn new at -180.

    if (obstacles.isEmpty || obstacles.last.z > (spawnZ + minGap)) {
      spawnObstacleRow(spawnZ);
    }
  }

  void spawnObstacleRow(double z) {
    // Determine safe lane
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

    // In TS, they just create the group. Here we need the object logic.
    obstacles.add(Obstacle(
      x: x,
      y: 0, // Base Y usually
      z: z,
      type: type,
      lane: laneIdx,
    ));
  }

  void gameOver() {
    status = GameStatus.gameOver;
  }
}
