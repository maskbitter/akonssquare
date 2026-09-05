import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'package:akons_square/Common/theme_manager.dart';

class GameZonePage extends StatefulWidget {
  const GameZonePage({super.key});

  @override
  State<GameZonePage> createState() => _GameZonePageState();
}

class _GameZonePageState extends State<GameZonePage> {
  final List<Map<String, dynamic>> _games = [
    {'name': 'Tic Tac Toe', 'icon': Icons.grid_3x3, 'route': (context) => const TicTacToeGame()},
    {'name': 'Memory Match', 'icon': Icons.style, 'route': (context) => const MemoryMatchGame()},
    {'name': 'Tap Blitz', 'icon': Icons.touch_app, 'route': (context) => const TapBlitzGame()},
    {'name': 'Color Match', 'icon': Icons.palette, 'route': (context) => const ColorMatchGame()},
    {'name': 'Whack-a-Mole', 'icon': Icons.sports_mma, 'route': (context) => const WhackAMoleGame()},
  ];

  @override
  Widget build(BuildContext context) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    final double cardWidth = (MediaQuery.of(context).size.width - 48) / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Game Zone"),
        centerTitle: true,
        elevation: isOutline ? 0 : 2,
        shape: isOutline ? Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)) : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: _games.asMap().entries.map((entry) {
              final index = entry.key;
              final game = entry.value;
              final color = ThemeManager.getCardColor(index);
              
              return SizedBox(
                width: cardWidth,
                height: cardWidth * 1.1,
                child: Card(
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
                        Text(
                          game['name'], 
                          style: TextStyle(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : color),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
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
  List<String> board = List.filled(9, "");
  bool xTurn = true;
  String winner = "";
  int winsX = 0;
  int winsO = 0;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  void _loadScores() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      winsX = p.getInt('ttt_wins_x') ?? 0;
      winsO = p.getInt('ttt_wins_o') ?? 0;
    });
  }

  void _saveScores() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('ttt_wins_x', winsX);
    await p.setInt('ttt_wins_o', winsO);
  }

  void _reset() => setState(() { board = List.filled(9, ""); xTurn = true; winner = ""; });

  void _play(int i) {
    if (board[i] != "" || winner != "") return;
    setState(() {
      board[i] = xTurn ? "X" : "O";
      xTurn = !xTurn;
      _checkWinner();
    });
  }

  void _checkWinner() {
    List winPaths = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
    for (var p in winPaths) {
      if (board[p[0]] != "" && board[p[0]] == board[p[1]] && board[p[0]] == board[p[2]]) {
        winner = board[p[0]];
        if (winner == "X") winsX++; else winsO++;
        _saveScores();
        return;
      }
    }
    if (!board.contains("")) winner = "Draw";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tic Tac Toe"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat("PLAYER X", "$winsX"),
                _stat("PLAYER O", "$winsO"),
              ],
            ),
            const SizedBox(height: 20),
            if (winner != "") 
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(winner == "Draw" ? "It's a Draw!" : "Winner: $winner", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo))
              ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: GridView.builder(
                shrinkWrap: true, 
                padding: const EdgeInsets.all(20), 
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                itemCount: 9, 
                itemBuilder: (c, i) => GestureDetector(
                  onTap: () => _play(i), 
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.indigo.shade100, width: 2)),
                    child: Center(child: Text(board[i], style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: board[i] == "X" ? Colors.blue : Colors.red)))
                  )
                )
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(onPressed: _reset, icon: const Icon(Icons.refresh), label: const Text("Reset Board"))
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String val) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]);
  }
}

// 2. MEMORY MATCH
class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});
  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  List<IconData> icons = [
    Icons.favorite, Icons.star, Icons.sunny, Icons.face, Icons.pets, Icons.anchor,
    Icons.favorite, Icons.star, Icons.sunny, Icons.face, Icons.pets, Icons.anchor
  ];
  List<bool> flipped = List.filled(12, false);
  List<int> selected = [];
  int moves = 0;
  int pairsFound = 0;
  Stopwatch stopwatch = Stopwatch();
  Timer? timer;
  String timeDisplay = "00:00";
  int bestTime = 0; // In seconds

  @override
  void initState() {
    super.initState();
    _resetGame();
    _loadBest();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _loadBest() async {
    final p = await SharedPreferences.getInstance();
    setState(() => bestTime = p.getInt('mem_best_time') ?? 0);
  }

  void _resetGame() {
    setState(() {
      icons.shuffle();
      flipped = List.filled(12, false);
      selected = [];
      moves = 0;
      pairsFound = 0;
      stopwatch.reset();
      timeDisplay = "00:00";
    });
    timer?.cancel();
  }

  void _startTimer() {
    stopwatch.start();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        final sec = stopwatch.elapsed.inSeconds;
        timeDisplay = "${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}";
      });
    });
  }

  void _onTap(int i) {
    if (flipped[i] || selected.length == 2) return;
    if (!stopwatch.isRunning) _startTimer();

    setState(() {
      flipped[i] = true;
      selected.add(i);
    });

    if (selected.length == 2) {
      moves++;
      if (icons[selected[0]] != icons[selected[1]]) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              flipped[selected[0]] = false;
              flipped[selected[1]] = false;
              selected.clear();
            });
          }
        });
      } else {
        pairsFound++;
        selected.clear();
        if (pairsFound == 6) {
          stopwatch.stop();
          timer?.cancel();
          _showWinDialog();
        }
      }
    }
  }

  void _showWinDialog() async {
    final currentSec = stopwatch.elapsed.inSeconds;
    final p = await SharedPreferences.getInstance();
    if (bestTime == 0 || currentSec < bestTime) {
      bestTime = currentSec;
      await p.setInt('mem_best_time', bestTime);
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(child: Text("Victory!", style: TextStyle(fontWeight: FontWeight.bold))),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.95,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Time: $timeDisplay", style: const TextStyle(fontSize: 18)),
              Text("Moves: $moves", style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text("Best Time: ${bestTime ~/ 60}:${(bestTime % 60).toString().padLeft(2, '0')}", style: const TextStyle(color: Colors.grey)),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Memory Match"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat("TIME", timeDisplay),
                  _stat("MOVES", "$moves"),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: 12,
                itemBuilder: (c, i) => GestureDetector(
                  onTap: () => _onTap(i),
                  child: Card(
                    elevation: 4,
                    color: flipped[i] ? Colors.white : Colors.indigo[400],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Center(child: flipped[i] ? Icon(icons[i], size: 40, color: Colors.indigo[900]) : const Icon(Icons.help_outline, color: Colors.white)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _resetGame, icon: const Icon(Icons.refresh), label: const Text("Reset")),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String val) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]);
  }
}

// 3. TAP BLITZ
class TapBlitzGame extends StatefulWidget {
  const TapBlitzGame({super.key});
  @override
  State<TapBlitzGame> createState() => _TapBlitzGameState();
}
class _TapBlitzGameState extends State<TapBlitzGame> {
  int score = 0;
  int time = 10;
  int bestScore = 0;
  Timer? timer;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  void _loadBest() async {
    final p = await SharedPreferences.getInstance();
    setState(() => bestScore = p.getInt('tap_best') ?? 0);
  }

  void _start() {
    setState(() {
      score = 0;
      time = 10;
      isPlaying = true;
    });
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (time > 0) {
          time--;
        } else {
          t.cancel();
          isPlaying = false;
          _save();
        }
      });
    });
  }

  void _save() async {
    final p = await SharedPreferences.getInstance();
    if (score > bestScore) {
      bestScore = score;
      await p.setInt('tap_best', bestScore);
    }
    _showResult();
  }

  void _showResult() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Game Over"),
        content: Text("You tapped $score times!\nBest: $bestScore"),
        actions: [TextButton(onPressed: () { Navigator.pop(ctx); _start(); }, child: const Text("Play Again"))],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tap Blitz"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat("TIME", "$time"),
                _stat("SCORE", "$score"),
                _stat("BEST", "$bestScore"),
              ],
            ),
            const SizedBox(height: 50),
            GestureDetector(
              onTap: () { if (isPlaying && time > 0) setState(() => score++); },
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  color: isPlaying ? Colors.blue : Colors.grey, 
                  shape: BoxShape.circle,
                  boxShadow: isPlaying ? [const BoxShadow(color: Colors.blue, blurRadius: 20)] : null,
                ),
                child: Center(child: Text(isPlaying ? "TAP!" : "READY?", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)))
              ),
            ),
            const SizedBox(height: 40),
            if (!isPlaying) ElevatedButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow), label: const Text("Start Game", style: TextStyle(fontSize: 20)))
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String val) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]);
  }
}

// 4. COLOR MATCH
class ColorMatchGame extends StatefulWidget {
  const ColorMatchGame({super.key});
  @override
  State<ColorMatchGame> createState() => _ColorMatchGameState();
}

class _ColorMatchGameState extends State<ColorMatchGame> {
  final List<String> names = ["RED", "BLUE", "GREEN", "YELLOW"];
  final List<Color> colors = [Colors.red, Colors.blue, Colors.green, Colors.yellow];
  int tIndex = 0;
  int cIndex = 0;
  int score = 0;
  int bestScore = 0;
  int timeLeft = 30;
  Timer? timer;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _loadBest() async {
    final p = await SharedPreferences.getInstance();
    setState(() => bestScore = p.getInt('color_best') ?? 0);
  }

  void _startGame() {
    setState(() {
      score = 0;
      timeLeft = 30;
      isPlaying = true;
      _next();
    });
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (timeLeft > 0) {
          timeLeft--;
        } else {
          t.cancel();
          isPlaying = false;
          _endGame();
        }
      });
    });
  }

  void _next() {
    setState(() {
      tIndex = Random().nextInt(4);
      cIndex = Random().nextInt(4);
    });
  }

  void _check(int i) {
    if (!isPlaying) return;
    if (i == cIndex) {
      score++;
    } else {
      score = score > 0 ? score - 1 : 0;
    }
    _next();
  }

  void _endGame() async {
    final p = await SharedPreferences.getInstance();
    if (score > bestScore) {
      bestScore = score;
      await p.setInt('color_best', bestScore);
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(child: Text("Time's Up!", style: TextStyle(fontWeight: FontWeight.bold))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Score: $score", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Best Score: $bestScore", style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(onPressed: () { Navigator.pop(ctx); _startGame(); }, child: const Text("PLAY AGAIN")),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Color Match"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat("TIME", "$timeLeft"),
                _stat("SCORE", "$score"),
                _stat("BEST", "$bestScore"),
              ],
            ),
            const SizedBox(height: 40),
            if (!isPlaying) 
              ElevatedButton.icon(onPressed: _startGame, icon: const Icon(Icons.play_arrow), label: const Text("Start Game", style: TextStyle(fontSize: 20)))
            else ...[
              Text(names[tIndex], style: TextStyle(fontSize: 70, fontWeight: FontWeight.w900, color: colors[cIndex], letterSpacing: 2)),
              const SizedBox(height: 60),
              const Text("Tap the color of the text!", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: List.generate(4, (i) => InkWell(
                  onTap: () => _check(i),
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: colors[i], borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: colors[i].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
                  ),
                )),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String val) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]);
  }
}

// 5. WHACK-A-MOLE
class WhackAMoleGame extends StatefulWidget {
  const WhackAMoleGame({super.key});
  @override
  State<WhackAMoleGame> createState() => _WhackAMoleGameState();
}

class _WhackAMoleGameState extends State<WhackAMoleGame> {
  int mole = -1;
  int score = 0;
  int bestScore = 0;
  Timer? timer;
  int timeLeft = 20;

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  void _loadBest() async {
    final p = await SharedPreferences.getInstance();
    setState(() => bestScore = p.getInt('mole_best') ?? 0);
  }

  void _start() {
    score = 0;
    timeLeft = 20;
    _nextMole();
    timer?.cancel();
    timer = Timer.periodic(const Duration(milliseconds: 800), (t) {
      setState(() {
        if (timeLeft > 0) {
          timeLeft--;
          _nextMole();
        } else {
          t.cancel();
          mole = -1;
          _save();
        }
      });
    });
  }

  void _nextMole() {
    setState(() => mole = Random().nextInt(9));
  }

  void _save() async {
    final p = await SharedPreferences.getInstance();
    if (score > bestScore) {
      bestScore = score;
      await p.setInt('mole_best', bestScore);
    }
    _showResult();
  }

  void _showResult() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Game Over"),
        content: Text("Score: $score\nBest: $bestScore"),
        actions: [TextButton(onPressed: () { Navigator.pop(ctx); _start(); }, child: const Text("Play Again"))],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Whack-a-Mole"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat("TIME", "$timeLeft"),
                _stat("SCORE", "$score"),
                _stat("BEST", "$bestScore"),
              ],
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(40),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 15, mainAxisSpacing: 15),
                itemCount: 9,
                itemBuilder: (c, i) => GestureDetector(
                  onTap: () { if (i == mole && timeLeft > 0) setState(() { score++; mole = -1; }); },
                  child: Container(
                    decoration: BoxDecoration(
                      color: i == mole ? Colors.brown : Colors.grey[300], 
                      shape: BoxShape.circle,
                      boxShadow: i == mole ? [const BoxShadow(color: Colors.brown, blurRadius: 10)] : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _start, child: const Text("Start Game")),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String val) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]);
  }
}
