import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mountainCtrl;
  late AnimationController _splitCtrl;
  late AnimationController _textCtrl;
  late AnimationController _fadeOutCtrl;

  late Animation<double> _mountainRise;
  late Animation<double> _snowAppear;
  late Animation<double> _splitLine;
  late Animation<double> _summitOpacity;
  late Animation<double> _splitOpacity;
  late Animation<double> _taglineOpacity;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    // Mountain rises up (0-800ms)
    _mountainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _mountainRise = CurvedAnimation(parent: _mountainCtrl, curve: Curves.easeOutBack);
    _snowAppear = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _mountainCtrl, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );

    // Split line draws down (400-1000ms)
    _splitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _splitLine = CurvedAnimation(parent: _splitCtrl, curve: Curves.easeInOut);

    // Text fades in (800-1400ms)
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _summitOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _splitOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)),
    );
    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );

    // Fade out everything (after pause)
    _fadeOutCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeOut = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeIn));

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _mountainCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _splitCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1200));
    await _fadeOutCtrl.forward();
    widget.onComplete();
  }

  @override
  void dispose() {
    _mountainCtrl.dispose();
    _splitCtrl.dispose();
    _textCtrl.dispose();
    _fadeOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_mountainCtrl, _splitCtrl, _textCtrl, _fadeOutCtrl]),
      builder: (context, _) {
        return Opacity(
          opacity: _fadeOut.value,
          child: Scaffold(
            backgroundColor: const Color(0xFF6366f1),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mountain logo
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CustomPaint(
                      painter: _MountainPainter(
                        mountainProgress: _mountainRise.value,
                        snowProgress: _snowAppear.value,
                        splitProgress: _splitLine.value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // "Summit" text
                  Opacity(
                    opacity: _summitOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - _summitOpacity.value)),
                      child: Text(
                        'Summit',
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  // "Split" text
                  Opacity(
                    opacity: _splitOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - _splitOpacity.value)),
                      child: Text(
                        'Split',
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFf59e0b),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tagline
                  Opacity(
                    opacity: _taglineOpacity.value,
                    child: Text(
                      'Split expenses, not friendships',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MountainPainter extends CustomPainter {
  final double mountainProgress;
  final double snowProgress;
  final double splitProgress;

  _MountainPainter({
    required this.mountainProgress,
    required this.snowProgress,
    required this.splitProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Slide up from bottom
    final yOffset = h * 0.4 * (1 - mountainProgress);
    canvas.save();
    canvas.translate(0, yOffset);

    // Scale in
    final scale = 0.5 + 0.5 * mountainProgress;
    canvas.translate(w / 2, h / 2);
    canvas.scale(scale);
    canvas.translate(-w / 2, -h / 2);

    // Back mountain (gray)
    final backPaint = Paint()..color = Color.lerp(Colors.transparent, const Color(0xFF94a3b8), mountainProgress)!;
    final backPath = Path()
      ..moveTo(w * 0.55, h * 0.85)
      ..lineTo(w * 0.75, h * 0.2)
      ..lineTo(w * 0.95, h * 0.85)
      ..close();
    canvas.drawPath(backPath, backPaint);

    // Front mountain (dark)
    final frontPaint = Paint()..color = Color.lerp(Colors.transparent, const Color(0xFF1e293b), mountainProgress)!;
    final frontPath = Path()
      ..moveTo(w * 0.1, h * 0.85)
      ..lineTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.78, h * 0.85)
      ..close();
    canvas.drawPath(frontPath, frontPaint);

    // Snow cap
    if (snowProgress > 0) {
      final snowPaint = Paint()..color = Color.lerp(Colors.transparent, const Color(0xFFF1F5F9), snowProgress)!;
      final snowPath = Path()
        ..moveTo(w * 0.5, h * 0.1)
        ..lineTo(w * 0.42, h * 0.25)
        ..lineTo(w * 0.58, h * 0.25)
        ..close();
      canvas.drawPath(snowPath, snowPaint);
    }

    // Split line (orange, draws from top to bottom)
    if (splitProgress > 0) {
      final linePaint = Paint()
        ..color = const Color(0xFFf97316)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      final startY = h * 0.3;
      final endY = h * 0.85;
      final currentEndY = startY + (endY - startY) * splitProgress;
      canvas.drawLine(Offset(w * 0.5, startY), Offset(w * 0.5, currentEndY), linePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MountainPainter oldDelegate) =>
      mountainProgress != oldDelegate.mountainProgress ||
      snowProgress != oldDelegate.snowProgress ||
      splitProgress != oldDelegate.splitProgress;
}
