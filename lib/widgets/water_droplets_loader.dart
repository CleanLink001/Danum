import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An animated loader where 3 water droplets interact in a circular motion:
/// 1. Incoming droplet arrives at Left and pushes Left to Middle.
/// 2. Middle droplet is pushed to Right.
/// 3. The droplet on the Right rotates around the circle (with its round head
///    forward and pointy tail trailing behind at the back) back to Left.
/// 4. Loop repeats continuously with organic water physics.
class WaterDropletsCircleLoader extends StatefulWidget {
  final double radius;
  final double dropletSize;
  final Widget? centerWidget;
  final Color primaryColor;
  final Color secondaryColor;

  const WaterDropletsCircleLoader({
    super.key,
    this.radius = 56.0,
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
    // 3 complete push-and-rotate cycles: 1200ms per cycle = 3600ms total
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
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
                painter: _WaterDropletsPhysicsPainter(
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

class _WaterDropletsPhysicsPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final double radius;
  final double dropletSize;
  final Color primaryColor;
  final Color secondaryColor;

  _WaterDropletsPhysicsPainter({
    required this.progress,
    required this.radius,
    required this.dropletSize,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Subtle water guide orbit track
    final trackPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, trackPaint);

    // Angular positions on the circle (in radians):
    // Coordinates: standard math angles where 0 = Right, pi/2 = Bottom, pi = Left, -pi/2 = Top
    // Left: bottom-left arc (approx 145 deg)
    const angleLeft = 2.53; 
    // Middle: bottom center (90 deg = pi/2)
    const angleMid = math.pi / 2;
    // Right: bottom-right arc (approx 35 deg)
    const angleRight = 0.61;

    // Split progress into 3 distinct cycles for the 3 droplets
    final globalT = progress * 3.0;
    final cycleIndex = globalT.floor() % 3;
    final cycleT = globalT - globalT.floor(); // 0.0 to 1.0 inside this cycle

    // In each cycle:
    // Phase 1 (0.0 to 0.28): Push phase
    // - Incoming droplet docks at Left
    // - Left droplet is pushed to Middle
    // - Middle droplet is pushed to Right
    // Phase 2 (0.28 to 1.0): Rotate phase
    // - Droplet on the Right launches and rotates counter-clockwise over the top
    //   all the way to the Left!
    // - Left & Middle droplets rest quietly.

    const pushThreshold = 0.28;
    final isPushPhase = cycleT < pushThreshold;

    // Role assignment for this cycle:
    // Droplet A: arrived at Left (pusher)
    // Droplet B: pushed Left -> Middle
    // Droplet C: pushed Middle -> Right, then ROTATES around the circle!
    final dropletA = cycleIndex;
    final dropletB = (cycleIndex + 1) % 3;
    final dropletC = (cycleIndex + 2) % 3;

    final dropletAngles = List<double>.filled(3, 0.0);
    final dropletHeadAngles = List<double>.filled(3, 0.0);
    final dropletStretches = List<double>.filled(3, 0.0);

    if (isPushPhase) {
      final pushT = cycleT / pushThreshold;
      // Fast responsive push curve
      final curvedPush = Curves.easeOutCubic.transform(pushT);

      // Droplet A: settles at Left
      dropletAngles[dropletA] = angleLeft;
      // Tangent pointing rightwards/forward (tail trailing to left)
      dropletHeadAngles[dropletA] = -math.pi * 0.15; 
      dropletStretches[dropletA] = 0.05 * (1.0 - pushT);

      // Droplet B: pushed from Left -> Middle
      dropletAngles[dropletB] = angleLeft + (angleMid - angleLeft) * curvedPush;
      // Moving counter-clockwise towards Middle (direction of velocity)
      dropletHeadAngles[dropletB] = dropletAngles[dropletB] - (math.pi / 2);
      dropletStretches[dropletB] = math.sin(pushT * math.pi) * 0.25;

      // Droplet C: pushed from Middle -> Right
      dropletAngles[dropletC] = angleMid + (angleRight - angleMid) * curvedPush;
      dropletHeadAngles[dropletC] = dropletAngles[dropletC] - (math.pi / 2);
      dropletStretches[dropletC] = math.sin(pushT * math.pi) * 0.25;
    } else {
      final rotateT = (cycleT - pushThreshold) / (1.0 - pushThreshold);
      // Fast, liquid rotation curve: accelerates quickly and glides smoothly
      final curvedRotate = Curves.easeInOutCubic.transform(rotateT);

      // Droplet A: rests at Left
      dropletAngles[dropletA] = angleLeft;
      dropletHeadAngles[dropletA] = angleLeft - (math.pi / 2);
      dropletStretches[dropletA] = 0.0;

      // Droplet B: rests at Middle
      dropletAngles[dropletB] = angleMid;
      dropletHeadAngles[dropletB] = angleMid - (math.pi / 2);
      dropletStretches[dropletB] = 0.0;

      // Droplet C: ROTATES around the circle from Right through Top to Left!
      // Total counter-clockwise travel around the circle:
      const totalSweep = (2 * math.pi) - (angleLeft - angleRight);
      final currentAngle = angleRight - (totalSweep * curvedRotate);

      dropletAngles[dropletC] = currentAngle;
      // Direction of motion along circle: velocity vector angle is tangent
      // For counter-clockwise rotation: angle - pi/2
      dropletHeadAngles[dropletC] = currentAngle - (math.pi / 2);
      // High stretch factor during fast flight
      dropletStretches[dropletC] = math.sin(rotateT * math.pi) * 0.45;
    }

    // Draw tiny water impact ripple when rotating droplet arrives at Left
    if (cycleT < 0.20) {
      final rippleT = cycleT / 0.20;
      final ripplePos = Offset(
        center.dx + radius * math.cos(angleLeft),
        center.dy + radius * math.sin(angleLeft),
      );
      final ripplePaint = Paint()
        ..color = primaryColor.withValues(alpha: (1.0 - rippleT) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - rippleT);
      canvas.drawCircle(ripplePos, dropletSize * (0.6 + rippleT * 0.8), ripplePaint);
    }

    // Draw the 3 water droplets
    for (int i = 0; i < 3; i++) {
      final angle = dropletAngles[i];
      final headAngle = dropletHeadAngles[i];
      final stretch = dropletStretches[i];

      final pos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      _drawWaterDroplet(
        canvas: canvas,
        center: pos,
        directionAngle: headAngle,
        baseSize: dropletSize,
        stretchFactor: stretch,
      );
    }
  }

  /// Draws an authentic water droplet:
  /// - Round bulbous head in FRONT (direction of motion)
  /// - Pointy tapered tail at the BACK (trailing behind)
  /// - Specular white liquid reflection on the dome
  void _drawWaterDroplet({
    required Canvas canvas,
    required Offset center,
    required double directionAngle,
    required double baseSize,
    required double stretchFactor,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Rotate so local +Y is the forward motion direction
    canvas.rotate(directionAngle);

    final width = baseSize * (1.0 - (stretchFactor * 0.12));
    final r = width * 0.46; // Radius of round head
    final headY = r * 0.6;   // Round head center at the FRONT (+Y)
    // Pointy tail stretches out towards the BACK (-Y)
    final tailY = -(baseSize * (0.75 + stretchFactor * 0.55));

    // Glowing liquid drop shadow
    final glowPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.35 + stretchFactor * 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(Offset(0, headY * 0.5), r * 1.2, glowPaint);

    // Build the authentic teardrop path:
    // 1. Pointy tip at the back (0, tailY)
    // 2. Smooth cubic curve from tail to the wide round head on the right
    // 3. Round semicircular arc across the front (+Y)
    // 4. Smooth cubic curve back to the pointy tail on the left
    final path = Path();
    path.moveTo(0, tailY);

    // Right curve from pointy tail to round head
    path.cubicTo(
      r * 0.35, tailY * 0.4,
      r * 1.05, headY - r * 0.3,
      r, headY,
    );

    // Round front head (semicircle facing forward in +Y)
    path.arcToPoint(
      Offset(-r, headY),
      radius: Radius.circular(r),
      clockwise: false,
    );

    // Left curve from round head back to pointy tail
    path.cubicTo(
      -r * 1.05, headY - r * 0.3,
      -r * 0.35, tailY * 0.4,
      0, tailY,
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
      stops: const [0.0, 0.55, 1.0],
    );

    final totalHeight = headY + r - tailY;
    final fillPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(-r, tailY, width, totalHeight),
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Specular highlight: glossy light reflection on the rounded front dome
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..style = PaintingStyle.fill;

    // Curved gloss arc on front head
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.28, headY + r * 0.28),
        width: r * 0.45,
        height: r * 0.32,
      ),
      highlightPaint,
    );

    // Small sparkle dot
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(-r * 0.15, headY + r * 0.48),
      r * 0.15,
      dotPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaterDropletsPhysicsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
