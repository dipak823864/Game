import 'package:flutter/material.dart';
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
      theme: ThemeData.dark(),
      home: const NeonRunnerPage(),
    );
  }
}

class NeonRunnerPage extends StatefulWidget {
  const NeonRunnerPage({super.key});

  @override
  State<NeonRunnerPage> createState() => NeonRunnerPageState();
}

class NeonRunnerPageState extends State<NeonRunnerPage> with SingleTickerProviderStateMixin {
  late NeonRunnerGame game;
  late AnimationController _repaintController;

  @override
  void initState() {
    super.initState();
    game = NeonRunnerGame();

    // Use AnimationController to drive the game loop.
    // It provides the Ticker and handles the repaint notifications.
    _repaintController = AnimationController(
      vsync: this,
      duration: const Duration(days: 1), // Infinite duration effectively
    );

    _repaintController.addListener(() {
      // Update game logic every frame
      game.update();
      // No need for setState() because CustomPainter listens to _repaintController (passed as repaint arg)
    });

    _repaintController.repeat();
  }

  @override
  void dispose() {
    _repaintController.dispose();
    super.dispose();
  }

  // --- Input Handling ---

  void _handleTap() {
    if (game.state == GameState.MENU || game.state == GameState.GAME_OVER) {
      game.start();
    } else {
      game.jump();
    }
  }

  void _handleSwipe(DragEndDetails details) {
    if (game.state != GameState.PLAYING) return;

    if (details.primaryVelocity != null) {
      // Horizontal
      if (details.primaryVelocity!.abs() > details.velocity.pixelsPerSecond.dy.abs()) {
          if (details.primaryVelocity! > 0) {
            game.moveRight();
          } else {
            game.moveLeft();
          }
      } else {
        // Vertical
        if (details.primaryVelocity! < 0) {
           game.jump();
        } else {
           game.roll();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _handleTap,
        onPanEnd: _handleSwipe, // Handles swipe
        child: SizedBox.expand(
          child: CustomPaint(
            painter: GamePainter(
              game: game,
              repaint: _repaintController
            ),
          ),
        ),
      ),
    );
  }
}
