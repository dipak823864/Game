import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'game_engine.dart';
import 'game_painter.dart';
import 'ui_overlays.dart';

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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: kNeonCyan, secondary: kNeonPink),
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  late GameEngine game;
  late Ticker _ticker;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    game = GameEngine();
    _ticker = createTicker((Duration elapsed) {
      if (game.status == GameStatus.playing) {
        setState(() {
          game.update();
        });
      }
    });
    _ticker.start();
    _initialized = true;

    // Keyboard Listener
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    _ticker.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
       if (event.logicalKey == LogicalKeyboardKey.keyP) {
         setState(() {
           game.toggleAutoPilot(!game.autoPilotEnabled);
         });
         return true;
       }
       if (event.logicalKey == LogicalKeyboardKey.escape) {
         if (game.status == GameStatus.playing) {
           setState(() => game.status = GameStatus.paused);
         } else if (game.status == GameStatus.paused || game.status == GameStatus.settings) {
           setState(() => game.status = GameStatus.playing);
         }
         return true;
       }

       if (game.status == GameStatus.playing && !game.autoPilotEnabled) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.keyA) {
            game.moveLeft();
            return true;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.keyD) {
            game.moveRight();
            return true;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.keyW || event.logicalKey == LogicalKeyboardKey.space) {
            game.jump();
            return true;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.keyS) {
            game.roll();
            return true;
          }
       }
    }
    return false;
  }

  void _handleSwipe(DragEndDetails details) {
    if (game.status != GameStatus.playing || game.autoPilotEnabled) return;

    double dx = details.velocity.pixelsPerSecond.dx;
    double dy = details.velocity.pixelsPerSecond.dy;

    if (dx.abs() > dy.abs()) {
      if (dx.abs() > 30) {
        if (dx > 0) game.moveRight();
        else game.moveLeft();
      }
    } else {
      if (dy.abs() > 30) {
        if (dy < 0) game.jump();
        else game.roll();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: GestureDetector(
        onPanEnd: _handleSwipe,
        child: Stack(
          children: [
            // Game Layer
            Positioned.fill(
              child: CustomPaint(
                painter: GamePainter(game),
              ),
            ),

            // UI Layers
            if (game.status == GameStatus.menu)
              MainMenu(onStart: () => setState(() => game.start())),

            if (game.status != GameStatus.menu && game.status != GameStatus.gameOver)
              HUD(
                score: game.score,
                autoPilot: game.autoPilotEnabled,
                showHUDButton: game.aiSettings.showHUDButton,
                onToggleAutoPilot: () => setState(() => game.toggleAutoPilot(!game.autoPilotEnabled)),
                onPause: () => setState(() => game.status = GameStatus.paused),
                onSettings: () => setState(() => game.status = GameStatus.settings),
                aiState: game.aiState,
                debugViz: game.aiSettings.debugViz,
              ),

            if (game.status == GameStatus.settings)
              SettingsModal(
                audioSettings: game.audioSettings,
                aiSettings: game.aiSettings,
                onUpdateAudio: (s) => setState(() => game.audioSettings = s),
                onUpdateAI: (s) => setState(() => game.aiSettings = s),
                onClose: () => setState(() => game.status = GameStatus.playing),
                autoPilot: game.autoPilotEnabled,
                onToggleAutoPilot: (v) => setState(() => game.toggleAutoPilot(v)),
              ),

            if (game.status == GameStatus.paused)
              Container(
                color: Colors.black45,
                child: Center(
                  child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       const Text("PAUSED", style: TextStyle(color: Colors.white, fontSize: 40, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 20),
                       ElevatedButton(onPressed: () => setState(() => game.status = GameStatus.playing), child: const Text("RESUME")),
                       const SizedBox(height: 10),
                       TextButton(onPressed: () => setState(() { game.status = GameStatus.menu; }), child: const Text("EXIT", style: TextStyle(color: Colors.red))),
                     ],
                  ),
                ),
              ),

             if (game.status == GameStatus.gameOver)
               Container(
                 color: Colors.red.withOpacity(0.3),
                 child: Center(
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       const Text("CRASHED", style: TextStyle(color: Colors.red, fontSize: 60, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                       Text("FINAL SCORE: ${game.score}", style: const TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'Courier')),
                       const SizedBox(height: 30),
                       ElevatedButton(onPressed: () => setState(() => game.start()), child: const Text("RETRY")),
                       const SizedBox(height: 10),
                       TextButton(onPressed: () => setState(() { game.status = GameStatus.menu; }), child: const Text("MENU", style: TextStyle(color: Colors.white))),
                     ],
                   ),
                 ),
               )
          ],
        ),
      ),
    );
  }
}
