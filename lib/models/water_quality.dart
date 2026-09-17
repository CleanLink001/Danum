class WaterQualityData {
  final double ph;
  final double tds;
  final double turbidity;
  final double filterHealth;
  final bool valveOpen;
  final double solarVoltage;
  final DateTime timestamp;

  WaterQualityData({
    required this.ph,
    required this.tds,
    required this.turbidity,
    required this.filterHealth,
    required this.valveOpen,
    required this.solarVoltage,
    required this.timestamp,
  });

  int get score {
    double s = 100;
    // pH: Ideal 7.0. Penalty for deviation.
    s -= (ph - 7.0).abs() * 15;
    // TDS: Ideal < 50. Penalty above.
    if (tds > 50) s -= (tds - 50) * 0.1;
    // Turbidity: Ideal < 1. Penalty above.
    if (turbidity > 1) s -= (turbidity - 1) * 10;
    if (s.isNaN || s.isInfinite) return 0;
    return s.clamp(0.0, 100.0).round().toInt();
  }

  bool get isSafe => ph >= 6.5 && ph <= 8.5 && tds <= 600.0 && turbidity <= 5.0;

  String get status {
    int s = score;
    if (s > 80) return 'Good';
    if (s > 50) return 'Fair';
    return 'Poor';
  }

  Map<String, dynamic> toJson() => {
        'ph': ph,
        'tds': tds,
        'turbidity': turbidity,
        'filterHealth': filterHealth,
        'valveOpen': valveOpen,
        'solarVoltage': solarVoltage,
        'timestamp': timestamp.toIso8601String(),
      };

  factory WaterQualityData.fromJson(Map<String, dynamic> json) {
    DateTime parsedTimestamp = DateTime.now();

    final rawTime = json['timestamp'] ?? json['created_at'];
    if (rawTime is num) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(rawTime.toInt());
    } else if (rawTime is String) {
      parsedTimestamp = DateTime.tryParse(rawTime) ?? DateTime.now();
    }

    final dynamic rawValve = json['valveOpen'] ?? json['valve_open'];
    final bool valveState = rawValve is bool
        ? rawValve
        : (rawValve == 1 || rawValve == '1' || rawValve == true);

    return WaterQualityData(
      ph: (json['ph'] as num?)?.toDouble() ?? 7.0,
      tds: (json['tds'] as num?)?.toDouble() ?? 150.0,
      turbidity: (json['turbidity'] as num?)?.toDouble() ?? 1.0,
      filterHealth: (json['filterHealth'] as num?)?.toDouble() ?? (json['filter_health'] as num?)?.toDouble() ?? 100.0,
      valveOpen: valveState,
      solarVoltage: (json['solarVoltage'] as num?)?.toDouble() ?? (json['solar_voltage'] as num?)?.toDouble() ?? 12.0,
      timestamp: parsedTimestamp,
    );
  }
}
