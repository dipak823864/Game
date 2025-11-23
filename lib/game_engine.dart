import 'dart:math';
import 'package:vector_math/vector_math_64.dart';
import 'models.dart';

class GameEngine {
  GameStatus status = GameStatus.menu;
  Player player = Player();
  List<Obstacle> obstacles = [];
  double gameSpeed = GameConfig.startSpeed;
  double distanceTraveled = 0;
  int score = 0;
  int lastSafeLane = 0;

  // AI
  bool autoPilotEnabled = false;
  int aiLaneChangeCooldown = 0;
  AIState aiState = AIState();
  AISettings aiSettings = AISettings();
  AudioSettings audioSettings = AudioSettings();

  void start() {
    status = GameStatus.playing;
    score = 0;
    distanceTraveled = 0;
    gameSpeed = GameConfig.startSpeed;
    player = Player();
    obstacles.clear();
    lastSafeLane = 0;
    autoPilotEnabled = false;
  }

  void update() {
    if (status != GameStatus.playing) return;

    // Speed & Score
    gameSpeed = min(GameConfig.maxSpeed, gameSpeed + GameConfig.speedIncrement);
    distanceTraveled += gameSpeed;
    score = (distanceTraveled * 10).floor();

    // AI
    if (autoPilotEnabled) updateAI();

    // Player Physics
    double targetX = player.currentLane * GameConfig.laneWidth;
    double lerpFactor = autoPilotEnabled ? 0.1 : 0.3;

    player.position.x += (targetX - player.position.x) * lerpFactor;

    if ((player.position.x - targetX).abs() < 0.05) player.position.x = targetX;

    // Lean
    double targetLean = (targetX - player.position.x) * -0.15;
    player.rotationZ += (targetLean - player.rotationZ) * 0.1;

    if (player.isJumping) {
      player.position.y += player.velocityY;
      player.velocityY -= GameConfig.gravity;
      player.rotationX = -0.2;

      if (player.position.y <= GameConfig.playerBaseY) {
        player.position.y = GameConfig.playerBaseY;
        player.isJumping = false;
        player.velocityY = 0;
        player.rotationX = 0;
      }
    } else {
      player.rotationX = 0;
      if (player.isRolling) {
        player.rollTimer--;
        player.size.y = 0.6;
        if (player.rollTimer <= 0) {
          player.isRolling = false;
          player.size.y = 1.0;
        }
      }
    }

    // Obstacles
    for (int i = obstacles.length - 1; i >= 0; i--) {
      Obstacle obs = obstacles[i];
      obs.position.z += gameSpeed;

      if (player.bounds.intersectsWithAabb3(obs.bounds) && obs.active) {
         if (obs.type == CollisionType.coin) {
           score += 500;
           obs.active = false;
         } else {
           bool safe = false;
           // "Precise hitboxes" ported logic
           double dx = (obs.position.x - player.position.x).abs();
           double dz = obs.position.z;

           if (dz > -1.0 && dz < 1.0 && dx < 1.2) {
             if (obs.type == CollisionType.jump && player.position.y > 1.2) safe = true;
             else if (obs.type == CollisionType.duck && player.isRolling) safe = true;

             if (!safe) {
               status = GameStatus.gameOver;
             }
           }
         }
      }

      if (obs.position.z > 20) {
        obstacles.removeAt(i);
      }
    }

    // Spawning
    const double spawnZ = -180;
    double minGap = 50 + (gameSpeed * 30);
    double lowestZ = 0;
    if (obstacles.isNotEmpty) {
       lowestZ = obstacles.fold(0.0, (min, obs) => obs.position.z < min ? obs.position.z : min);
    }

    if (obstacles.isEmpty || lowestZ > (spawnZ + minGap)) {
      spawnObstacleRow(spawnZ);
    }
  }

  void updateAI() {
    if (aiLaneChangeCooldown > 0) aiLaneChangeCooldown--;

    double currentSpeed = gameSpeed;
    double visionRange = 800 + (currentSpeed * 400);

    List<LaneAnalysis> analysis = [-1, 0, 1].map((l) => analyzeLane(l, visionRange)).toList();
    LaneAnalysis currentLaneStats = analysis.firstWhere((a) => a.lane == player.currentLane);
    analysis.sort((a, b) => b.score.compareTo(a.score));
    LaneAnalysis bestLaneAnalysis = analysis.first;

    int targetLane = player.currentLane;
    AIAction aiAction = AIAction.scanning;
    bool isEmergency = false;

    double riskFactor = 1.0 - (aiSettings.riskTolerance * 0.5);
    double emergencyThreshold = (100 + currentSpeed * 20) * riskFactor;

    if (currentLaneStats.firstSolidDist < emergencyThreshold) {
      isEmergency = true;
      aiLaneChangeCooldown = 0;
    }

    if (isEmergency) {
      if (bestLaneAnalysis.lane != player.currentLane) {
        int diff = bestLaneAnalysis.lane - player.currentLane;
        int direction = diff > 0 ? 1 : -1;
        int nextStepLane = player.currentLane + direction;

        // Find stats for next step
        LaneAnalysis nextStepAnalysis = analysis.firstWhere((a) => a.lane == nextStepLane, orElse: () => currentLaneStats); // fallback unsafe but ok
        // Actually we need to search in the original list, but 'analysis' is sorted now.
        // Let's re-find from sorted list or map.
        nextStepAnalysis = analysis.firstWhere((a) => a.lane == nextStepLane);

        if (!nextStepAnalysis.isBlockedSide) {
           bool isSafer = nextStepAnalysis.firstSolidDist > 20 && (nextStepAnalysis.firstSolidDist > currentLaneStats.firstSolidDist);
           bool isSafe = nextStepAnalysis.firstSolidDist > 30;

           if (isSafe || isSafer) {
             targetLane = nextStepLane;
             aiAction = AIAction.dodge;
           }
        } else {
          aiAction = AIAction.waiting;
        }
      }
    } else {
      if (aiLaneChangeCooldown <= 0) {
        double switchThreshold = aiSettings.heuristic == AIHeuristic.coins ? 20 : 100;
        if (bestLaneAnalysis.score > currentLaneStats.score + switchThreshold && bestLaneAnalysis.firstSolidDist > 400 * riskFactor) {
           LaneAnalysis targetStats = analysis.firstWhere((a) => a.lane == bestLaneAnalysis.lane);
           if (!targetStats.isBlockedSide) {
             targetLane = bestLaneAnalysis.lane;
             aiAction = AIAction.run;
             aiLaneChangeCooldown = 30;
           }
        }
      }
    }

    if (targetLane != player.currentLane) {
      setLane(targetLane);
    }

    LaneAnalysis effectiveLaneStats = analysis.firstWhere((a) => a.lane == player.currentLane);

    // Action execution
    if (effectiveLaneStats.action != AIAction.scanning && effectiveLaneStats.action != AIAction.waiting) {
       // Note: analyzeLane returns 'jump' or 'duck' in action field based on threat logic
       // But my LaneAnalysis struct uses AIAction enum. I need to map it carefully.
       // The 'analyzeLane' logic sets 'jump' or 'duck'.

       double dist = effectiveLaneStats.distanceToThreat;
       double timeToImpactFrames = dist / gameSpeed;
       double reactionWindow = 25 * (1 + aiSettings.riskTolerance * 0.2);

       if (effectiveLaneStats.action == AIAction.jump) {
         if (timeToImpactFrames < reactionWindow && timeToImpactFrames > 5) {
           jump();
           aiAction = AIAction.jump;
         }
       } else if (effectiveLaneStats.action == AIAction.duck) {
         if (timeToImpactFrames < reactionWindow && timeToImpactFrames > 5) {
           roll();
           aiAction = AIAction.duck;
         }
       }
    }

    // Update AI State for UI
    aiState = AIState(
      enabled: autoPilotEnabled,
      currentLane: player.currentLane,
      targetLane: targetLane,
      action: aiAction,
      confidence: isEmergency ? 20 : 100,
      nearestThreatDist: currentLaneStats.distanceToThreat,
      laneScores: [-1,0,1].map((l) => analysis.firstWhere((a) => a.lane == l).score).toList()
    );
  }

  LaneAnalysis analyzeLane(int laneIdx, double range) {
    bool isDeadly = false;
    bool isBlockedSide = false;
    AIAction action = AIAction.scanning; // Default 'none'
    double score = 5000;
    double distToThreat = 9999;
    double firstSolidDist = 9999;
    CollisionType threatType = CollisionType.none;

    List<Obstacle> laneObs = obstacles.where((o) => o.active && o.lane == laneIdx && o.position.z > -range && o.position.z < 10).toList();
    laneObs.sort((a, b) => b.position.z.compareTo(a.position.z));

    for (var obs in laneObs) {
      double z = obs.position.z;
      double dist = z.abs();

      if (z > -4 && z < 5) {
        if (obs.type != CollisionType.coin) {
          isBlockedSide = true;
          score = -999999;
        }
      }

      if (obs.type == CollisionType.coin) {
        double coinWeight = aiSettings.heuristic == AIHeuristic.coins ? 150 : 30;
        score += coinWeight;
      } else {
        if (z < 0) {
          if (dist < distToThreat) {
            distToThreat = dist;
            threatType = obs.type;
          }

          if (obs.type == CollisionType.solid) {
             isDeadly = true;
             if (dist < firstSolidDist) firstSolidDist = dist;
             score -= (100000 / (dist + 1));
          } else if (obs.type == CollisionType.jump) {
             if (action == AIAction.scanning) action = AIAction.jump;
             score -= 100;
             if (player.isRolling && dist < 30) score -= 5000;
          } else if (obs.type == CollisionType.duck) {
             if (action == AIAction.scanning) action = AIAction.duck;
             score -= 100;
             if (player.isJumping && dist < 30) score -= 5000;
          }
        }
      }
    }

    if (laneIdx == 0) score += 10; // Center bias

    return LaneAnalysis(
      lane: laneIdx,
      isDeadly: isDeadly,
      isBlockedSide: isBlockedSide,
      action: action,
      score: score,
      distanceToThreat: distToThreat,
      threatType: threatType,
      firstSolidDist: firstSolidDist
    );
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
    double y = 2.0;

    if (r < 0.25) {
      type = CollisionType.jump;
      size = Vector3(3.5, 0.8, 0.5);
      y = 0.5;
    } else if (r < 0.5) {
      type = CollisionType.duck;
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

  void moveLeft() { if (player.currentLane > -1) player.currentLane--; }
  void moveRight() { if (player.currentLane < 1) player.currentLane++; }
  void setLane(int l) { player.currentLane = l; }
  void jump() { player.jump(); }
  void roll() { player.roll(); }
  void toggleAutoPilot(bool v) { autoPilotEnabled = v; }
}
