import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => user != null ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF005C4B), Color(0xFF00A884), Color(0xFF25D366)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo ──
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _LogoPainter(),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // ── App name ──
              FadeTransition(
                opacity: _fade,
                child: const Column(
                  children: [
                    Text(
                      'نور شات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'تواصل بلا حدود',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer chat bubble
    final bubblePaint = Paint()
      ..color = const Color(0xFF00A884)
      ..style = PaintingStyle.fill;

    final bubblePath = Path();
    final r = size.width * 0.36;
    bubblePath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - 6), width: r * 2, height: r * 1.7),
      const Radius.circular(16),
    ));
    // Tail
    bubblePath.moveTo(cx - 6, cy + r * 0.75);
    bubblePath.lineTo(cx - 18, cy + r * 1.15);
    bubblePath.lineTo(cx + 8, cy + r * 0.75);
    bubblePath.close();
    canvas.drawPath(bubblePath, bubblePaint);

    // Signal waves (right side)
    final wavePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final waveX = cx + r * 0.15;
    final waveY = cy - 6;
    for (var i = 0; i < 3; i++) {
      final wr = 5.0 + i * 6.0;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(waveX, waveY), width: wr * 2, height: wr * 2),
        -0.9,
        1.8,
        false,
        wavePaint,
      );
    }

    // Mic icon (left side)
    final micPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final micX = cx - r * 0.28;
    final micY = cy - 6;
    // Mic body
    final micRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(micX, micY - 2), width: 8, height: 14),
      const Radius.circular(4),
    );
    canvas.drawRRect(micRect, micPaint);
    // Mic stand
    final standPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(micX, micY + 4), width: 14, height: 10),
      0,
      3.14159,
      false,
      standPaint,
    );
    canvas.drawLine(Offset(micX, micY + 9), Offset(micX, micY + 12), standPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
