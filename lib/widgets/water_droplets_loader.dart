import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An animated loader featuring 3 water droplets moving along a circular path.
/// In each cycle, the trailing droplet rushes fast around the circle and stops
/// neatly behind the preceding droplet, followed by the next droplet in sequence.
class WaterDropletsCircleLoader extends StatefulWidget {
  final double radius;
  final double dropletSize;
  final Widget? centerWidget;
  final Color primaryColor;
  final Color secondaryColor;

  const WaterDropletsCircleLoader({
    super.key,
    this.radius = 58.0,
    this.dropletSize = 18.0,
    this.centerWidget,
    this.primaryColor = const Color(0xFF38BDF8),
    this.secondaryColor = const Color(0xFF0284C7),
  });

  @override
  State<WaterDropletsCircleLoader> createState() => _WaterDropletsCircleLoaderState();
}

class _WaterDropletsCircleLoaderState extends State<WaterDropletsCircleLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 2100ms total for 3 droplets = 700ms per droplet dash
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSize = (widget.radius + widget.dropletSize + 16) * 2;

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.centerWidget != null) widget.centerWidget!,
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                size: Size(totalSize, totalSize),
                painter: _WaterDropletsPainter(
                  progress: _controller.value,
                  radius: widget.radius,
                  dropletSize: widget.dropletSize,
                  primaryColor: widget.primaryColor,
                  secondaryColor: widget.secondaryColor,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WaterDropletsPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final double radius;
  final double dropletSize;
  final Color primaryColor;
  final Color secondaryColor;

  _WaterDropletsPainter({
    required this.progress,
    required this.radius,
    required this.dropletSize,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Subtle water track ring
    final trackPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, trackPaint);

    // 3 droplets moving in sequence
    // Total animation cycle is split into 3 phases: [0..1/3), [1/3..2/3), [2/3..1]
    final phaseProgress = progress * 3.0;
    final activeIndex = phaseProgress.floor() % 3;
    final subT = phaseProgress - phaseProgress.floor();

    // Fast-out, slow-in / easeOutCubic curve for rapid acceleration then graceful docking
    final curvedT = Curves.fastOutSlowIn.transform(subT.clamp(0.0, 1.0));

    // Calculate current angle for each of the 3 droplets
    const spacing = 0.65; // ~37 degrees between resting droplets
    const stepAdvance = (2 * math.pi) / 3.0; // 120 degrees advance per phase

    for (int i = 0; i < 3; i++) {
      double angle;
      double speedFactor = 0.0;

      if (i == activeIndex) {
        // This droplet is active: accelerates fast and travels around the circle
        // to stop behind the last one
        final startAngle = (activeIndex * stepAdvance) - spacing;
        final targetAngle = (activeIndex * stepAdvance) + (2 * math.pi - 2 * spacing);
        angle = startAngle + (targetAngle - startAngle) * curvedT;
        // Elongate and glow more while moving fast
        speedFactor = math.sin(subT * math.pi);
      } else {
        // Resting droplets
        final int relativePos = (i - activeIndex + 3) % 3;
        if (relativePos == 1) {
          // Front resting droplet
          angle = (activeIndex * stepAdvance) + (2 * math.pi - 4 * spacing);
        } else {
          // Last resting droplet (the one being docked behind)
          angle = (activeIndex * stepAdvance) + (2 * math.pi - 3 * spacing);
        }
      }

      // Compute droplet center on circle
      final dropletPos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      // Orientation angle along circle tangent (direction of motion)
      final tangentAngle = angle + (math.pi / 2);

      _drawWaterDroplet(
        canvas,
        dropletPos,
        tangentAngle,
        dropletSize,
        speedFactor,
      );
    }
  }

  void _drawWaterDroplet(
    Canvas canvas,
    Offset position,
    double tangentAngle,
    double baseSize,
    double speedFactor,
  ) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(tangentAngle);

    final stretch = 1.0 + (speedFactor * 0.45); // Elongates when fast
    final width = baseSize * (1.0 - (speedFactor * 0.15));
    final height = baseSize * stretch;

    // Outer glow for water clarity
    final shadowPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.35 + (speedFactor * 0.25))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawCircle(Offset(0, height * 0.1), width * 0.6, shadowPaint);

    // Teardrop path pointing forward
    final path = Path();
    final r = width / 2;
    final tipY = height * 0.55;
    final backY = -height * 0.35;

    path.moveTo(0, tipY);
    // Right curve from tip to back rounded bulb
    path.cubicTo(
      r * 1.0, tipY * 0.4,
      r * 1.1, backY * 0.2,
      r, backY,
    );
    // Rounded bulb at the back
    path.arcToPoint(
      Offset(-r, backY),
      radius: Radius.circular(r),
      clockwise: false,
    );
    // Left curve from back bulb to tip
    path.cubicTo(
      -r * 1.1, backY * 0.2,
      -r * 1.0, tipY * 0.4,
      0, tipY,
    );
    path.close();

    // Vibrant water gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primaryColor,
        secondaryColor,
        const Color(0xFF0369A1),
      ],
      stops: const [0.0, 0.6, 1.0],
    );

    final dropPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(-r, -height / 2, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, dropPaint);

    // Specular highlight (water droplet light reflection)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.3, backY * 0.6),
        width: r * 0.4,
        height: r * 0.65,
      ),
      highlightPaint,
    );

    // Small sparkle dot
    final sparklePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(-r * 0.25, backY * 0.15), r * 0.16, sparklePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaterDropletsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
