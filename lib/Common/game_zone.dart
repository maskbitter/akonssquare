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
    {'name': 'Slide Puzzle', 'icon': Icons.extension, 'route': (context) => const SlidePuzzleGame()},
    {'name': 'Memory Match', 'icon': Icons.style, 'route': (context) => const MemoryMatchGame()},
    {'name': 'Snake', 'icon': Icons.gesture, 'route': (context) => const SnakeGame()},
    {'name': 'Tap Blitz', 'icon': Icons.touch_app, 'route': (context) => const TapBlitzGame()},
    {'name': '2048 Lite', 'icon': Icons.looks_two, 'route': (context) => const Game2048()},
    {'name': 'Color Match', 'icon': Icons.palette, 'route': (context) => const ColorMatchGame()},
    {'name': 'Higher Lower', 'icon': Icons.swap_vert, 'route': (context) => const HigherLowerGame()},
    {'name': 'R-P-S', 'icon': Icons.front_hand, 'route': (context) => const RockPaperScissorsGame()},
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

// 2. SLIDE PUZZLE
class SlidePuzzleGame extends StatefulWidget {
  const SlidePuzzleGame({super.key});
  @override
  State<SlidePuzzleGame> createState() => _SlidePuzzleGameState();
}
class _SlidePuzzleGameState extends State<SlidePuzzleGame> {
  List<int> numbers = [1, 2, 3, 4, 5, 6, 7, 8, 0];
  @override
  void initState() { super.initState(); numbers.shuffle(); }
  void _move(int i) {
    int empty = numbers.indexOf(0);
    if ((i - empty).abs() == 1 || (i - empty).abs() == 3) setState(() { numbers[empty] = numbers[i]; numbers[i] = 0; });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Slide Puzzle")),
      body: Center(child: GridView.builder(shrinkWrap: true, padding: const EdgeInsets.all(20), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
        itemCount: 9, itemBuilder: (c, i) => GestureDetector(onTap: () => _move(i), child: Card(color: numbers[i] == 0 ? Colors.grey : Colors.blue,
        child: Center(child: Text(numbers[i] == 0 ? "" : "${numbers[i]}", style: const TextStyle(fontSize: 24, color: Colors.white))))))));
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

// 4. SNAKE
class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});
  @override
  State<SnakeGame> createState() => _SnakeGameState();
}
class _SnakeGameState extends State<SnakeGame> {
  List<int> snake = [45, 65, 85]; int food = 100; String dir = "down"; Timer? timer;
  void _start() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(milliseconds: 300), (t) {
      setState(() {
        int next = snake.last + (dir == "down" ? 20 : dir == "up" ? -20 : dir == "left" ? -1 : 1);
        if (snake.contains(next) || next < 0 || next >= 400) { t.cancel(); return; }
        snake.add(next); if (next == food) { food = Random().nextInt(400); } else { snake.removeAt(0); }
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Snake")),
      body: Column(children: [
        Expanded(child: GridView.builder(itemCount: 400, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 20),
          itemBuilder: (c, i) => Container(color: snake.contains(i) ? Colors.green : (i == food ? Colors.red : Colors.black12), margin: const EdgeInsets.all(1)))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(onPressed: () => dir = "left", icon: const Icon(Icons.arrow_back)),
          IconButton(onPressed: () => dir = "up", icon: const Icon(Icons.arrow_upward)),
          IconButton(onPressed: () => dir = "down", icon: const Icon(Icons.arrow_downward)),
          IconButton(onPressed: () => dir = "right", icon: const Icon(Icons.arrow_forward)),
          ElevatedButton(onPressed: _start, child: const Text("Start"))
        ])
      ]));
  }
}

// 5. TAP BLITZ
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

// 6. 2048 LITE (3x3)
class Game2048 extends StatefulWidget {
  const Game2048({super.key});
  @override
  State<Game2048> createState() => _Game2048State();
}
class _Game2048State extends State<Game2048> {
  List<int> grid = List.filled(9, 0);
  void _add() { var empty = []; for (var i=0; i<9; i++) if (grid[i] == 0) empty.add(i); if (empty.isNotEmpty) grid[empty[Random().nextInt(empty.length)]] = 2; }
  void _move() { setState(() { _add(); }); } // Simplified for demo
  @override
  void initState() { super.initState(); _add(); _add(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("2048 Lite")),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        GridView.builder(shrinkWrap: true, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
          itemCount: 9, itemBuilder: (c, i) => Card(color: grid[i] == 0 ? Colors.grey[300] : Colors.orange, child: Center(child: Text(grid[i] == 0 ? "" : "${grid[i]}")))),
        ElevatedButton(onPressed: _move, child: const Text("Random Move"))
      ])));
  }
}

// 7. COLOR MATCH
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

// 8. HIGHER LOWER
class HigherLowerGame extends StatefulWidget {
  const HigherLowerGame({super.key});
  @override
  State<HigherLowerGame> createState() => _HigherLowerGameState();
}
class _HigherLowerGameState extends State<HigherLowerGame> {
  int current = 50; int next = 0; int score = 0;
  void _check(bool higher) {
    next = Random().nextInt(100);
    if ((higher && next >= current) || (!higher && next <= current)) { score++; } else { score = 0; }
    setState(() { current = next; });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Higher Lower")),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("Score: $score", style: const TextStyle(fontSize: 30)),
        Text("$current", style: const TextStyle(fontSize: 100, fontWeight: FontWeight.bold)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(onPressed: () => _check(true), child: const Text("Higher")),
          const SizedBox(width: 20),
          ElevatedButton(onPressed: () => _check(false), child: const Text("Lower")),
        ])
      ])));
  }
}

// 9. ROCK PAPER SCISSORS
class RockPaperScissorsGame extends StatefulWidget {
  const RockPaperScissorsGame({super.key});
  @override
  State<RockPaperScissorsGame> createState() => _RockPaperScissorsGameState();
}
class _RockPaperScissorsGameState extends State<RockPaperScissorsGame> {
  String msg = "Choose!"; List opts = ["Rock", "Paper", "Scissors"];
  void _play(int i) {
    int bot = Random().nextInt(3);
    if (i == bot) msg = "Draw!";
    else if ((i == 0 && bot == 2) || (i == 1 && bot == 0) || (i == 2 && bot == 1)) msg = "You Win! Bot: ${opts[bot]}";
    else msg = "You Lose! Bot: ${opts[bot]}";
    setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Rock Paper Scissors")),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(msg, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 40),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          ElevatedButton(onPressed: () => _play(0), child: const Text("Rock")),
          ElevatedButton(onPressed: () => _play(1), child: const Text("Paper")),
          ElevatedButton(onPressed: () => _play(2), child: const Text("Scissors")),
        ])
      ])));
  }
}

// 10. WHACK-A-MOLE
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
