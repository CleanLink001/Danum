import 'package:flutter/material.dart';
import '../models/water_quality.dart';

import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class OverallStatus extends StatelessWidget {
  final WaterQualityData data;
  final VoidCallback? onTap;

  const OverallStatus({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    String status = data.status;
    int score = data.score;
    Color statusColor;

    switch (status) {
      case 'Good':
        statusColor = const Color(0xFF10B981);
        break;
      case 'Fair':
        statusColor = const Color(0xFFF59E0B);
        break;
      default:
        statusColor = const Color(0xFFEF4444);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 2),
            gradient: LinearGradient(
              colors: [
                statusColor.withValues(alpha: 0.15),
                isDark ? Colors.transparent : Colors.white.withValues(alpha: 0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      settings.translate('water_quality'),
                      style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      settings.translate('live_analysis'),
                      style: TextStyle(color: subColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 100,
                    width: 100,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      backgroundColor: textColor.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'SCORE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subColor),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ],
);
  }
}
