import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/water_quality.dart';
import '../services/simulation_service.dart';
import '../services/settings_service.dart';
import '../services/ai_filter_predictor.dart';
import '../widgets/status_card.dart';
import '../widgets/overall_status.dart';
import '../utils/ui_helpers.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final simulationService = Provider.of<SimulationService>(context);
    final settings = Provider.of<SettingsService>(context);

    final WaterQualityData? initialWaterData = 
        simulationService.history.isNotEmpty ? simulationService.history.last : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('DANUM ${settings.translate('monitor')}'),
        actions: [
          StreamBuilder<WaterQualityData>(
            stream: simulationService.dataStream,
            initialData: initialWaterData,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final hasAlerts = data != null && _getActiveAlerts(data).isNotEmpty;
              
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      hasAlerts ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      color: hasAlerts ? Colors.orangeAccent : null,
                    ),
                    onPressed: () => _showNotificationCenter(context, simulationService),
                  ),
                  if (hasAlerts)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<WaterQualityData>(
        stream: simulationService.dataStream,
        initialData: initialWaterData,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF22D3EE)),
                  const SizedBox(height: 16),
                  Text(
                    settings.isSimulationMode 
                      ? 'Initializing Local Stream...' 
                      : 'Connecting to Firebase Realtime Database...',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final history = simulationService.history;
          final prediction = FilterAiPrediction.analyze(history.isNotEmpty ? history : [data]);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Overall Water Quality Score Card
                OverallStatus(
                  data: data,
                  onTap: () => _showMetricDetails(context, simulationService, 'score'),
                ),
                const SizedBox(height: 20),

                // 2. Connectivity & 3-Sensor Status Header Chips
                Row(
                  children: [
                    Expanded(
                      child: _buildHeaderChip(
                        context,
                        settings.translate('cloud_status'),
                        settings.isSimulationMode ? 'SIMULATED' : 'FIREBASE LIVE',
                        settings.isSimulationMode ? const Color(0xFF818CF8) : const Color(0xFF10B981),
                        Icons.cloud_done_rounded,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildHeaderChip(
                        context,
                        settings.translate('system_status'),
                        'pH • TDS • NTU',
                        const Color(0xFF06B6D4),
                        Icons.sensors_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // 3. Current Live Sensor Metrics (3 Sensors with Plain Language Subtitles)
                Text(
                  settings.translate('current_metrics'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    StatusCard(
                      title: 'pH Level',
                      value: data.ph.toStringAsFixed(1),
                      unit: 'pH',
                      subtitle: settings.translate('ph_sub'),
                      icon: Icons.science_rounded,
                      color: Colors.blueAccent,
                      onTap: () => _showMetricDetails(context, simulationService, 'ph'),
                    ),
                    StatusCard(
                      title: 'TDS',
                      value: data.tds.toStringAsFixed(0),
                      unit: 'ppm',
                      subtitle: settings.translate('tds_sub'),
                      icon: Icons.water_drop_rounded,
                      color: Colors.cyanAccent,
                      onTap: () => _showMetricDetails(context, simulationService, 'tds'),
                    ),
                    StatusCard(
                      title: 'Turbidity',
                      value: data.turbidity.toStringAsFixed(1),
                      unit: 'NTU',
                      subtitle: settings.translate('turb_sub'),
                      icon: Icons.opacity_rounded,
                      color: Colors.deepPurpleAccent,
                      onTap: () => _showMetricDetails(context, simulationService, 'turbidity'),
                    ),
                    StatusCard(
                      title: 'Filter Health',
                      value: '${prediction.filterHealth.toStringAsFixed(0)}%',
                      unit: 'Life',
                      subtitle: prediction.filterHealth > 50 ? 'Optimal' : 'Attention',
                      icon: Icons.filter_alt_rounded,
                      color: prediction.filterHealth > 50 ? const Color(0xFF10B981) : Colors.orangeAccent,
                      onTap: () => _showMetricDetails(context, simulationService, 'score'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. Solenoid Valve Control Switch Card
                _buildSolenoidValveControlCard(context, data, simulationService),
                const SizedBox(height: 25),

                // 5. AI Filter Degradation & Flushing Predictor
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      settings.translate('ai_predictor_title'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0284C7), letterSpacing: 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF0284C7), size: 20),
                      onPressed: () => UIHelpers.showScoreExplanation(context),
                      tooltip: 'Explain Water Quality Score',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildAiFilterPredictorCard(context, prediction, settings),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSolenoidValveControlCard(BuildContext context, WaterQualityData data, SimulationService simulationService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final bool isOpen = data.valveOpen;
    final bool isSafe = data.isSafe;
    final bool isManual = simulationService.manualValveOverride;

    final Color statusColor = isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final String statusText = isOpen ? 'VALVE OPEN (Flow Active)' : 'VALVE CLOSED (Water Shut-off)';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOpen ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SOLENOID VALVE',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            isManual
                                ? 'Manual Override Active'
                                : (isSafe ? 'Auto-Cutoff Active (Safe)' : 'Auto-Shutoff (Unsafe Water)'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isManual ? Colors.orangeAccent : (isSafe ? subColor : const Color(0xFFEF4444)),
                              fontSize: 11,
                              fontWeight: isManual || !isSafe ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOpen,
                activeThumbColor: const Color(0xFF10B981),
                inactiveThumbColor: const Color(0xFFEF4444),
                onChanged: (bool newValue) {
                  if (newValue == true && !isSafe) {
                    _showUnsafeWaterWarningDialog(context, data, simulationService);
                  } else {
                    simulationService.setValveState(newValue);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  isOpen ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: statusColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (isManual)
                  TextButton(
                    onPressed: () => simulationService.disableValveOverride(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'RESUME AUTO',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUnsafeWaterWarningDialog(BuildContext context, WaterQualityData data, SimulationService simulationService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'UNSAFE WATER WARNING',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The system detected that the water is currently NOT safe to consume:',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    _buildMetricRow('pH Level', data.ph.toStringAsFixed(1), data.ph >= 6.5 && data.ph <= 8.5),
                    _buildMetricRow('TDS Level', '${data.tds.toStringAsFixed(0)} ppm', data.tds <= 600),
                    _buildMetricRow('Turbidity', '${data.turbidity.toStringAsFixed(1)} NTU', data.turbidity <= 5),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Opening the valve will allow unsafe water to flow. Are you sure you want to force open the valve?',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                simulationService.setValveState(true);
              },
              child: const Text('FORCE OPEN VALVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricRow(String label, String value, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          Row(
            children: [
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isOk ? Colors.greenAccent : Colors.redAccent)),
              const SizedBox(width: 4),
              Icon(isOk ? Icons.check_circle_outline : Icons.error_outline, size: 14, color: isOk ? Colors.greenAccent : Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiFilterPredictorCard(BuildContext context, FilterAiPrediction prediction, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final innerBg = isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF1F5F9);
    final innerBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    Color statusColor;
    IconData statusIcon;

    switch (prediction.action) {
      case FilterMaintenanceAction.needsFlushing:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.cleaning_services_rounded;
        break;
      case FilterMaintenanceAction.needsReplacement:
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.warning_amber_rounded;
        break;
      case FilterMaintenanceAction.optimal:
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.verified_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Status Badge & Estimated Days
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          prediction.statusTitle,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${prediction.estimatedDaysRemaining} Days',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  Text(
                    'Est. Remaining',
                    style: TextStyle(color: subColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter Health Gauge Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter Media Health', style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('${prediction.filterHealth.toStringAsFixed(0)}%', style: TextStyle(color: statusColor, fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: prediction.filterHealth / 100.0,
              minHeight: 10,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 20),

          // 3 Physics-Informed AI Model Insights Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: innerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Model 1: Filter Lifespan (Baseline Drift)
                Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, color: Color(0xFF0284C7), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Baseline Drift: ${prediction.baselineTdsDriftRate > 0 ? "+${prediction.baselineTdsDriftRate.toStringAsFixed(1)}" : "0.0"} ppm/day drift',
                        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${prediction.lifespanDaysRemaining}d remaining',
                      style: const TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Model 2: Flush Trigger Binary Output
                Row(
                  children: [
                    Icon(
                      prediction.flushRequired ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                      color: prediction.flushRequired ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Flush Trigger: ${prediction.flushRequired ? "REQUIRED IMMEDIATELY" : "STATUS OPTIMAL"}',
                        style: TextStyle(
                          color: prediction.flushRequired ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      'Spike: ${prediction.startupSpikePeak.toStringAsFixed(1)} NTU',
                      style: TextStyle(color: subColor, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Model 3: Water Safety Forecasting (12-24h Horizon)
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFF0284C7), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Safety Forecast: ${prediction.safetyStatusLabel}',
                        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${prediction.safeWaterWindowHours.toStringAsFixed(0)}h Window',
                        style: const TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // AI Diagnosed Primary Cause & Recommendation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: innerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_rounded, color: Color(0xFF0284C7), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Diagnosis: ${prediction.primaryCause}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  prediction.aiRecommendation,
                  style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                ),
                if (prediction.forecastSummary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Forecast: ${prediction.forecastSummary}',
                    style: TextStyle(color: subColor, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3-Sensor Clogging & Stress Breakdown
          Text('3-SENSOR CLOGGING STRESS BREAKDOWN', style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 12),
          _buildStressBar(context, 'Turbidity Sediment Stress', prediction.sedimentStress, Colors.deepPurpleAccent),
          const SizedBox(height: 8),
          _buildStressBar(context, 'TDS Mineral Scaling Stress', prediction.mineralStress, Colors.cyanAccent),
          const SizedBox(height: 8),
          _buildStressBar(context, 'pH Chemical Stress', prediction.phStress, Colors.blueAccent),

          const SizedBox(height: 20),
          // Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showFlushingGuide(context, prediction, settings),
              icon: const Icon(Icons.build_rounded, size: 18),
              label: Text(
                settings.translate('view_flush_guide'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor.withValues(alpha: 0.15),
                foregroundColor: statusColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStressBar(BuildContext context, String label, double stressValue, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600)),
            Text('${stressValue.toInt()}% Stress', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: stressValue / 100.0,
            minHeight: 5,
            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  void _showFlushingGuide(BuildContext context, FilterAiPrediction prediction, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.cleaning_services_rounded, color: Color(0xFF0284C7), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(settings.translate('guide_title'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
                      Text('Simple 4-step maintenance process', style: TextStyle(fontSize: 12, color: subColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildGuideStep(context, '1', 'Turn Off Main Water', 'Shut off the main water valve going into your ESP32 Danum monitoring unit.'),
                  _buildGuideStep(context, '2', 'Open Reverse Flushing Valve', 'Open the flush tap or reverse valve for 2 minutes to wash away trapped mud and dirt.'),
                  _buildGuideStep(context, '3', 'Check Screen Turbidity (NTU)', 'Observe your LCD screen or phone screen. NTU clarity should drop below 1.5 NTU.'),
                  _buildGuideStep(context, '4', 'Resume Fresh Water Flow', 'Close the flush valve and turn back on the main water supply for clean drinking water.'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Text('GOT IT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(BuildContext context, String stepNumber, String title, String description) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(stepNumber, style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(color: subColor, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMetricDetails(BuildContext context, SimulationService simulationService, String metricType) {
    final data = simulationService.history.isNotEmpty
        ? simulationService.history.last
        : WaterQualityData(
            ph: 7.2,
            tds: 145.0,
            turbidity: 1.2,
            filterHealth: 98.0,
            valveOpen: true,
            solarVoltage: 12.8,
            timestamp: DateTime.now(),
          );

    switch (metricType) {
      case 'ph':
        UIHelpers.showMetricDetails(
          context, 
          'pH Level', 
          data.ph.toStringAsFixed(1), 
          'pH', 
          data.ph >= 6.5 && data.ph <= 8.5, 
          'The safe range for drinking water is between 6.5 and 8.5. pH levels outside this range can indicate chemical contamination or lead to pipe corrosion.', 
          '6.5 - 8.5 pH', 
          Colors.blueAccent
        );
        break;
      case 'tds':
        UIHelpers.showMetricDetails(
          context, 
          'Total Dissolved Solids', 
          data.tds.toStringAsFixed(0), 
          'ppm', 
          data.tds <= 600, 
          'TDS represents the amount of minerals, salts, or metals dissolved in water. Levels below 600 ppm are generally considered safe and palatable.', 
          '< 600 ppm', 
          Colors.cyanAccent
        );
        break;
      case 'turbidity':
        UIHelpers.showMetricDetails(
          context, 
          'Turbidity', 
          data.turbidity.toStringAsFixed(1), 
          'NTU', 
          data.turbidity <= 5, 
          'Turbidity measures the cloudiness of water. High turbidity can protect bacteria from disinfection and often indicates high particle content.', 
          '< 5 NTU', 
          Colors.deepPurpleAccent
        );
        break;
      case 'score':
        UIHelpers.showMetricDetails(
          context, 
          'Water Quality Score', 
          '${data.score}/100', 
          'Score', 
          data.isSafe, 
          'Overall water safety score computed dynamically from pH, TDS, and Turbidity 3-sensor telemetry.', 
          '>= 80 Safe', 
          const Color(0xFF10B981)
        );
        break;
    }
  }

  Widget _buildHeaderChip(BuildContext context, String label, String value, Color color, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final subColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: subColor, fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getActiveAlerts(WaterQualityData data) {
    final List<Map<String, dynamic>> alerts = [];
    
    if (data.ph < 6.5) {
      alerts.add({
        'title': 'Acidic pH Level',
        'body': 'pH is ${data.ph.toStringAsFixed(1)} (Too Acidic). Water may be corrosive and metallic.',
        'severity': 'critical',
        'icon': Icons.science_rounded,
        'color': Colors.redAccent,
      });
    } else if (data.ph > 8.5) {
      alerts.add({
        'title': 'Alkaline pH Level',
        'body': 'pH is ${data.ph.toStringAsFixed(1)} (Too Alkaline). High scale-forming/mineral risk.',
        'severity': 'critical',
        'icon': Icons.science_rounded,
        'color': Colors.redAccent,
      });
    }
    
    if (data.tds > 300.0) {
      alerts.add({
        'title': 'High Dissolved Solids (TDS)',
        'body': 'TDS is ${data.tds.toStringAsFixed(0)} ppm. Dissolved mineral particles are elevated.',
        'severity': 'warning',
        'icon': Icons.water_drop_rounded,
        'color': Colors.orangeAccent,
      });
    }
    
    if (data.turbidity > 5.0) {
      alerts.add({
        'title': 'High Water Turbidity',
        'body': 'Turbidity is ${data.turbidity.toStringAsFixed(1)} NTU (Cloudy). Higher sedimentation risk.',
        'severity': 'warning',
        'icon': Icons.opacity_rounded,
        'color': Colors.orangeAccent,
      });
    }
    
    return alerts;
  }

  void _showNotificationCenter(BuildContext context, SimulationService simulationService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StreamBuilder<WaterQualityData>(
        stream: simulationService.dataStream,
        initialData: simulationService.history.isNotEmpty ? simulationService.history.last : null,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final alerts = _getActiveAlerts(data);
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'System Alerts',
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w900, 
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: (alerts.isEmpty ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          alerts.isEmpty ? 'NOMINAL' : '${alerts.length} ACTIVE',
                          style: TextStyle(
                            color: alerts.isEmpty ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: alerts.isEmpty
                    ? _buildEmptyAlertsState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: alerts.length,
                        itemBuilder: (context, index) {
                          final alert = alerts[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: alert['color'].withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      color: alert['color'],
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: alert['color'].withValues(alpha: 0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(alert['icon'], color: alert['color'], size: 20),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    alert['title'],
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    alert['body'],
                                                    style: const TextStyle(
                                                      color: Colors.white60,
                                                      fontSize: 13,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyAlertsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.greenAccent,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'All Systems Nominal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No active alerts. All 3 sensor metrics match standard healthy drinking conditions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
