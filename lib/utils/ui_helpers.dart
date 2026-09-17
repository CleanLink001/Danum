import 'package:flutter/material.dart';

class UIHelpers {
  static void showMetricDetails(
    BuildContext context, 
    String title, 
    String value, 
    String unit, 
    bool isSafe, 
    String info, 
    String threshold, 
    Color color
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Builder(
          builder: (context) {
            bool isPopping = false;
            return NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (!isPopping && notification.metrics.pixels < -60) {
                  isPopping = true;
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  return true;
                }
                return false;
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, 
                        height: 4, 
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black26, 
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(title, style: TextStyle(fontSize: 15, color: subColor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
                        color: color.withValues(alpha: 0.08),
                      ),
                      child: Column(
                        children: [
                          Text(value, style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -2)),
                          Text('${title.split(' ')[0]} LVL', style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: (isSafe ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isSafe ? 'SAFE' : 'UNSAFE',
                          style: TextStyle(color: isSafe ? (isDark ? Colors.greenAccent : const Color(0xFF059669)) : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    _buildInfoCard(context, color, info, 'Safe Threshold:', threshold),
                    const SizedBox(height: 25),
                    _buildGotItButton(context, color),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static void showScoreExplanation(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final cardBg = isDark ? const Color(0xFF132238) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Builder(
          builder: (context) {
            bool isPopping = false;
            return NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (!isPopping && notification.metrics.pixels < -60) {
                  isPopping = true;
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  return true;
                }
                return false;
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, 
                        height: 4, 
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black26, 
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.help_outline_rounded, color: Color(0xFF0284C7), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('WATER QUALITY SCORE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
                              Text('0 to 100 Safety & Purity Index', style: TextStyle(fontSize: 12, color: subColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Explanation Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Base Target: 100 Points', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 6),
                          Text(
                            'The score starts at 100 for ideal water. Deductions are calculated automatically from 3 telemetry sensors:',
                            style: TextStyle(color: subColor, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          _buildRuleRow('1. pH Deviation', '-15 pts per 1.0 pH away from 7.0 (Ideal: 6.5–8.5)', Colors.blueAccent),
                          _buildRuleRow('2. TDS Mineral Scaling', '-0.1 pts per 1 ppm over 50 ppm (Ideal: < 600 ppm)', Colors.cyanAccent),
                          _buildRuleRow('3. Turbidity Cloudiness', '-10 pts per 1.0 NTU over 1.0 NTU (Ideal: < 5.0 NTU)', Colors.deepPurpleAccent),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tiers Legend
                    Text('STATUS TIERS', style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 10),
                    _buildTierRow('81 – 100', 'GOOD / SAFE', 'Water is clean & safe to consume.', const Color(0xFF10B981)),
                    _buildTierRow('51 – 80', 'FAIR / WARNING', 'Acceptable but approaching safety thresholds.', const Color(0xFFF59E0B)),
                    _buildTierRow('0 – 50', 'POOR / UNSAFE', 'Unsafe water! Automatic solenoid cut-off active.', const Color(0xFFEF4444)),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: const Text('UNDERSTOOD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget _buildRuleRow(String title, String rule, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right_rounded, color: color, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
                Text(rule, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTierRow(String range, String label, String desc, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text(range, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoCard(BuildContext context, Color color, String info, String label, String threshold) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : const Color(0xFF334155);
    final subColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: color, size: 20),
              const SizedBox(width: 10),
              Text('NEED TO KNOW', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 15),
          Text(info, style: TextStyle(color: textColor, fontSize: 14, height: 1.5)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(threshold, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildGotItButton(BuildContext context, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          elevation: 0,
        ),
        child: const Text('GOT IT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}
