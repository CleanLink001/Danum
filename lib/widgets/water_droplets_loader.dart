import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// An authentic physics-based water droplet loader.
///
/// Exactly 3 realistic liquid water droplets travel around an invisible or glowing
/// circular orbit under a curved gravitational field.
///
/// Physics features:
/// - Tangential gravity projection, driving acceleration & deceleration
/// - Fluid damping and viscosity
/// - Surface tension / separation spring forces maintaining ~120° spacing
/// - Velocity-based fluid elongation and spray particles
///
/// Visual appearance (matches reference):
/// - Curved water teardrop geometry hugging the orbit
/// - Glass-like caustic refraction, translucent liquid gradient, and specular white reflections
/// - Trailing splash droplets (wake beads) flying behind the pointy tail
/// - Glowing circular water trace
class WaterDropletsCircleLoader extends StatefulWidget {
  final double radius;
  final double dropletSize;
  final Color primaryColor;
  final Color secondaryColor;

  const WaterDropletsCircleLoader({
    super.key,
    this.radius = 76.0,
    this.dropletSize = 22.0,
    this.primaryColor = const Color(0xFF38BDF8),
    this.secondaryColor = const Color(0xFF0284C7),
  });

  @override
  State<WaterDropletsCircleLoader> createState() => _WaterDropletsCircleLoaderState();
}

class _WaterDropletsCircleLoaderState extends State<WaterDropletsCircleLoader>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration? _lastElapsed;
  double _totalTime = 0.0;

  // 3 droplet physics states: angle (rad), angular velocity (rad/s)
  final List<double> _angles = [
    0.0,
    (2 * math.pi) / 3.0,
    (4 * math.pi) / 3.0,
  ];

  final List<double> _velocities = [2.4, 2.4, 2.4];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == null) {
      _lastElapsed = elapsed;
      return;
    }

    final double dt = ((elapsed - _lastElapsed!).inMicroseconds / 1000000.0).clamp(0.001, 0.033);
    _lastElapsed = elapsed;
    _totalTime += dt;

    _updatePhysics(dt);
    if (mounted) {
      setState(() {});
    }
  }

  void _updatePhysics(double dt) {
    // Dynamic curved gravity field:
    // A traveling gravitational wave rotates around the circle, creating
    // zones where gravity pulls droplets forward (acceleration) and zones
    // where they climb against gravity (deceleration).
    final double fieldWave = _totalTime * 1.6;

    for (int i = 0; i < 3; i++) {
      final double theta = _angles[i];

      // 1. Tangential gravity:
      // Downward gravity projection cos(theta) + rotating gravitational surge sin(theta - fieldWave)
      final double gDown = 6.0 * math.cos(theta);
      final double gWave = 5.0 * math.sin(theta - fieldWave);
      final double drivingForce = 8.5 + (gDown * 0.7) + (gWave * 0.8);

      // 2. Viscous fluid damping (air & water resistance)
      final double damping = 3.2 * _velocities[i];

      // 3. Elastic separation spring force between adjacent droplets:
      // Ensures droplets remain ~120° (2*pi/3) apart while letting them breathe naturally
      final int nextIndex = (i + 1) % 3;
      double diffForward = _angles[nextIndex] - theta;
      while (diffForward < 0) {
        diffForward += 2 * math.pi;
      }
      while (diffForward >= 2 * math.pi) {
        diffForward -= 2 * math.pi;
      }

      final double spacingError = diffForward - ((2 * math.pi) / 3.0);
      final double springForce = spacingError * 14.0;

      // Net tangential angular acceleration
      final double angularAcc = drivingForce - damping + springForce;

      // Integrate: velocity += acc * dt, angle += velocity * dt
      _velocities[i] += angularAcc * dt;
      // Clamp velocity to smooth, natural liquid speeds
      _velocities[i] = _velocities[i].clamp(1.1, 4.6);

      _angles[i] += _velocities[i] * dt;
      if (_angles[i] >= 2 * math.pi) {
        _angles[i] -= 2 * math.pi;
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSize = (widget.radius + widget.dropletSize + 24) * 2;

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: CustomPaint(
        size: Size(totalSize, totalSize),
        painter: _RealisticWaterDropletsPainter(
          angles: _angles,
          velocities: _velocities,
          radius: widget.radius,
          dropletSize: widget.dropletSize,
          primaryColor: widget.primaryColor,
          secondaryColor: widget.secondaryColor,
        ),
      ),
    );
  }
}

class _RealisticWaterDropletsPainter extends CustomPainter {
  final List<double> angles;
  final List<double> velocities;
  final double radius;
  final double dropletSize;
  final Color primaryColor;
  final Color secondaryColor;

  _RealisticWaterDropletsPainter({
    required this.angles,
    required this.velocities,
    required this.radius,
    required this.dropletSize,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Glowing circular water ring (orbit track)
    _drawGlowingOrbitRing(canvas, center);

    // 2. Trailing water wakes along the orbit
    for (int i = 0; i < 3; i++) {
      _drawDropletWake(canvas, center, angles[i], velocities[i]);
    }

    // 3. Draw each of the 3 realistic water droplets
    for (int i = 0; i < 3; i++) {
      _drawWaterDroplet(
        canvas: canvas,
        center: center,
        angle: angles[i],
        velocity: velocities[i],
      );
    }
  }

  void _drawGlowingOrbitRing(Canvas canvas, Offset center) {
    // Outer ethereal glow
    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(center, radius, glowPaint);

    // Subtle crisp luminescent trace
    final corePaint = Paint()
      ..color = const Color(0xFF7DD3FC).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, radius, corePaint);
  }

  void _drawDropletWake(Canvas canvas, Offset center, double headAngle, double velocity) {
    // A luminous wake arc trailing behind the droplet
    final wakeLength = 0.55 + (velocity - 1.1) * 0.12;
    final startAngle = headAngle - wakeLength;

    final wakeRect = Rect.fromCircle(center: center, radius: radius);
    final wakePaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: headAngle,
        colors: [
          primaryColor.withValues(alpha: 0.0),
          primaryColor.withValues(alpha: 0.45),
        ],
        stops: const [0.0, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(wakeRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    canvas.drawArc(wakeRect, startAngle, wakeLength, false, wakePaint);
  }

  void _drawWaterDroplet({
    required Canvas canvas,
    required Offset center,
    required double angle, // Current position of head along circle
    required double velocity,
  }) {
    // Velocity stretch factor: as the droplet accelerates under gravity,
    // its body and tail elongate along the orbit
    final speedNorm = ((velocity - 1.1) / 3.5).clamp(0.0, 1.0);
    final tailAngleLength = 0.36 + (speedNorm * 0.22); // Arc in radians
    final headRadius = (dropletSize * 0.46) * (1.0 - speedNorm * 0.12);

    // Droplet landmarks on the circle:
    // Head center
    final headPos = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    // Tail tip position (trailing behind clockwise motion)
    final tailAngle = angle - tailAngleLength;
    final tailPos = Offset(
      center.dx + radius * math.cos(tailAngle),
      center.dy + radius * math.sin(tailAngle),
    );

    // Motion direction tangent vector at head
    final tangent = Offset(-math.sin(angle), math.cos(angle));
    // Normal vector pointing outwards
    final normal = Offset(math.cos(angle), math.sin(angle));

    // Outer and inner shoulder points at the head
    final outerShoulder = Offset(
      center.dx + (radius + headRadius) * math.cos(angle),
      center.dy + (radius + headRadius) * math.sin(angle),
    );

    final innerShoulder = Offset(
      center.dx + (radius - headRadius) * math.cos(angle),
      center.dy + (radius - headRadius) * math.sin(angle),
    );

    // Front rounded nose tip
    final noseTip = headPos + (tangent * (headRadius * 1.08));

    // Construct curved teardrop path hugging the circular orbit
    final path = Path();
    path.moveTo(tailPos.dx, tailPos.dy);

    // 1. Outer curved flank: from pointy tail to outer head shoulder
    final midAngleOuter = angle - (tailAngleLength * 0.45);
    final cp1Outer = Offset(
      center.dx + (radius + headRadius * 0.3) * math.cos(tailAngle + tailAngleLength * 0.25),
      center.dy + (radius + headRadius * 0.3) * math.sin(tailAngle + tailAngleLength * 0.25),
    );
    final cp2Outer = Offset(
      center.dx + (radius + headRadius * 1.1) * math.cos(midAngleOuter),
      center.dy + (radius + headRadius * 1.1) * math.sin(midAngleOuter),
    );
    path.cubicTo(cp1Outer.dx, cp1Outer.dy, cp2Outer.dx, cp2Outer.dy, outerShoulder.dx, outerShoulder.dy);

    // 2. Round front head (leading the motion)
    final cpNose1 = outerShoulder + (tangent * (headRadius * 0.65));
    final cpNose2 = noseTip + (normal * (headRadius * 0.35));
    path.cubicTo(cpNose1.dx, cpNose1.dy, cpNose2.dx, cpNose2.dy, noseTip.dx, noseTip.dy);

    final cpNose3 = noseTip - (normal * (headRadius * 0.35));
    final cpNose4 = innerShoulder + (tangent * (headRadius * 0.65));
    path.cubicTo(cpNose3.dx, cpNose3.dy, cpNose4.dx, cpNose4.dy, innerShoulder.dx, innerShoulder.dy);

    // 3. Inner curved flank: from inner head shoulder back to pointy tail
    final midAngleInner = angle - (tailAngleLength * 0.45);
    final cp1Inner = Offset(
      center.dx + (radius - headRadius * 1.1) * math.cos(midAngleInner),
      center.dy + (radius - headRadius * 1.1) * math.sin(midAngleInner),
    );
    final cp2Inner = Offset(
      center.dx + (radius - headRadius * 0.3) * math.cos(tailAngle + tailAngleLength * 0.25),
      center.dy + (radius - headRadius * 0.3) * math.sin(tailAngle + tailAngleLength * 0.25),
    );
    path.cubicTo(cp1Inner.dx, cp1Inner.dy, cp2Inner.dx, cp2Inner.dy, tailPos.dx, tailPos.dy);
    path.close();

    // A. Soft liquid drop shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.45 + speedNorm * 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0);
    canvas.drawPath(path, shadowPaint);

    // B. Glass-like translucent gradient fill
    final bounds = path.getBounds();
    final bodyGradient = LinearGradient(
      begin: Alignment(tangent.dx * 0.8 - normal.dx * 0.5, tangent.dy * 0.8 - normal.dy * 0.5),
      end: Alignment(-tangent.dx * 0.8 + normal.dx * 0.5, -tangent.dy * 0.8 + normal.dy * 0.5),
      colors: const [
        Color(0xF2E0F2FE), // Bright water gloss crest
        Color(0xE038BDF8), // Translucent sky cyan
        Color(0xD90284C7), // Deep ocean azure
        Color(0xCC0369A1), // Shaded base
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    final fillPaint = Paint()
      ..shader = bodyGradient.createShader(bounds)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // C. Inner caustic refraction glow inside the droplet belly
    final causticPaint = Paint()
      ..color = const Color(0x99BAE6FD)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawCircle(headPos - (tangent * (headRadius * 0.25)), headRadius * 0.55, causticPaint);

    // D. Outer specular reflection highlight (arc along the outer convex crest)
    final specPath = Path();
    specPath.moveTo(
      center.dx + (radius + headRadius * 0.75) * math.cos(angle - tailAngleLength * 0.25),
      center.dy + (radius + headRadius * 0.75) * math.sin(angle - tailAngleLength * 0.25),
    );
    specPath.cubicTo(
      outerShoulder.dx + tangent.dx * (headRadius * 0.2),
      outerShoulder.dy + tangent.dy * (headRadius * 0.2),
      noseTip.dx + normal.dx * (headRadius * 0.25),
      noseTip.dy + normal.dy * (headRadius * 0.25),
      noseTip.dx, noseTip.dy,
    );

    final specPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;
    canvas.drawPath(specPath, specPaint);

    // E. Crisp specular sparkle reflection dot on the leading dome
    final gleamPos = headPos + (tangent * (headRadius * 0.5)) + (normal * (headRadius * 0.35));
    final gleamPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(gleamPos, headRadius * 0.24, gleamPaint);

    // Secondary smaller highlight dot
    canvas.drawCircle(
      headPos + (tangent * (headRadius * 0.75)),
      headRadius * 0.14,
      gleamPaint..color = Colors.white.withValues(alpha: 0.85),
    );

    // F. Trailing water spray beads (tiny liquid drops flying in the wake)
    _drawWakeSprayBeads(canvas, center, tailAngle, speedNorm);
  }

  void _drawWakeSprayBeads(Canvas canvas, Offset center, double tailAngle, double speedNorm) {
    // 3 tiny droplet beads flying in the wake behind the pointy tail
    final beads = [
      {'dist': 0.075, 'size': 2.8, 'alpha': 0.85, 'radialOffset': 0.0},
      {'dist': 0.140, 'size': 2.1, 'alpha': 0.65, 'radialOffset': 1.8},
      {'dist': 0.200, 'size': 1.4, 'alpha': 0.45, 'radialOffset': -1.5},
    ];

    for (final b in beads) {
      final bAngle = tailAngle - (b['dist'] as double);
      final r = radius + (b['radialOffset'] as double);
      final pos = Offset(
        center.dx + r * math.cos(bAngle),
        center.dy + r * math.sin(bAngle),
      );

      final beadSize = (b['size'] as double) * (0.85 + speedNorm * 0.35);
      final alpha = (b['alpha'] as double);

      // Liquid bead body
      final beadPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, beadSize, beadPaint);

      // Tiny white specular glint
      final glintPaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos - const Offset(0.5, 0.5), beadSize * 0.35, glintPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RealisticWaterDropletsPainter oldDelegate) {
    return true; // Continuously updated by ticker physics simulation
  }
}
