import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/water_quality.dart';
import '../services/simulation_service.dart';
import '../services/settings_service.dart';
import '../services/audit_service.dart';
import '../services/auth_service.dart';
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'web/icons/Icon-Danum.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.water_drop_rounded, size: 24, color: Color(0xFF0284C7)),
                ),
              ),
            ),
            Text('${settings.translate('danum_title')} ${settings.translate('monitor')}'),
          ],
        ),
        actions: [
          StreamBuilder<WaterQualityData>(
            stream: simulationService.dataStream,
            initialData: initialWaterData,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final hasAlerts = data != null && _getActiveAlerts(data, settings).isNotEmpty;
              
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      hasAlerts ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      color: hasAlerts ? Colors.orangeAccent : null,
                    ),
                    onPressed: () => _showNotificationCenter(context, simulationService, settings),
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
                      ? settings.translate('init_local_stream') 
                      : settings.translate('connecting_firebase'),
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
                  onTap: () => _showMetricDetails(context, simulationService, 'score', settings),
                ),
                const SizedBox(height: 20),

                // 2. Connectivity & 3-Sensor Status Header Chips
                Row(
                  children: [
                    Expanded(
                      child: _buildHeaderChip(
                        context,
                        settings.translate('cloud_status'),
                        settings.isSimulationMode ? settings.translate('simulated') : settings.translate('firebase_live'),
                        settings.isSimulationMode ? const Color(0xFF818CF8) : const Color(0xFF10B981),
                        Icons.cloud_done_rounded,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildHeaderChip(
                        context,
                        settings.translate('system_status'),
                        settings.translate('sensors_chip_subtitle'),
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
                      title: settings.translate('ph_level'),
                      value: data.ph.toStringAsFixed(1),
                      unit: 'pH',
                      subtitle: settings.translate('ph_sub'),
                      icon: Icons.science_rounded,
                      color: Colors.blueAccent,
                      onTap: () => _showMetricDetails(context, simulationService, 'ph', settings),
                    ),
                    StatusCard(
                      title: settings.translate('tds'),
                      value: data.tds.toStringAsFixed(0),
                      unit: 'ppm',
                      subtitle: settings.translate('tds_sub'),
                      icon: Icons.water_drop_rounded,
                      color: Colors.cyanAccent,
                      onTap: () => _showMetricDetails(context, simulationService, 'tds', settings),
                    ),
                    StatusCard(
                      title: settings.translate('turbidity'),
                      value: data.turbidity.toStringAsFixed(1),
                      unit: 'NTU',
                      subtitle: settings.translate('turb_sub'),
                      icon: Icons.opacity_rounded,
                      color: Colors.deepPurpleAccent,
                      onTap: () => _showMetricDetails(context, simulationService, 'turbidity', settings),
                    ),
                    StatusCard(
                      title: settings.translate('filter_health'),
                      value: '${prediction.filterHealth.toStringAsFixed(0)}%',
                      unit: settings.translate('life_unit'),
                      subtitle: prediction.filterHealth > 50 ? settings.translate('optimal') : settings.translate('attention'),
                      icon: Icons.filter_alt_rounded,
                      color: prediction.filterHealth > 50 ? const Color(0xFF10B981) : Colors.orangeAccent,
                      onTap: () => _showMetricDetails(context, simulationService, 'score', settings),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. Solenoid Valve Control Switch Card
                _buildSolenoidValveControlCard(context, data, simulationService, settings),
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
                      tooltip: settings.translate('tooltip_score_exp'),
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

  Widget _buildSolenoidValveControlCard(BuildContext context, WaterQualityData data, SimulationService simulationService, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final bool isOpen = data.valveOpen;
    final bool isSafe = data.isSafe;
    final bool isManual = simulationService.manualValveOverride;

    final Color statusColor = isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final String statusText = isOpen ? settings.translate('valve_open') : settings.translate('valve_closed');

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
                            settings.translate('solenoid_valve'),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            isManual
                                ? settings.translate('manual_override_active')
                                : (isSafe ? settings.translate('auto_cutoff_safe') : settings.translate('auto_shutoff_unsafe')),
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
                    _showUnsafeWaterWarningDialog(context, data, simulationService, settings);
                  } else {
                    simulationService.setValveState(newValue);
                    final audit = Provider.of<AuditService>(context, listen: false);
                    final auth = Provider.of<AuthService>(context, listen: false);
                    audit.logEvent(
                      authService: auth,
                      category: 'VALVE_CONTROL',
                      action: newValue ? 'Valve Manually Opened' : 'Valve Manually Closed',
                      details: 'User manually switched solenoid valve ${newValue ? 'OPEN' : 'CLOSED'}',
                    );
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
                    onPressed: () {
                      simulationService.disableValveOverride();
                      final audit = Provider.of<AuditService>(context, listen: false);
                      final auth = Provider.of<AuthService>(context, listen: false);
                      audit.logEvent(
                        authService: auth,
                        category: 'VALVE_CONTROL',
                        action: 'Valve Auto-Safety Resumed',
                        details: 'Manual override deactivated. Restored automatic solenoid safety cutoff.',
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      settings.translate('resume_auto'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUnsafeWaterWarningDialog(BuildContext context, WaterQualityData data, SimulationService simulationService, SettingsService settings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  settings.translate('force_open_warning_title'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.translate('force_open_warning_body'),
                style: const TextStyle(fontSize: 13, height: 1.4),
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
                    _buildMetricRow(settings.translate('ph_level'), data.ph.toStringAsFixed(1), data.ph >= 6.5 && data.ph <= 8.5),
                    _buildMetricRow(settings.translate('tds'), '${data.tds.toStringAsFixed(0)} ppm', data.tds <= 600),
                    _buildMetricRow(settings.translate('turbidity'), '${data.turbidity.toStringAsFixed(1)} NTU', data.turbidity <= 5),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                settings.translate('force_open_warning_confirm'),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(settings.translate('cancel'), style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                simulationService.setValveState(true);
                final audit = Provider.of<AuditService>(context, listen: false);
                final auth = Provider.of<AuthService>(context, listen: false);
                audit.logEvent(
                  authService: auth,
                  category: 'VALVE_CONTROL',
                  action: 'Valve Force-Opened (Unsafe Water)',
                  details: 'User override: Solenoid valve force-opened despite unsafe water (pH: ${data.ph.toStringAsFixed(1)}, TDS: ${data.tds.toStringAsFixed(0)}, Turbidity: ${data.turbidity.toStringAsFixed(1)})',
                );
              },
              child: Text(settings.translate('force_open_confirm_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    '${prediction.estimatedDaysRemaining} ${settings.translate('days_unit')}',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  Text(
                    settings.translate('est_remaining'),
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
              Text(settings.translate('filter_media_health'), style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
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
                        '${settings.translate('baseline_drift_label')}: ${prediction.baselineTdsDriftRate > 0 ? "+${prediction.baselineTdsDriftRate.toStringAsFixed(1)}" : "0.0"} ${settings.translate('drift_suffix')}',
                        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${prediction.lifespanDaysRemaining}${settings.translate('days_short')} ${settings.translate('remaining_lower')}',
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
                        '${settings.translate('flush_trigger_label')}: ${prediction.flushRequired ? settings.translate('required_immediately') : settings.translate('status_optimal')}',
                        style: TextStyle(
                          color: prediction.flushRequired ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${settings.translate('spike_label')}: ${prediction.startupSpikePeak.toStringAsFixed(1)} NTU',
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
                        '${settings.translate('safety_forecast_label')}: ${prediction.safetyStatus == WaterSafetyStatus.safe ? settings.translate('safe') : (prediction.safetyStatus == WaterSafetyStatus.warningDegradingTrend ? settings.translate('moderate_tag') : settings.translate('unsafe'))}',
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
                        '${prediction.safeWaterWindowHours.toStringAsFixed(0)}h ${settings.translate('window_label')}',
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
                        '${settings.translate('ai_diagnosis_label')}: ${prediction.primaryCause}',
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
                    '${settings.translate('forecast_label')}: ${prediction.forecastSummary}',
                    style: TextStyle(color: subColor, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3-Sensor Clogging & Stress Breakdown
          Text(settings.translate('stress_breakdown_title'), style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 12),
          _buildStressBar(context, settings.translate('turbidity_stress_label'), prediction.sedimentStress, Colors.deepPurpleAccent, settings),
          const SizedBox(height: 8),
          _buildStressBar(context, settings.translate('tds_stress_label'), prediction.mineralStress, Colors.cyanAccent, settings),
          const SizedBox(height: 8),
          _buildStressBar(context, settings.translate('ph_stress_label'), prediction.phStress, Colors.blueAccent, settings),

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

  Widget _buildStressBar(BuildContext context, String label, double stressValue, Color color, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600)),
            Text('${stressValue.toInt()}% ${settings.translate('stress_unit')}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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
                const Icon(Icons.build_circle_rounded, color: Color(0xFF0284C7), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(settings.translate('guide_title'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
                      Text(settings.translate('guide_subtitle'), style: TextStyle(fontSize: 12, color: subColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildGuideStep(context, '1', settings.translate('step1_title'), settings.translate('step1_desc')),
                  _buildGuideStep(context, '2', settings.translate('step2_title'), settings.translate('step2_desc')),
                  _buildGuideStep(context, '3', settings.translate('step3_title'), settings.translate('step3_desc')),
                  _buildGuideStep(context, '4', settings.translate('step4_title'), settings.translate('step4_desc')),
                  _buildGuideStep(context, '5', settings.translate('step5_title'), settings.translate('step5_desc')),
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settings.translate('important_note'),
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                settings.translate('flushing_note_desc'),
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text(settings.translate('got_it'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  void _showMetricDetails(BuildContext context, SimulationService simulationService, String metricType, SettingsService settings) {
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
          settings.translate('ph_level'), 
          data.ph.toStringAsFixed(1), 
          'pH', 
          data.ph >= 6.5 && data.ph <= 8.5, 
          settings.translate('ph_info'), 
          '6.5 - 8.5 pH', 
          Colors.blueAccent
        );
        break;
      case 'tds':
        UIHelpers.showMetricDetails(
          context, 
          settings.translate('total_dissolved_solids'), 
          data.tds.toStringAsFixed(0), 
          'ppm', 
          data.tds <= 600, 
          settings.translate('tds_info'), 
          '< 600 ppm', 
          Colors.cyanAccent
        );
        break;
      case 'turbidity':
        UIHelpers.showMetricDetails(
          context, 
          settings.translate('turbidity'), 
          data.turbidity.toStringAsFixed(1), 
          'NTU', 
          data.turbidity <= 5, 
          settings.translate('turb_info'), 
          '< 5 NTU', 
          Colors.deepPurpleAccent
        );
        break;
      case 'score':
        UIHelpers.showMetricDetails(
          context, 
          settings.translate('quality_score_title'), 
          '${data.score}/100', 
          settings.translate('score'), 
          data.isSafe, 
          settings.translate('score_info'), 
          '>= 80 ${settings.translate('safe')}', 
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

  List<Map<String, dynamic>> _getActiveAlerts(WaterQualityData data, SettingsService settings) {
    final List<Map<String, dynamic>> alerts = [];
    
    if (data.ph < 6.5) {
      alerts.add({
        'title': settings.translate('alert_ph_acidic_title'),
        'body': settings.translate('alert_ph_acidic_body', {'value': data.ph.toStringAsFixed(1)}),
        'severity': 'critical',
        'icon': Icons.science_rounded,
        'color': Colors.redAccent,
      });
    } else if (data.ph > 8.5) {
      alerts.add({
        'title': settings.translate('alert_ph_alkaline_title'),
        'body': settings.translate('alert_ph_alkaline_body', {'value': data.ph.toStringAsFixed(1)}),
        'severity': 'critical',
        'icon': Icons.science_rounded,
        'color': Colors.redAccent,
      });
    }
    
    if (data.tds > 300.0) {
      alerts.add({
        'title': settings.translate('alert_tds_high_title'),
        'body': settings.translate('alert_tds_high_body', {'value': data.tds.toStringAsFixed(0)}),
        'severity': 'warning',
        'icon': Icons.water_drop_rounded,
        'color': Colors.orangeAccent,
      });
    }
    
    if (data.turbidity > 5.0) {
      alerts.add({
        'title': settings.translate('alert_turb_high_title'),
        'body': settings.translate('alert_turb_high_body', {'value': data.turbidity.toStringAsFixed(1)}),
        'severity': 'warning',
        'icon': Icons.opacity_rounded,
        'color': Colors.orangeAccent,
      });
    }
    
    return alerts;
  }

  void _showNotificationCenter(BuildContext context, SimulationService simulationService, SettingsService settings) {
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
          final alerts = _getActiveAlerts(data, settings);
          
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
                      Text(
                        settings.translate('system_alerts'),
                        style: const TextStyle(
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
                          alerts.isEmpty ? settings.translate('nominal_chip') : settings.translate('active_chip', {'count': alerts.length.toString()}),
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
                    ? _buildEmptyAlertsState(context, settings)
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

  Widget _buildEmptyAlertsState(BuildContext context, SettingsService settings) {
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
            Text(
              settings.translate('all_systems_nominal'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              settings.translate('no_active_alerts_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(
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
