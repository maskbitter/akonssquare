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

// 2. OBSTACLE RUNNER
class ObstacleRunnerGame extends StatefulWidget {
  const ObstacleRunnerGame({super.key});
  @override
  State<ObstacleRunnerGame> createState() => _ObstacleRunnerGameState();
}
class _ObstacleRunnerGameState extends State<ObstacleRunnerGame> {
  double birdY = 0;
  double initialPos = 0;
  double height = 0;
  double time = 0;
  double gravity = -4.9;
  double velocity = 3.5;
  double birdWidth = 0.1;
  double birdHeight = 0.1;

  bool gameHasStarted = false;

  static List<double> barrierX = [2, 2 + 1.5];
  static double barrierWidth = 0.2;
  List<List<double>> barrierHeight = [
    [0.6, 0.4],
    [0.4, 0.6],
  ];

  int score = 0;
  int bestScore = 0;

  @override
  void initState() {
    super.initState();
    _loadBestScore();
  }

  Future<void> _loadBestScore() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      bestScore = p.getInt('runner_best') ?? 0;
    });
  }

  void startGame() {
    gameHasStarted = true;
    score = 0;
    Timer.periodic(const Duration(milliseconds: 10), (timer) {
      height = gravity * time * time + velocity * time;
      setState(() {
        birdY = initialPos - height;
      });

      if (_checkGameOver()) {
        timer.cancel();
        _endGame();
      }

      _moveBarriers();
      time += 0.01;
    });
  }

  void _moveBarriers() {
    setState(() {
      for (int i = 0; i < barrierX.length; i++) {
        barrierX[i] -= 0.01;
        if (barrierX[i] < -1.5) {
          barrierX[i] += 3;
          score++;
        }
      }
    });
  }

  void jump() {
    setState(() {
      time = 0;
      initialPos = birdY;
    });
  }

  bool _checkGameOver() {
    if (birdY < -1 || birdY > 1) return true;
    for (int i = 0; i < barrierX.length; i++) {
      if (barrierX[i] <= birdWidth && barrierX[i] + barrierWidth >= -birdWidth && (birdY <= -1 + barrierHeight[i][0] || birdY + birdHeight >= 1 - barrierHeight[i][1])) {
        return true;
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
    _showGameOverDialog();
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Game Over"),
        content: Text("Score: $score\nBest Score: $bestScore"),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); _resetGame(); }, child: const Text("Play Again")),
        ],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      birdY = 0;
      gameHasStarted = false;
      time = 0;
      initialPos = 0;
      barrierX = [2, 2 + 1.5];
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: gameHasStarted ? jump : startGame,
      child: Scaffold(
        backgroundColor: Colors.blue[100],
        body: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.blue[100],
                child: Center(
                  child: Stack(
                    children: [
                      // Player
                      Container(
                        alignment: Alignment(0, birdY),
                        child: Container(width: 30, height: 30, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                      ),
                      // Barriers
                      ...List.generate(barrierX.length, (i) {
                        return Stack(
                          children: [
                            Container(
                              alignment: Alignment(barrierX[i], 1.1),
                              child: Container(width: 50, height: 150 * barrierHeight[i][1], color: Colors.green),
                            ),
                            Container(
                              alignment: Alignment(barrierX[i], -1.1),
                              child: Container(width: 50, height: 150 * barrierHeight[i][0], color: Colors.green),
                            ),
                          ],
                        );
                      }),
                      Container(
                        alignment: const Alignment(0, -0.3),
                        child: Text(gameHasStarted ? "" : "TAP TO PLAY", style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(height: 15, color: Colors.green),
            Expanded(
              child: Container(
                color: Colors.brown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("SCORE", style: const TextStyle(color: Colors.white, fontSize: 20)), Text("$score", style: const TextStyle(color: Colors.white, fontSize: 35))]),
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("BEST", style: const TextStyle(color: Colors.white, fontSize: 20)), Text("$bestScore", style: const TextStyle(color: Colors.white, fontSize: 35))]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
