import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'package:akonssquare/Common/theme_manager.dart';

class GameZonePage extends StatefulWidget {
  const GameZonePage({super.key});

  @override
  State<GameZonePage> createState() => _GameZonePageState();
}

class _GameZonePageState extends State<GameZonePage> {
  final List<Map<String, dynamic>> _games = [
    {'name': 'Tic Tac Toe', 'icon': Icons.grid_3x3, 'route': (context) => const TicTacToeGame()},
    {'name': 'Obstacle Runner', 'icon': Icons.directions_run, 'route': (context) => const ObstacleRunnerGame()},
    {'name': 'Memory Match', 'icon': Icons.style, 'route': (context) => const MemoryMatchGame()},
    {'name': 'Tap Blitz', 'icon': Icons.touch_app, 'route': (context) => const TapBlitzGame()},
    {'name': 'Color Match', 'icon': Icons.palette, 'route': (context) => const ColorMatchGame()},
    {'name': 'Whack-a-Mole', 'icon': Icons.sports_mma, 'route': (context) => const WhackAMoleGame()},
  ];

  @override
  Widget build(BuildContext context) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return Scaffold(
      appBar: AppBar(
        title: const Text("GameZone"),
        centerTitle: true,
        elevation: isOutline ? 0 : 2,
        shape: isOutline ? Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)) : null,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
        ),
        itemCount: _games.length,
        itemBuilder: (context, index) {
          final game = _games[index];
          final color = ThemeManager.getCardColor(index);
          return Card(
            elevation: isOutline ? 0 : 4,
            color: isOutline ? Colors.transparent : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: isOutline ? BorderSide(color: color, width: 1.5) : BorderSide.none,
            ),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: game['route'])),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(game['icon'], size: 40, color: color),
                  const SizedBox(height: 12),
                  Text(game['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : color)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 1. TIC TAC TOE
class TicTacToeGame extends StatefulWidget {
  const TicTacToeGame({super.key});
  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}
class _TicTacToeGameState extends State<TicTacToeGame> {
  List<String> board = List.filled(9, ""); bool xTurn = true; String winner = "";
  void _reset() => setState(() { board = List.filled(9, ""); xTurn = true; winner = ""; });
  void _play(int i) {
    if (board[i] != "" || winner != "") return;
    setState(() { board[i] = xTurn ? "X" : "O"; xTurn = !xTurn; _checkWinner(); });
  }
  void _checkWinner() {
    List winPaths = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
    for (var p in winPaths) { if (board[p[0]] != "" && board[p[0]] == board[p[1]] && board[p[0]] == board[p[2]]) { winner = board[p[0]]; return; } }
    if (!board.contains("")) winner = "Draw";
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tic Tac Toe")),
      body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (winner != "") Text(winner == "Draw" ? "It's a Draw!" : "Winner: $winner", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        GridView.builder(shrinkWrap: true, padding: const EdgeInsets.all(40), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
          itemCount: 9, itemBuilder: (c, i) => GestureDetector(onTap: () => _play(i), child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.black)),
          child: Center(child: Text(board[i], style: TextStyle(fontSize: 40, color: board[i] == "X" ? Colors.blue : Colors.red)))))),
        ElevatedButton(onPressed: _reset, child: const Text("Reset"))
      ]),
    );
  }
}

// 2. OBSTACLE RUNNER (Ground Runner Version)
class ObstacleRunnerGame extends StatefulWidget {
  const ObstacleRunnerGame({super.key});
  @override
  State<ObstacleRunnerGame> createState() => _ObstacleRunnerGameState();
}

class _ObstacleRunnerGameState extends State<ObstacleRunnerGame> {
  double playerY = 0.8; // Alignment Y: 0.8 is near bottom
  double yVelocity = 0;
  double gravity = 0.003;
  double jumpStrength = -0.06;
  bool isJumping = false;
  bool gameHasStarted = false;

  static List<double> barrierX = [1.2, 2.2]; // Horizontal positions
  double barrierWidth = 0.15;
  double barrierHeight = 0.25; // Height relative to alignment space

  int score = 0;
  int bestScore = 0;
  Timer? gameTimer;

  @override
  void initState() {
    super.initState();
    _loadBestScore();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBestScore() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      bestScore = p.getInt('runner_best') ?? 0;
    });
  }

  void startGame() {
    setState(() {
      gameHasStarted = true;
      score = 0;
      playerY = 0.8;
      yVelocity = 0;
      barrierX = [1.2, 2.2];
    });

    gameTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      // Physics: Gravity & Jump
      setState(() {
        playerY += yVelocity;
        if (playerY < 0.8) {
          yVelocity += gravity;
        } else {
          playerY = 0.8;
          yVelocity = 0;
          isJumping = false;
        }
      });

      // Move Barriers
      _moveBarriers();

      // Check Game Over
      if (_checkGameOver()) {
        timer.cancel();
        _endGame();
      }
    });
  }

  void _moveBarriers() {
    setState(() {
      for (int i = 0; i < barrierX.length; i++) {
        barrierX[i] -= 0.025; // Speed
        if (barrierX[i] < -1.5) {
          barrierX[i] += 2.5; // Respawn on right
          score++;
        }
      }
    });
  }

  void jump() {
    if (!isJumping) {
      setState(() {
        isJumping = true;
        yVelocity = jumpStrength;
      });
    }
  }

  bool _checkGameOver() {
    for (int i = 0; i < barrierX.length; i++) {
      // Simple Bounding Box Collision
      // Player is at X=0, Y=playerY. Box size approx 0.1 wide, 0.1 high.
      // Barrier is at X=barrierX[i], Y=0.8. Box size approx 0.15 wide, 0.25 high.
      if (barrierX[i] > -0.15 && barrierX[i] < 0.1) {
        if (playerY > 0.55) { // Barrier top is around 0.8 - 0.25 = 0.55
          return true;
        }
      }
    }
    return false;
  }

  void _endGame() async {
    gameHasStarted = false;
    if (score > bestScore) {
      bestScore = score;
      final p = await SharedPreferences.getInstance();
      p.setInt('runner_best', bestScore);
    }
    if (mounted) _showGameOverDialog();
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(child: Text("GAME OVER", style: TextStyle(fontWeight: FontWeight.bold))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Your Score: $score", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text("Best Score: $bestScore", style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _resetGame(); }, 
              child: const Text("PLAY AGAIN")
            ),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      playerY = 0.8;
      gameHasStarted = false;
      yVelocity = 0;
      barrierX = [1.2, 2.2];
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: gameHasStarted ? jump : startGame,
      child: Scaffold(
        appBar: AppBar(title: const Text("Obstacle Runner"), centerTitle: true),
        body: Column(
          children: [
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade300, Colors.blue.shade50],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    // Clouds / Background decor
                    const Positioned(top: 50, left: 40, child: Icon(Icons.cloud, color: Colors.white, size: 60)),
                    const Positioned(top: 100, right: 60, child: Icon(Icons.cloud, color: Colors.white, size: 40)),

                    // Player (Running Man)
                    Container(
                      alignment: Alignment(0, playerY),
                      child: Icon(
                        isJumping ? Icons.accessibility_new : Icons.directions_run, 
                        size: 50, color: Colors.indigo.shade900
                      ),
                    ),

                    // Barriers (Obstacles on Ground)
                    ...List.generate(barrierX.length, (i) {
                      return Container(
                        alignment: Alignment(barrierX[i], 0.85),
                        child: Icon(Icons.warning, color: Colors.red.shade700, size: 35),
                      );
                    }),

                    // Ground
                    Container(
                      alignment: const Alignment(0, 0.95),
                      child: Container(height: 4, width: double.infinity, color: Colors.brown.shade400),
                    ),

                    // Start Message
                    if (!gameHasStarted)
                      Container(
                        alignment: const Alignment(0, -0.2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                          child: const Text("TAP TO JUMP OVER OBSTACLES", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold))
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Bottom Info Panel
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _scoreItem("SCORE", score),
                  _scoreItem("BEST", bestScore),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreItem(String label, int value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Text("$value", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.indigo.shade800)),
      ],
    );
  }
}

// 3. MEMORY MATCH
class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});
  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}
class _MemoryMatchGameState extends State<MemoryMatchGame> {
  List<IconData> icons = [Icons.favorite, Icons.star, Icons.sunny, Icons.face, Icons.pets, Icons.anchor, Icons.favorite, Icons.star, Icons.sunny, Icons.face, Icons.pets, Icons.anchor];
  List<bool> flipped = List.filled(12, false); List<int> selected = [];
  @override
  void initState() { super.initState(); icons.shuffle(); }
  void _onTap(int i) {
    if (flipped[i] || selected.length == 2) return;
    setState(() { flipped[i] = true; selected.add(i); });
    if (selected.length == 2) {
      if (icons[selected[0]] != icons[selected[1]]) {
        Future.delayed(const Duration(seconds: 1), () => setState(() { flipped[selected[0]] = false; flipped[selected[1]] = false; selected.clear(); }));
      } else { selected.clear(); }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Memory Match")),
      body: GridView.builder(padding: const EdgeInsets.all(20), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
        itemCount: 12, itemBuilder: (c, i) => GestureDetector(onTap: () => _onTap(i), child: Card(color: flipped[i] ? Colors.white : Colors.blue,
        child: flipped[i] ? Icon(icons[i], size: 30) : const SizedBox()))));
  }
}

// 4. TAP BLITZ
class TapBlitzGame extends StatefulWidget {
  const TapBlitzGame({super.key});
  @override
  State<TapBlitzGame> createState() => _TapBlitzGameState();
}
class _TapBlitzGameState extends State<TapBlitzGame> {
  int score = 0; int time = 10; Timer? timer;
  void _start() {
    score = 0; time = 10;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() { if (time > 0) { time--; } else { t.cancel(); _save(); } });
    });
  }
  void _save() async { final p = await SharedPreferences.getInstance(); if (score > (p.getInt('tap_best') ?? 0)) p.setInt('tap_best', score); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Tap Blitz")),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("Time: $time", style: const TextStyle(fontSize: 30)),
        Text("Score: $score", style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold)),
        const SizedBox(height: 50),
        GestureDetector(onTap: () { if (time > 0) setState(() => score++); },
          child: Container(width: 200, height: 200, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Center(child: Text("TAP!", style: TextStyle(color: Colors.white, fontSize: 30))))),
        const SizedBox(height: 30),
        ElevatedButton(onPressed: _start, child: const Text("Start"))
      ])));
  }
}

// 5. COLOR MATCH
class ColorMatchGame extends StatefulWidget {
  const ColorMatchGame({super.key});
  @override
  State<ColorMatchGame> createState() => _ColorMatchGameState();
}
class _ColorMatchGameState extends State<ColorMatchGame> {
  final List<String> names = ["RED", "BLUE", "GREEN", "YELLOW"];
  final List<Color> colors = [Colors.red, Colors.blue, Colors.green, Colors.yellow];
  int tIndex = 0; int cIndex = 0; int score = 0;
  void _next(int i) {
    if (i == cIndex) score++;
    setState(() { tIndex = Random().nextInt(4); cIndex = Random().nextInt(4); });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Color Match")),
      body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("Score: $score", style: const TextStyle(fontSize: 30)),
        const SizedBox(height: 20),
        Center(child: Text(names[tIndex], style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: colors[cIndex]))),
        const SizedBox(height: 50),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(4, (i) => ElevatedButton(onPressed: () => _next(i), style: ElevatedButton.styleFrom(backgroundColor: colors[i]), child: const Text(""))))
      ]));
  }
}

// 6. WHACK-A-MOLE
class WhackAMoleGame extends StatefulWidget {
  const WhackAMoleGame({super.key});
  @override
  State<WhackAMoleGame> createState() => _WhackAMoleGameState();
}
class _WhackAMoleGameState extends State<WhackAMoleGame> {
  int mole = -1; int score = 0; Timer? timer;
  void _start() {
    score = 0;
    timer = Timer.periodic(const Duration(milliseconds: 800), (t) {
      setState(() { mole = Random().nextInt(9); });
    });
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Whack-a-Mole")),
      body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("Score: $score", style: const TextStyle(fontSize: 30)),
        GridView.builder(shrinkWrap: true, padding: const EdgeInsets.all(40), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
          itemCount: 9, itemBuilder: (c, i) => GestureDetector(onTap: () { if (i == mole) setState(() => score++); },
          child: Container(decoration: BoxDecoration(color: i == mole ? Colors.brown : Colors.grey[300], shape: BoxShape.circle), margin: const EdgeInsets.all(10)))),
        ElevatedButton(onPressed: _start, child: const Text("Start"))
      ]));
  }
}
