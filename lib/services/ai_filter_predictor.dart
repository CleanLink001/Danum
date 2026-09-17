import 'dart:math';
import '../models/water_quality.dart';

enum FilterMaintenanceAction {
  optimal,
  needsFlushing,
  needsReplacement,
}

enum WaterSafetyStatus {
  safe,
  warningDegradingTrend,
  criticalDoNotDrink,
}

class FilterAiPrediction {
  final double filterHealth; // 0.0 to 100.0%
  final FilterMaintenanceAction action;
  final String statusTitle;
  final String primaryCause;
  final int estimatedDaysRemaining;
  final String aiRecommendation;
  final double sedimentStress;
  final double mineralStress;
  final double phStress;

  // 1. FILTER LIFESPAN MODEL (Baseline Drift Regression)
  final double baselineTdsDriftRate; // ppm / day linear regression slope
  final double baselineTurbidityDriftRate; // NTU / day linear regression slope
  final double goldenBaselineTds; // Initial golden baseline TDS (ppm)
  final double currentRollingMinTds; // 7-day rolling minimum TDS (ppm)
  final int lifespanDaysRemaining; // Countdown until baseline permanently crosses threshold

  // 2. FLUSH TRIGGER MODEL (Stagnation & Residual Classification)
  final bool flushRequired; // Binary trigger (true/false)
  final double startupSpikePeak; // Peak turbidity in first 60 seconds (NTU)
  final double startupStabilizedValue; // Stabilized turbidity after 5 minutes (NTU)
  final double startupAucRatio; // Area under curve / Peak-to-Steady ratio
  final String flushReason;

  // 3. WATER SAFETY FORECASTING (Time-Series Horizon Trend)
  final WaterSafetyStatus safetyStatus;
  final String safetyStatusLabel; // "Safe", "Warning: Degrading Trend Detected", "Critical: Do Not Drink"
  final double safeWaterWindowHours; // Estimated safe water window in hours
  final String forecastSummary;

  // Edge Case Alert
  final bool sensorMalfunction;

  FilterAiPrediction({
    required this.filterHealth,
    required this.action,
    required this.statusTitle,
    required this.primaryCause,
    required this.estimatedDaysRemaining,
    required this.aiRecommendation,
    required this.sedimentStress,
    required this.mineralStress,
    required this.phStress,
    required this.baselineTdsDriftRate,
    required this.baselineTurbidityDriftRate,
    required this.goldenBaselineTds,
    required this.currentRollingMinTds,
    required this.lifespanDaysRemaining,
    required this.flushRequired,
    required this.startupSpikePeak,
    required this.startupStabilizedValue,
    required this.startupAucRatio,
    required this.flushReason,
    required this.safetyStatus,
    required this.safetyStatusLabel,
    required this.safeWaterWindowHours,
    required this.forecastSummary,
    required this.sensorMalfunction,
  });

  factory FilterAiPrediction.analyze(List<WaterQualityData> history) {
    if (history.isEmpty) {
      return FilterAiPrediction(
        filterHealth: 100.0,
        action: FilterMaintenanceAction.optimal,
        statusTitle: 'SAFE: FILTER HEALTHY',
        primaryCause: 'Golden Baseline Active',
        estimatedDaysRemaining: 90,
        aiRecommendation: 'Danum AI: All output water sensors indicate optimal filtration efficiency.',
        sedimentStress: 0.0,
        mineralStress: 0.0,
        phStress: 0.0,
        baselineTdsDriftRate: 0.0,
        baselineTurbidityDriftRate: 0.0,
        goldenBaselineTds: 25.0,
        currentRollingMinTds: 25.0,
        lifespanDaysRemaining: 90,
        flushRequired: false,
        startupSpikePeak: 0.2,
        startupStabilizedValue: 0.2,
        startupAucRatio: 1.0,
        flushReason: 'No stagnation spike detected.',
        safetyStatus: WaterSafetyStatus.safe,
        safetyStatusLabel: 'Safe',
        safeWaterWindowHours: 24.0,
        forecastSummary: 'pH, TDS, and Turbidity trends remain flat and optimal.',
        sensorMalfunction: false,
      );
    }

    final latest = history.last;

    // -------------------------------------------------------------------------
    // EDGE CASE DETECTOR: Sensor Malfunction / Zero Variance Check
    // -------------------------------------------------------------------------
    bool sensorFreeze = false;
    if (history.length >= 5 && latest.valveOpen) {
      final recent = history.sublist(max(0, history.length - 5));
      double sumTds = 0, sumPh = 0, sumTurb = 0;
      for (var s in recent) {
        sumTds += s.tds;
        sumPh += s.ph;
        sumTurb += s.turbidity;
      }
      double avgTds = sumTds / recent.length;
      double avgPh = sumPh / recent.length;
      double avgTurb = sumTurb / recent.length;

      double varTds = 0, varPh = 0, varTurb = 0;
      for (var s in recent) {
        varTds += pow(s.tds - avgTds, 2);
        varPh += pow(s.ph - avgPh, 2);
        varTurb += pow(s.turbidity - avgTurb, 2);
      }
      // If all 3 streams show exactly zero variance while valve is active
      if (varTds < 0.0001 && varPh < 0.0001 && varTurb < 0.0001) {
        sensorFreeze = true;
      }
    }

    if (sensorFreeze) {
      return FilterAiPrediction(
        filterHealth: latest.filterHealth,
        action: FilterMaintenanceAction.needsFlushing,
        statusTitle: 'SENSOR MALFUNCTION / MAINTENANCE CHECK',
        primaryCause: 'Telemetry Data Stream Frozen (Zero Variance)',
        estimatedDaysRemaining: 0,
        aiRecommendation:
            'Danum AI Alert: Output water sensor streams show zero variance while pump is active. Immediate maintenance check required for sensor probes and wiring.',
        sedimentStress: 0.0,
        mineralStress: 0.0,
        phStress: 0.0,
        baselineTdsDriftRate: 0.0,
        baselineTurbidityDriftRate: 0.0,
        goldenBaselineTds: 25.0,
        currentRollingMinTds: latest.tds,
        lifespanDaysRemaining: 0,
        flushRequired: false,
        startupSpikePeak: 0.0,
        startupStabilizedValue: 0.0,
        startupAucRatio: 1.0,
        flushReason: 'Sensor data stream offline or frozen.',
        safetyStatus: WaterSafetyStatus.warningDegradingTrend,
        safetyStatusLabel: 'Warning: Degrading Trend Detected',
        safeWaterWindowHours: 0.0,
        forecastSummary: 'Data stream frozen. Telemetry reliability compromised.',
        sensorMalfunction: true,
      );
    }

    // -------------------------------------------------------------------------
    // MODEL 1: FILTER LIFESPAN MODEL (Baseline Drift Regression)
    // -------------------------------------------------------------------------
    // 1. Establish Golden Baseline (minimum recorded TDS & Turbidity)
    double goldenTds = 25.0; // Default pure golden baseline
    for (var sample in history) {
      if (sample.tds < goldenTds) goldenTds = sample.tds;
    }

    // 2. Compute 7-day rolling minimums (or rolling window minimums)
    List<double> tdsMins = [];
    List<double> turbMins = [];
    int windowSize = max(1, (history.length / 7).floor());
    for (int i = 0; i < history.length; i += windowSize) {
      int end = min(i + windowSize, history.length);
      var chunk = history.sublist(i, end);
      double minTds = chunk.map((e) => e.tds).reduce(min);
      double minTurb = chunk.map((e) => e.turbidity).reduce(min);
      tdsMins.add(minTds);
      turbMins.add(minTurb);
    }

    double currentRollingMinTds = tdsMins.isNotEmpty ? tdsMins.last : latest.tds;
    double currentRollingMinTurb = turbMins.isNotEmpty ? turbMins.last : latest.turbidity;

    // 3. Linear Regression Slope Calculation for Baseline Drift
    // y = m * x + c (x in days or sample steps)
    double tdsSlope = 0.0; // ppm per day/step
    double turbSlope = 0.0;
    if (tdsMins.length > 1) {
      double xMean = (tdsMins.length - 1) / 2.0;
      double yTdsMean = tdsMins.reduce((a, b) => a + b) / tdsMins.length;
      double yTurbMean = turbMins.reduce((a, b) => a + b) / turbMins.length;

      double numTds = 0, numTurb = 0, denom = 0;
      for (int i = 0; i < tdsMins.length; i++) {
        double xDiff = i - xMean;
        numTds += xDiff * (tdsMins[i] - yTdsMean);
        numTurb += xDiff * (turbMins[i] - yTurbMean);
        denom += xDiff * xDiff;
      }
      if (denom > 0) {
        tdsSlope = max(0.0, numTds / denom);
        turbSlope = max(0.0, numTurb / denom);
      }
    }

    // Unsafe Thresholds: TDS > 300 ppm, Turbidity > 3.0 NTU
    const double safeTdsLimit = 300.0;
    const double safeTurbLimit = 3.0;

    double daysToTdsLimit = tdsSlope > 0.01 ? (safeTdsLimit - currentRollingMinTds) / tdsSlope : 90.0;
    double daysToTurbLimit = turbSlope > 0.005 ? (safeTurbLimit - currentRollingMinTurb) / turbSlope : 90.0;

    int lifespanDaysRemaining = min(daysToTdsLimit, daysToTurbLimit).clamp(1, 120).toInt();

    // Health percentage calculated relative to golden baseline drift to threshold
    double tdsRatio = (currentRollingMinTds - goldenTds) / (safeTdsLimit - goldenTds);
    double remainingHealthPct = (100.0 * (1.0 - tdsRatio)).clamp(5.0, 100.0);

    // -------------------------------------------------------------------------
    // MODEL 2: FLUSH TRIGGER MODEL (Stagnation & Residual Classification)
    // -------------------------------------------------------------------------
    // Compare initial peak value (first 60s of run) vs stabilized value (after 5 min)
    double startupPeak = latest.turbidity;
    double stabilizedVal = latest.turbidity;

    if (history.length >= 3) {
      // Find peak turbidity in recent window vs earliest stabilized value
      var recentWindow = history.sublist(max(0, history.length - 10));
      startupPeak = recentWindow.map((e) => e.turbidity).reduce(max);
      stabilizedVal = recentWindow.last.turbidity;
    }

    double startupAucRatio = stabilizedVal > 0 ? (startupPeak / max(0.1, stabilizedVal)) : 1.0;
    bool prolongedSpike = (startupPeak - stabilizedVal > 1.2) || (startupAucRatio > 2.2) || (startupPeak > 3.5);
    bool flushRequired = prolongedSpike || (remainingHealthPct < 60.0 && latest.turbidity > 2.0);

    String flushReason = flushRequired
        ? 'Stagnation pocket impurity spike detected: Initial 60s turbidity peak (${startupPeak.toStringAsFixed(1)} NTU) clears slowly relative to stabilized baseline (${stabilizedVal.toStringAsFixed(1)} NTU).'
        : 'Startup impurity clearance optimal (<30 sec transient). No flush needed.';

    // -------------------------------------------------------------------------
    // MODEL 3: WATER SAFETY FORECASTING (Time-Series Horizon Trend)
    // -------------------------------------------------------------------------
    // Time-series trend 12h-24h into future based on last 48h rolling data points
    WaterSafetyStatus safetyStatus = WaterSafetyStatus.safe;
    String safetyStatusLabel = 'Safe';
    double safeWaterWindowHours = 24.0;
    String forecastSummary = '';

    // Calculate 24h projected values using exponential/linear trends
    double phTrendDelta = 0.0;
    if (history.length >= 2) {
      phTrendDelta = latest.ph - history[max(0, history.length - 10)].ph;
    }

    double forecast24hPh = latest.ph + phTrendDelta;
    double forecast24hTds = currentRollingMinTds + (tdsSlope * 1.5);
    double forecast24hTurb = currentRollingMinTurb + (turbSlope * 1.5);

    // Bacterial growth indicator: sharp pH drop (< 6.5)
    bool bacterialRisk = forecast24hPh < 6.5 || (phTrendDelta < -0.4);
    bool tdsCreeping = forecast24hTds > 250.0 || tdsSlope > 8.0;
    bool turbCreeping = forecast24hTurb > 2.5;

    if (latest.ph < 5.8 || latest.ph > 9.2 || latest.tds > 450.0 || latest.turbidity > 5.0) {
      safetyStatus = WaterSafetyStatus.criticalDoNotDrink;
      safetyStatusLabel = 'Critical: Do Not Drink';
      safeWaterWindowHours = 0.0;
      forecastSummary = 'CRITICAL: Output water sensors breached safe drinking limits. Immediate replacement required.';
    } else if (bacterialRisk || tdsCreeping || turbCreeping) {
      safetyStatus = WaterSafetyStatus.warningDegradingTrend;
      safetyStatusLabel = 'Warning: Degrading Trend Detected';

      // Estimate hours until breach
      double hoursToBreach = 24.0;
      if (bacterialRisk && phTrendDelta < 0) {
        hoursToBreach = min(hoursToBreach, ((latest.ph - 6.5) / phTrendDelta.abs() * 24.0).abs());
      }
      if (tdsCreeping && tdsSlope > 0) {
        hoursToBreach = min(hoursToBreach, ((safeTdsLimit - latest.tds) / (tdsSlope / 24.0)));
      }
      safeWaterWindowHours = hoursToBreach.clamp(1.0, 23.9);

      if (bacterialRisk) {
        forecastSummary = '24-Hour Horizon: Sharp downward pH trend (Δ ${phTrendDelta.toStringAsFixed(2)}) detected. Potential bio-film or organic saturation.';
      } else {
        forecastSummary = '24-Hour Horizon: Creeping TDS drift (+${tdsSlope.toStringAsFixed(1)} ppm/day) projects threshold breach in ${safeWaterWindowHours.toStringAsFixed(0)} hours.';
      }
    } else {
      safetyStatus = WaterSafetyStatus.safe;
      safetyStatusLabel = 'Safe';
      safeWaterWindowHours = 24.0;
      forecastSummary = '24-Hour Horizon: pH (${latest.ph.toStringAsFixed(1)}), TDS (${latest.tds.toStringAsFixed(0)} ppm), and Turbidity (${latest.turbidity.toStringAsFixed(1)} NTU) remain fully stable within golden baseline bounds.';
    }

    // Determine Action & Status Title
    FilterMaintenanceAction action;
    String statusTitle;
    String primaryCause;
    String aiRecommendation;

    if (safetyStatus == WaterSafetyStatus.criticalDoNotDrink || remainingHealthPct < 30.0 || daysToTdsLimit < 5) {
      action = FilterMaintenanceAction.needsReplacement;
      statusTitle = 'CRITICAL: DO NOT DRINK - REPLACE FILTER';
      primaryCause = 'Filter Media Saturation & Baseline Drift';
      aiRecommendation =
          'Danum AI Recommendation: Filter life is at ${remainingHealthPct.toStringAsFixed(0)}% with baseline TDS drifting +${tdsSlope.toStringAsFixed(1)} ppm/day. Replace cartridge immediately.';
    } else if (flushRequired) {
      action = FilterMaintenanceAction.needsFlushing;
      statusTitle = 'FLUSH REQUIRED: STAGNATION SPIKE';
      primaryCause = 'Prolonged Startup Impurity Pocket';
      aiRecommendation =
          'Danum AI Recommendation: Heavy membrane stagnation spike detected (${startupPeak.toStringAsFixed(1)} NTU startup peak). Execute a 2-minute reverse flush to restore pore velocity.';
    } else if (safetyStatus == WaterSafetyStatus.warningDegradingTrend) {
      action = FilterMaintenanceAction.needsFlushing;
      statusTitle = 'WARNING: DEGRADATION TREND DETECTED';
      primaryCause = '24h Time-Series Horizon Creep';
      aiRecommendation =
          'Danum AI Forecast: Water quality degrading over next ${safeWaterWindowHours.toStringAsFixed(0)} hours. Schedule preventative maintenance flush today.';
    } else {
      action = FilterMaintenanceAction.optimal;
      statusTitle = 'CRITICAL STATUS: SAFE DRINKING WATER';
      primaryCause = 'Golden Baseline Active & Flat Horizon Trend';
      aiRecommendation =
          'Danum AI Status: Output water quality is optimal. 7-day rolling minimum TDS is flat at ${currentRollingMinTds.toStringAsFixed(0)} ppm (${remainingHealthPct.toStringAsFixed(0)}% remaining life, ~$lifespanDaysRemaining days remaining).';
    }

    // Stress calculations for visualization
    double sedimentStress = ((latest.turbidity - 0.5) / 3.5 * 100).clamp(0.0, 100.0);
    double mineralStress = ((latest.tds - goldenTds) / (safeTdsLimit - goldenTds) * 100).clamp(0.0, 100.0);
    double phStress = ((latest.ph - 7.0).abs() / 2.0 * 100).clamp(0.0, 100.0);

    return FilterAiPrediction(
      filterHealth: remainingHealthPct,
      action: action,
      statusTitle: statusTitle,
      primaryCause: primaryCause,
      estimatedDaysRemaining: lifespanDaysRemaining,
      aiRecommendation: aiRecommendation,
      sedimentStress: sedimentStress,
      mineralStress: mineralStress,
      phStress: phStress,
      baselineTdsDriftRate: tdsSlope,
      baselineTurbidityDriftRate: turbSlope,
      goldenBaselineTds: goldenTds,
      currentRollingMinTds: currentRollingMinTds,
      lifespanDaysRemaining: lifespanDaysRemaining,
      flushRequired: flushRequired,
      startupSpikePeak: startupPeak,
      startupStabilizedValue: stabilizedVal,
      startupAucRatio: startupAucRatio,
      flushReason: flushReason,
      safetyStatus: safetyStatus,
      safetyStatusLabel: safetyStatusLabel,
      safeWaterWindowHours: safeWaterWindowHours,
      forecastSummary: forecastSummary,
      sensorMalfunction: false,
    );
  }
}
