import 'package:vector_math/vector_math_64.dart';

enum GameStatus { menu, playing, paused, settings, gameOver }
enum CollisionType { solid, jump, duck, coin, none }
enum AIAction { run, jump, duck, dodge, scanning, waiting }
enum AIHeuristic { survival, coins }

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
  Vector3 position = Vector3(0, GameConfig.playerBaseY, 0);
  Vector3 size = Vector3(1, 1, 1);
  double rotationZ = 0;
  double rotationX = 0;

  int currentLane = 0;
  double velocityY = 0;
  bool isJumping = false;
  bool isRolling = false;
  int rollTimer = 0;

  Aabb3 get bounds => Aabb3.minMax(
    position - (size * 0.5),
    position + (size * 0.5)
  );

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

  Aabb3 get bounds => Aabb3.minMax(
    position - (size * 0.5),
    position + (size * 0.5)
  );
}

class AIState {
  bool enabled;
  int currentLane;
  int targetLane;
  AIAction action;
  double confidence;
  double nearestThreatDist;
  List<double> laneScores;

  AIState({
    this.enabled = false,
    this.currentLane = 0,
    this.targetLane = 0,
    this.action = AIAction.scanning,
    this.confidence = 0,
    this.nearestThreatDist = 0,
    this.laneScores = const [0, 0, 0],
  });
}

class AISettings {
  double riskTolerance;
  AIHeuristic heuristic;
  bool debugViz;
  bool showHUDButton;

  AISettings({
    this.riskTolerance = 0.5,
    this.heuristic = AIHeuristic.survival,
    this.debugViz = false,
    this.showHUDButton = true,
  });
}

class AudioSettings {
  double musicVolume;
  double engineVolume;
  double sfxVolume;

  AudioSettings({
    this.musicVolume = 0.5,
    this.engineVolume = 0.3,
    this.sfxVolume = 0.6,
  });
}

class LaneAnalysis {
  int lane;
  bool isDeadly;
  bool isBlockedSide;
  AIAction action; // Using AIAction subset logic mapped manually
  double score;
  double distanceToThreat;
  CollisionType threatType;
  double firstSolidDist;

  LaneAnalysis({
    required this.lane,
    this.isDeadly = false,
    this.isBlockedSide = false,
    this.action = AIAction.scanning, // 'none' equivalent?
    this.score = 0,
    this.distanceToThreat = 9999,
    this.threatType = CollisionType.none,
    this.firstSolidDist = 9999,
  });
}
