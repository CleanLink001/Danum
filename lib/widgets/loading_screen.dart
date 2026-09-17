import 'package:flutter/material.dart';
import 'water_droplets_loader.dart';

class DanumLoadingScreen extends StatelessWidget {
  final String statusText;
  final bool isOverlay;

  const DanumLoadingScreen({
    super.key,
    this.statusText = 'Loading Danum System...',
    this.isOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isOverlay 
        ? (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.90) : Colors.white.withValues(alpha: 0.90))
        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC));
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WaterDropletsCircleLoader(
              radius: 65,
              dropletSize: 20,
              centerWidget: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(45),
                  child: Image.asset(
                    'web/icons/Icon-Danum.jpeg',
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF0284C7),
                        child: const Icon(Icons.water_drop_rounded, size: 45, color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'DANUM MONITOR',
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: TextStyle(
                color: subColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Color(0x220284C7),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
