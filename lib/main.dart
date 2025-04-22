import 'dart:async' show Timer;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

void main() {
  runApp(const HedgehogThornGame());
}

class HedgehogThornGame extends StatelessWidget {
  const HedgehogThornGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hedgehog Thorn',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.green[100],
      ),
      home: const GameHomePage(),
    );
  }
}

class HowToPlayPage extends StatelessWidget {
  const HowToPlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How to Play')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hedgehog Thorn Game Guide',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildInstructionStep(
              '1. Game Objective',
              'Shoot arrows at flying birds and objects to earn points and tokens.',
            ),
            _buildInstructionStep(
              '2. Starting the Game',
              'Tap "Start Game" to begin. You begin with 5 arrows.',
            ),
            _buildInstructionStep(
              '3. Shooting Mechanics',
              'Drag and release to shoot an arrow. The longer you drag, the more powerful the shot!',
            ),
            _buildInstructionStep(
              '4. Scoring System',
              'Different targets have different point values. Faster targets are worth more!',
            ),
            _buildInstructionStep(
              '5. Levels & Difficulty',
              'Each level introduces faster and more challenging targets.',
            ),
            _buildInstructionStep(
              '6. Token Rewards',
              'Connect your wallet and claim tokens after each round.',
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Game'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(description, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class GameHomePage extends StatefulWidget {
  const GameHomePage({super.key});

  @override
  State<GameHomePage> createState() => _GameHomePageState();
}

class _GameHomePageState extends State<GameHomePage> {
  bool _showTutorial = true;

  void _startGame() {
    setState(() {
      _showTutorial = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hedgehog Thorn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HowToPlayPage(),
                  ),
                ),
          ),
        ],
      ),
      body: _showTutorial ? _buildStartScreen() : const GameScreen(),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Welcome to Hedgehog Thorn!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _startGame,
            child: const Text('Start Game'),
          ),
        ],
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
  int _score = 0;
  int _tokensEarned = 0;
  int _highScore = 0;
  int _ammo = 5;
  bool _gameActive = false;
  bool _walletConnected = false;
  bool _showTutorial = true;
  bool _isDragging = false;
  late ConfettiController _confettiController;
  Offset _dragStart = Offset.zero;
  Offset _dragEnd = Offset.zero;
  final List<Arrow> _arrows = [];
  final List<FlyingTarget> _targets = [];
  Timer? _targetSpawnTimer;
  Timer? _gameTimer;

  final Random _random = Random();
  int _round = 1;
  int _multiplier = 1;
  int _timeRemaining = 60;
  double _hedgehogAngle = 0;

  final List<TargetType> _targetTypes = [
    TargetType(
      name: 'Small Ice',
      icon: Icons.ac_unit,
      color: const Color.fromARGB(255, 231, 134, 7),
      speed: 1.5,
      value: 50,
      size: 0.8,
      spawnChance: 0.3,
    ),
    TargetType(
      name: 'Medium Ice',
      icon: Icons.ac_unit,
      color: const Color.fromARGB(255, 247, 160, 79),
      speed: 1.2,
      value: 75,
      size: 1.0,
      spawnChance: 0.25,
    ),
    TargetType(
      name: 'Large Ice',
      icon: Icons.ac_unit,
      color: const Color.fromARGB(255, 250, 14, 14),
      speed: 0.8,
      value: 100,
      size: 1.2,
      spawnChance: 0.2,
    ),
    TargetType(
      name: 'Bird',
      icon: Icons.air,
      color: Colors.brown,
      speed: 2.0,
      value: 60,
      size: 0.9,
      spawnChance: 0.15,
    ),
    TargetType(
      name: 'Butterfly',
      icon: Icons.air,
      color: Colors.purple,
      speed: 2.5,
      value: 80,
      size: 0.7,
      spawnChance: 0.1,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _targetSpawnTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _connectWallet() {
    setState(() {
      _walletConnected = true;
      _tokensEarned = 0;
    });
  }

  Future<void> _claimTokens() async {
    if (!_walletConnected) return;

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _tokensEarned += _score;
      if (_score > _highScore) {
        _highScore = _score;
        _confettiController.play();
      }
      _score = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tokens claimed successfully!')),
    );
  }

  void _startGame() {
    setState(() {
      _gameActive = true;
      _score = 0;
      _ammo = 5;
      _round = 1;
      _multiplier = 1;
      _timeRemaining = 60;
      _arrows.clear();
      _targets.clear();
      _startTargetSpawner();
      _startGameTimer();
      _showTutorial = false;
    });
  }

  void _startTargetSpawner() {
    const baseInterval = 2000; // ms
    final levelFactor = 1 - (_round * 0.1);
    final interval = (baseInterval * levelFactor).clamp(500, 2000).toInt();

    _targetSpawnTimer?.cancel();
    _targetSpawnTimer = Timer.periodic(Duration(milliseconds: interval), (
      timer,
    ) {
      if (!_gameActive) {
        timer.cancel();
        return;
      }
      _spawnTarget();
    });
  }

  void _spawnTarget() {
    if (!_gameActive) return; // Add this safety check

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double randomValue = _random.nextDouble();
    double cumulativeChance = 0;
    TargetType selectedType = _targetTypes.first;

    for (var type in _targetTypes) {
      cumulativeChance += type.spawnChance;
      if (randomValue <= cumulativeChance) {
        selectedType = type;
        break;
      }
    }

    setState(() {
      _targets.add(
        FlyingTarget(
          position: Offset(
            _random.nextDouble() * screenWidth,
            screenHeight + 50,
          ),
          type: selectedType,
          direction: _random.nextDouble() > 0.5 ? 1 : -1,
        ),
      );
    });

    setState(() {
      _targets.add(
        FlyingTarget(
          position: Offset(
            _random.nextDouble() * screenWidth,
            screenHeight + 50,
          ),
          type: selectedType,
          direction: _random.nextDouble() > 0.5 ? 1 : -1,
        ),
      );
    });
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_gameActive) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeRemaining--;
        if (_timeRemaining <= 0) {
          _endGame();
        }
      });
    });
  }

  void _updateGame() {
    if (!_gameActive) return;

    final currentTime = DateTime.now().millisecondsSinceEpoch;

    if (currentTime - _lastUpdateTime < 16) return;
    _lastUpdateTime = currentTime;

    for (var arrow in _arrows) {
      arrow.update();
    }
    _arrows.removeWhere(
      (arrow) => arrow.isOffScreen(MediaQuery.of(context).size),
    );

    // Update targets
    for (var target in _targets) {
      target.update();
    }
    _targets.removeWhere(
      (target) => target.isOffScreen(MediaQuery.of(context).size),
    );

    // Check for collisions
    _checkCollisions();

    setState(() {});
  }

  void _checkCollisions() {
    final arrowsToRemove = <Arrow>[];
    final targetsToRemove = <FlyingTarget>[];

    for (final arrow in _arrows) {
      for (final target in _targets) {
        final distance = (arrow.position - target.position).distance;
        final collisionDistance = 30 * target.type.size;
        if (distance < collisionDistance) {
          arrowsToRemove.add(arrow);
          targetsToRemove.add(target);
          _score += (target.type.value * _multiplier).round();
          _multiplier++;
          break;
        }
      }
    }

    setState(() {
      _arrows.removeWhere(arrowsToRemove.contains);
      _targets.removeWhere(targetsToRemove.contains);
      if (targetsToRemove.isNotEmpty && _multiplier > 1) {
        _multiplier = 1;
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (!_gameActive || _ammo <= 0) return;
    setState(() {
      _isDragging = true;
      _dragStart = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragEnd = details.localPosition;
      _hedgehogAngle = atan2(
        _dragEnd.dy - _dragStart.dy,
        _dragEnd.dx - _dragStart.dx,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final power = (_dragEnd - _dragStart).distance.clamp(0, 200);
    if (power < 20) {
      setState(() {
        _isDragging = false;
      });
      return;
    }

    final direction = _dragEnd - _dragStart;
    final distance = direction.distance;
    final normalized =
        distance > 0
            ? Offset(direction.dx / distance, direction.dy / distance)
            : Offset.zero;

    setState(() {
      _isDragging = false;
      _ammo--;
      _arrows.add(
        Arrow(
          position: _dragStart,
          velocity: Offset(
            normalized.dx * power * 0.1,
            normalized.dy * power * 0.1,
          ),
        ),
      );
    });

    if (_ammo <= 0) {
      _endGame();
    }
  }

  void _endGame() {
    setState(() {
      _gameActive = false;
      _targetSpawnTimer?.cancel();
      _gameTimer?.cancel();
    });
  }

  void _buyMoreAmmo() {
    if (_tokensEarned < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need at least 50 tokens to buy more ammo!'),
        ),
      );
      return;
    }

    setState(() {
      _tokensEarned -= 50;
      _ammo += 5;
    });
  }

  void _startNextRound() {
    setState(() {
      _round++;
      _ammo = 5 + _round;
      _timeRemaining = 60 + (_round * 10);
      _gameActive = true;
      _arrows.clear();
      _targets.clear();
      _startTargetSpawner();
      _startGameTimer();
    });
  }

  void _showHowToPlay() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HowToPlayPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateGame());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hedgehog Thorn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHowToPlay,
            tooltip: 'How to Play',
          ),
          IconButton(
            icon: Icon(
              _walletConnected ? Icons.account_balance_wallet : Icons.wallet,
            ),
            onPressed: _walletConnected ? null : _connectWallet,
            tooltip: _walletConnected ? 'Wallet connected' : 'Connect wallet',
          ),
        ],
      ),
      body: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Stack(
          children: [
            // Sky background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF87CEEB), Color(0xFFE0F7FA)],
                ),
              ),
            ),

            // Clouds
            for (int i = 0; i < 5; i++)
              Positioned(
                left: MediaQuery.of(context).size.width * 0.2 * i,
                top: 100 + 50 * (i % 3),
                child: const Icon(Icons.cloud, color: Colors.white, size: 60),
              ),

            // Targets
            for (final target in _targets)
              Positioned(
                left: target.position.dx - 25,
                top: target.position.dy - 25,
                child: Transform.rotate(
                  angle: target.angle,
                  child: Icon(
                    target.type.icon,
                    color: target.type.color,
                    size: 50 * target.type.size,
                  ),
                ),
              ),

            // Arrows
            for (final arrow in _arrows)
              Positioned(
                left: arrow.position.dx - 15,
                top: arrow.position.dy - 15,
                child: Transform.rotate(
                  angle: atan2(arrow.velocity.dy, arrow.velocity.dx),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.brown,
                    size: 30,
                  ),
                ),
              ),

            // Ground
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green[800],
                  border: Border.all(color: Colors.brown, width: 2),
                ),
              ),
            ),

            // Hedgehog
            Positioned(
              left: 50,
              bottom: 100,
              child: Transform.rotate(
                angle: _hedgehogAngle,
                child: Icon(Icons.pets, size: 60, color: Colors.brown[700]),
              ),
            ),

            // Game UI
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (_showTutorial) ...[
                    const Text(
                      'Welcome to Hedgehog Thorn!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Shoot arrows at flying targets to earn tokens!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _startGame,
                      child: const Text('Start Game'),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _showHowToPlay,
                      child: const Text('How to Play'),
                    ),
                  ] else ...[
                    if (_walletConnected) ...[
                      Text(
                        'Tokens: $_tokensEarned',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      'Level: $_round',
                      style: const TextStyle(fontSize: 20),
                    ),
                    Text(
                      'Score: $_score',
                      style: const TextStyle(fontSize: 24),
                    ),
                    Text(
                      'High Score: $_highScore',
                      style: const TextStyle(fontSize: 20),
                    ),
                    Text('Ammo: $_ammo', style: const TextStyle(fontSize: 20)),
                    Text(
                      'Time: $_timeRemaining',
                      style: const TextStyle(fontSize: 20),
                    ),
                    Text(
                      'Multiplier: x$_multiplier',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 20),
                    if (!_gameActive && _score > 0)
                      ElevatedButton(
                        onPressed: _claimTokens,
                        child: const Text('Claim Tokens'),
                      ),
                    if (!_gameActive && _round > 1)
                      ElevatedButton(
                        onPressed: _startNextRound,
                        child: const Text('Next Level'),
                      ),
                    if (!_gameActive && _round == 1)
                      ElevatedButton(
                        onPressed: _startGame,
                        child: const Text('Start Game'),
                      ),
                    if (_gameActive) ...[
                      const Text(
                        'Drag to aim and release to shoot!',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ],
              ),
            ),

            // Drag line
            if (_isDragging)
              CustomPaint(painter: DragLinePainter(_dragStart, _dragEnd)),

            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          _walletConnected && !_gameActive
              ? FloatingActionButton(
                onPressed: _buyMoreAmmo,
                tooltip: 'Buy more ammo (50 tokens)',
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add),
                    Text('Ammo', style: TextStyle(fontSize: 10)),
                  ],
                ),
              )
              : null,
    );
  }
}

class DragLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;

  DragLinePainter(this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red.withOpacity(0.7)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Arrow {
  Offset position;
  Offset velocity;

  Arrow({required this.position, required this.velocity});

  void update() {
    position += velocity;
    velocity *= 0.98; // Air resistance
  }

  bool isOffScreen(Size screenSize) {
    return position.dx < 0 ||
        position.dy < 0 ||
        position.dx > screenSize.width ||
        position.dy > screenSize.height;
  }
}

class FlyingTarget {
  Offset position;
  final TargetType type;
  final int direction;
  double angle = 0;

  FlyingTarget({
    required this.position,
    required this.type,
    required this.direction,
  });

  void update() {
    position += Offset(direction * type.speed, -type.speed * 0.5);
    angle += direction * 0.05;
  }

  bool isOffScreen(Size screenSize) {
    return position.dy < -100 ||
        (direction > 0 && position.dx > screenSize.width + 100) ||
        (direction < 0 && position.dx < -100);
  }
}

class TargetType {
  final String name;
  final IconData icon;
  final Color color;
  final double speed;
  final int value;
  final double size;
  final double spawnChance;

  const TargetType({
    required this.name,
    required this.icon,
    required this.color,
    required this.speed,
    required this.value,
    required this.size,
    required this.spawnChance,
  });
}
