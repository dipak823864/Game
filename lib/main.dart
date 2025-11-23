import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'models.dart';
import 'game_painter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Runner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => GamePageState();
}

class GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  late NeonRunnerGame game;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    game = NeonRunnerGame();
    _ticker = createTicker((Duration elapsed) {
      setState(() {
        game.update();
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (game.status == GameStatus.menu || game.status == GameStatus.gameOver) {
      game.start();
    } else {
      // Tap usually means Jump in simple runners, but we have swipes.
      // Let's make tap also Jump for convenience.
      game.player.jump();
    }
  }

  void _handleSwipe(DragEndDetails details) {
    if (game.status != GameStatus.playing) return;

    double dx = details.velocity.pixelsPerSecond.dx;
    double dy = details.velocity.pixelsPerSecond.dy;

    if (dx.abs() > dy.abs()) {
      // Horizontal
      if (dx > 0) {
        game.player.moveRight();
      } else {
        game.player.moveLeft();
      }
    } else {
      // Vertical
      if (dy < 0) {
        game.player.jump();
      } else {
        game.player.roll();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _handleTap,
        onPanEnd: _handleSwipe, // Using PanEnd to detect swipes
        child: Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: CustomPaint(
            painter: GamePainter(game),
          ),
        ),
      ),
    );
  }
}
