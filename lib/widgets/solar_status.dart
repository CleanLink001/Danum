import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class SolarStatus extends StatelessWidget {
  final double voltage;

  const SolarStatus({super.key, required this.voltage});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Status based on voltage
    String status;
    Color statusColor;
    double percentage = (voltage - 10.5) / (14.8 - 10.5);
    percentage = percentage.clamp(0, 1).toDouble();

    if (voltage > 12.5) {
      status = settings.translate('solar_charging');
      statusColor = const Color(0xFF10B981);
    } else if (voltage > 11.5) {
      status = settings.translate('solar_normal');
      statusColor = const Color(0xFFF59E0B);
    } else {
      status = settings.translate('solar_low_battery');
      statusColor = const Color(0xFFEF4444);
    }

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 2),
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.1),
            isDark ? Colors.transparent : Colors.white.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  settings.translate('solar_power'),
                  style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  settings.translate('battery_voltage_output'),
                  style: TextStyle(color: subColor, fontSize: 13),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: textColor.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              Icon(
                Icons.solar_power,
                color: statusColor,
                size: 30,
              ),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${voltage.toStringAsFixed(1)}V',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              Text(
                'DC POWER',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: subColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
