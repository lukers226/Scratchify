import 'package:flutter/material.dart';
import 'package:flutter_scratch_card/flutter_scratch_card.dart';

void main() => runApp(const ScratchApp());

class ScratchApp extends StatelessWidget {
  const ScratchApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Scratchify',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
      ),
      home: const ScratchDemo(),
    );
  }
}

class ScratchDemo extends StatefulWidget {
  const ScratchDemo({Key? key}) : super(key: key);

  @override
  State<ScratchDemo> createState() => _ScratchDemoState();
}

class _ScratchDemoState extends State<ScratchDemo> {
  final ScratchController _controller = ScratchController();

  @override
  Widget build(BuildContext context) {
    const double cardSize = 300.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Scratchify',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 4,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Scratch to see your reward!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ScratchCard(
                  controller: _controller,
                  // ── Scratch overlay: silver metallic image texture ──────────────
                  overlayImageAsset: 'assets/scratch_texture.png',
                  animationType: ScratchAnimationType.lottie,
                  animationAsset: 'assets/Confetti.json',
                  revealDuration: const Duration(seconds: 2),
                  width: cardSize,
                  height: cardSize,
                  brushSize: 50,
                  threshold: 0.6,
                  enableHaptics: true,
                  progressTriggers: const [0.25],
                  autoReveal: true,
                  onProgressTrigger: (value) {
                    debugPrint('Trigger: ${(value * 100).toStringAsFixed(0)}%');
                  },
                  onThreshold: () {
                    debugPrint('🎉 Revealed!');
                  },
                  child: Container(
                    width: cardSize,
                    height: cardSize,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/reveal.jpg',
                        width: cardSize,
                        height: cardSize,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _controller.reset(),
              icon: const Icon(Icons.refresh),
              label: const Text("Reset Card"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}