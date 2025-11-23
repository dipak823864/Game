import 'dart:math';

enum GameState {
  MENU,
  PLAYING,
  GAME_OVER,
}

enum CollisionType {
  SOLID,
  JUMP,
  DUCK,
  COIN,
}

class GameConfig {
  static const double laneWidth = 4.0;
  static const double startSpeed = 0.6;
  static const double maxSpeed = 2.8;
  static const double speedIncrement = 0.0002;
  static const double jumpForce = 0.38;
  static const double gravity = 0.020;
  static const double visibilityRange = 350.0;
  static const double playerBaseY = 1.0;
}

class Player {
  int lane = 0; // -1, 0, 1
  double x = 0.0;
  double y = GameConfig.playerBaseY;
  double velocityY = 0.0;
  bool isJumping = false;
  bool isRolling = false;
  int rollTimer = 0;
  double rotationZ = 0.0;
  double rotationX = 0.0;

  void reset() {
    lane = 0;
    x = 0.0;
    y = GameConfig.playerBaseY;
    velocityY = 0.0;
    isJumping = false;
    isRolling = false;
    rollTimer = 0;
    rotationZ = 0.0;
    rotationX = 0.0;
  }
}

class Obstacle {
  double x;
  double y; // mostly 0, but coins are higher
  double z;
  CollisionType type;
  int lane;
  bool active = true;
  double rotationY = 0.0; // for coin spin
  double rotationX = 0.0; // for coin spin

  Obstacle({
    required this.x,
    required this.y,
    required this.z,
    required this.type,
    required this.lane,
  });
}

class Particle {
  double x, y, z;
  double vx, vy, vz;
  double life;
  int color; // 0xAARRGGBB

  Particle({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    this.life = 1.0,
    required this.color,
  });
}

class NeonRunnerGame {
  GameState state = GameState.MENU;
  Player player = Player();
  List<Obstacle> obstacles = [];
  List<Particle> particles = [];

  double score = 0;
  double distanceTraveled = 0;
  double gameSpeed = GameConfig.startSpeed;
  int lastSafeLane = 0;

  // To handle spawning intervals
  double _lastSpawnZ = 0.0;

  void start() {
    state = GameState.PLAYING;
    score = 0;
    distanceTraveled = 0;
    gameSpeed = GameConfig.startSpeed;
    player.reset();
    obstacles.clear();
    particles.clear();
    lastSafeLane = 0;
    _lastSpawnZ = -180.0; // Initial spawn point

    // Initial spawn
    spawnObstacleRow(-180.0);
  }

  void update() {
    if (state != GameState.PLAYING) return;

    // 1. Update Game Speed and Score
    gameSpeed = min(GameConfig.maxSpeed, gameSpeed + GameConfig.speedIncrement);
    distanceTraveled += gameSpeed;
    score = (distanceTraveled * 10).floorToDouble();

    // 2. Player Physics
    final double targetX = player.lane * GameConfig.laneWidth;

    // Smooth movement (Lerp)
    player.x += (targetX - player.x) * 0.3;

    // Lean
    double targetLean = (targetX - player.x) * -0.15;
    player.rotationZ += (targetLean - player.rotationZ) * 0.1;

    // Jumping
    if (player.isJumping) {
      player.y += player.velocityY;
      player.velocityY -= GameConfig.gravity;
      player.rotationX = -0.2;

      if (player.y <= GameConfig.playerBaseY) {
        player.y = GameConfig.playerBaseY;
        player.isJumping = false;
        player.velocityY = 0;
        player.rotationX = 0;
        createExplosion(player.x, player.y, 0, 0xFF00FFFF, 5);
      }
    } else {
      player.rotationX = 0;
      if (player.isRolling) {
        player.rollTimer--;
        if (player.rollTimer <= 0) {
          player.isRolling = false;
        }
      }
    }

    // 3. Update Obstacles
    for (int i = obstacles.length - 1; i >= 0; i--) {
      final obs = obstacles[i];
      obs.z += gameSpeed;

      // Coin spin
      if (obs.type == CollisionType.COIN) {
        obs.rotationY += 0.05;
        obs.rotationX += 0.02;
      }

      // Cleanup
      if (obs.z > 15) {
        obstacles.removeAt(i);
        continue;
      }

      // Collision Detection
      if (obs.active) {
        double dx = (obs.x - player.x).abs();
        double dz = obs.z; // Player is at 0

        // Simple Hitbox
        // Player width ~ 1.0, Obstacle width ~ depends on type
        // Collision zone: z between -1.0 and 1.0
        if (dz > -1.0 && dz < 1.0 && dx < 1.2) {
          if (obs.type == CollisionType.COIN) {
            score += 500; // Visual score? actual score is distance based.
            // In original code: this.score += 500. But score is also recalculated every frame from distance.
            // Actually in original code: score = floor(distance * 10); onScoreChange(score).
            // AND inside collision: score += 500.
            // This is a bug in original code if score is reset every frame.
            // Let's assume we add bonus to distance to simulate score increase?
            // Or just keep a separate bonusScore.
            // To match original behavior (even if buggy) or fix it?
            // Original: `this.score = Math.floor(this.distanceTraveled * 10);` then `this.score += 500`.
            // This means the +500 is immediately overwritten next frame. Lol.
            // I will fix this by adding to distanceTraveled equivalent.
            distanceTraveled += 50; // 50 * 10 = 500 score

            createExplosion(obs.x, obs.y, obs.z, 0xFFFFFF00, 10);
            obs.active = false;
          } else {
            bool safe = false;
            if (obs.type == CollisionType.JUMP && player.y > 1.2) {
              safe = true;
            } else if (obs.type == CollisionType.DUCK && player.isRolling) {
              safe = true;
            }
            // SOLID is never safe

            if (!safe) {
              gameOver();
            }
          }
        }
      }
    }

    // 4. Spawning
    // Spawn at -180.
    // If last obstacle Z > (-180 + minGap), spawn new row.
    // minGap = 50 + (gameSpeed * 30).
    double minGap = 50 + (gameSpeed * 30);

    // Find the most distant obstacle (smallest Z)
    double mostDistantZ = 0;
    if (obstacles.isNotEmpty) {
      mostDistantZ = obstacles.fold(0.0, (prev, element) => min(prev, element.z));
    }

    // If no obstacles or enough gap
    if (obstacles.isEmpty || mostDistantZ > (-180 + minGap)) {
       spawnObstacleRow(-180);
    }

    // 5. Update Particles
    for (int i = particles.length - 1; i >= 0; i--) {
      var p = particles[i];
      p.life -= 0.04;
      p.x += p.vx;
      p.y += p.vy;
      p.z += p.vz;
      if (p.life <= 0) {
        particles.removeAt(i);
      }
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
          createObstacleAt(x, z, laneIdx);
        }
      }
    }
  }

  void createObstacleAt(double x, double z, int laneIdx) {
    double typeRand = Random().nextDouble();
    CollisionType type;

    if (typeRand < 0.25) {
      type = CollisionType.JUMP;
    } else if (typeRand < 0.5) {
      type = CollisionType.DUCK;
    } else {
      type = CollisionType.SOLID;
    }

    obstacles.add(Obstacle(
      x: x,
      y: 0,
      z: z,
      type: type,
      lane: laneIdx
    ));
  }

  void spawnCoin(double x, double z, int laneIdx) {
    obstacles.add(Obstacle(
      x: x,
      y: 1.5,
      z: z,
      type: CollisionType.COIN,
      lane: laneIdx
    ));
  }

  void createExplosion(double x, double y, double z, int color, int count) {
    final rand = Random();
    for(int i=0; i<count; i++) {
      particles.add(Particle(
        x: x, y: y, z: z,
        vx: (rand.nextDouble() - 0.5),
        vy: (rand.nextDouble() - 0.5) + 0.5,
        vz: (rand.nextDouble() - 0.5),
        color: color
      ));
    }
  }

  void gameOver() {
    state = GameState.GAME_OVER;
    createExplosion(player.x, player.y, 0, 0xFFFF0000, 50);
  }

  // Controls
  void moveLeft() { if (player.lane > -1) player.lane--; }
  void moveRight() { if (player.lane < 1) player.lane++; }
  void jump() {
    if (!player.isJumping) {
      player.isJumping = true;
      player.velocityY = GameConfig.jumpForce;
      player.isRolling = false;
    }
  }
  void roll() {
    if (!player.isJumping && !player.isRolling) {
      player.isRolling = true;
      player.rollTimer = 40;
    }
  }
}
