import 'package:flutter/material.dart';
import 'water_droplets_loader.dart';

/// A full-screen or overlay loading screen featuring:
/// - 3 realistic water droplets orbiting along a curved gravitational field
/// - Deep midnight navy blue gradient background
/// - Silky ocean water waves along the bottom
/// - "Checking Water Quality..." and "Clean Water • Healthier Tomorrow" typography
class DanumLoadingScreen extends StatelessWidget {
  final String statusText;
  final String subtitleText;
  final bool isOverlay;

  const DanumLoadingScreen({
    super.key,
    this.statusText = 'Checking Water Quality...',
    this.subtitleText = 'Clean Water  •  Healthier Tomorrow',
    this.isOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    // Deep midnight ocean navy gradient matching the reference design
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isOverlay
          ? [
              const Color(0xF2041333),
              const Color(0xF2071E4A),
              const Color(0xF4030D24),
            ]
          : [
              const Color(0xFF041333),
              const Color(0xFF071E4A),
              const Color(0xFF030D24),
            ],
      stops: const [0.0, 0.45, 1.0],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: Stack(
          children: [
            // Soft flowing water waves along the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 180,
              child: CustomPaint(
                painter: _BottomWaterWavesPainter(),
              ),
            ),

            // Center: Physics-driven 3-water-droplets loader & typography
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const WaterDropletsCircleLoader(
                    radius: 76,
                    dropletSize: 22,
                  ),
                  const SizedBox(height: 48),
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      shadows: [
                        Shadow(
                          color: Color(0x660284C7),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitleText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints subtle, silky ocean wave lines along the bottom of the screen,
/// exactly matching the reference design.
class _BottomWaterWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Wave 1: deep soft translucent fill at the very bottom
    final wave1 = Path();
    wave1.moveTo(0, height * 0.65);
    wave1.cubicTo(
      width * 0.28, height * 0.45,
      width * 0.62, height * 0.85,
      width, height * 0.58,
    );
    wave1.lineTo(width, height);
    wave1.lineTo(0, height);
    wave1.close();

    final fill1 = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave1, fill1);

    // Wave 1 contour line
    final line1 = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(wave1, line1);

    // Wave 2: foreground gentle crest
    final wave2 = Path();
    wave2.moveTo(0, height * 0.82);
    wave2.cubicTo(
      width * 0.35, height * 0.95,
      width * 0.70, height * 0.60,
      width, height * 0.78,
    );
    wave2.lineTo(width, height);
    wave2.lineTo(0, height);
    wave2.close();

    final fill2 = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave2, fill2);

    final line2 = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(wave2, line2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
