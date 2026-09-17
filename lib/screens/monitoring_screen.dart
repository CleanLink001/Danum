import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/water_quality.dart';
import '../services/simulation_service.dart';
import '../services/settings_service.dart';
import '../utils/ui_helpers.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _showPh = true;
  bool _showTds = true;
  bool _showTurb = true;
  bool _showGraphs = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulationService = Provider.of<SimulationService>(context);
    final settings = Provider.of<SettingsService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(settings.translate('real_time_monitor')),
            const SizedBox(width: 10),
            _buildLiveIndicator(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF0284C7)),
            onPressed: () => UIHelpers.showScoreExplanation(context),
            tooltip: 'Explain Water Quality Score',
          ),
          IconButton(
            icon: Icon(_showGraphs ? Icons.list_alt_rounded : Icons.show_chart_rounded),
            onPressed: () => setState(() => _showGraphs = !_showGraphs),
            tooltip: _showGraphs ? 'View Log Archive' : 'View Analysis',
          ),
        ],
      ),
      body: StreamBuilder<WaterQualityData>(
        stream: simulationService.dataStream,
        builder: (context, snapshot) {
          final history = simulationService.history;
          if (history.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!_showGraphs) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildHistoryTable(context, history),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAdvancedMetricsHeader(history),
                const SizedBox(height: 25),
                _buildComparisonChart(history),
                const SizedBox(height: 30),
                _buildDetailedTrend(
                  settings.translate('ph_trends'),
                  history,
                  (data) => data.ph,
                  Colors.blueAccent,
                  'pH',
                  () => _showMetricDetails(context, simulationService, 'ph'),
                ),
                const SizedBox(height: 25),
                _buildDetailedTrend(
                  settings.translate('tds_trends'),
                  history,
                  (data) => data.tds,
                  Colors.cyanAccent,
                  'ppm',
                  () => _showMetricDetails(context, simulationService, 'tds'),
                ),
                const SizedBox(height: 25),
                _buildDetailedTrend(
                  settings.translate('turb_trends'),
                  history,
                  (data) => data.turbidity,
                  Colors.deepPurpleAccent,
                  'NTU',
                  () => _showMetricDetails(context, simulationService, 'turbidity'),
                ),
              ],
            ),
          );
        },
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
    }
  }

  Widget _buildLiveIndicator() {
    return ScaleTransition(
      scale: Tween(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 4)],
        ),
      ),
    );
  }

  Widget _buildAdvancedMetricsHeader(List<WaterQualityData> history) {
    // Calculate session volatility (simple range)
    double phMin = history.map((e) => e.ph).reduce((a, b) => a < b ? a : b);
    double phMax = history.map((e) => e.ph).reduce((a, b) => a > b ? a : b);
    double tdsAvg = history.map((e) => e.tds).reduce((a, b) => a + b) / history.length;
    double turbMax = history.map((e) => e.turbidity).reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        _buildAdvancedChip('STABILITY', '${(100 - (phMax - phMin) * 20).toStringAsFixed(1)}%', Colors.greenAccent),
        const SizedBox(width: 10),
        _buildAdvancedChip('AVG TDS', '${tdsAvg.toInt()}ppm', Colors.cyanAccent),
        const SizedBox(width: 10),
        _buildAdvancedChip('MAX TURB', turbMax.toStringAsFixed(1), Colors.deepPurpleAccent),
      ],
    );
  }

  Widget _buildAdvancedChip(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? color.withValues(alpha: 0.8) : const Color(0xFF0369A1);
    final valueColor = isDark ? color : const Color(0xFF0F172A);
    final cardBg = isDark ? color.withValues(alpha: 0.08) : Colors.white;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: labelColor, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonChart(List<WaterQualityData> history) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Correlation Analysis', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, size: 16, color: Colors.white38),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showCorrelationInfo(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  if (_showPh)
                    LineChartBarData(
                      spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.ph * 10)).toList(),
                      isCurved: true,
                      color: Colors.blueAccent,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  if (_showTds)
                    LineChartBarData(
                      spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.tds / 5)).toList(),
                      isCurved: true,
                      color: Colors.cyanAccent,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  if (_showTurb)
                    LineChartBarData(
                      spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.turbidity * 10)).toList(),
                      isCurved: true,
                      color: Colors.deepPurpleAccent,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildInteractiveLegend('pH', Colors.blueAccent, _showPh, () => setState(() => _showPh = !_showPh)),
              const SizedBox(width: 15),
              _buildInteractiveLegend('TDS', Colors.cyanAccent, _showTds, () => setState(() => _showTds = !_showTds)),
              const SizedBox(width: 15),
              _buildInteractiveLegend('TURB', Colors.deepPurpleAccent, _showTurb, () => setState(() => _showTurb = !_showTurb)),
            ],
          ),
        ],
      ),
    );
  }

  void _showCorrelationInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Correlation Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text(
              'This chart shows how different water metrics fluctuate together over time. For example, high turbidity often correlates with changes in TDS or pH levels due to suspended particles.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.12),
                  foregroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.3)),
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

  Widget _buildDetailedTrend(String title, List<WaterQualityData> history, double Function(WaterQualityData) getValue, Color color, String unit, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    
    final current = getValue(history.last);
    final previous = history.length > 1 ? getValue(history[history.length - 2]) : current;
    final diff = current - previous;
    final isRising = diff > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Icon(Icons.info_outline_rounded, size: 14, color: color.withValues(alpha: 0.3)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(current.toStringAsFixed(1), style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 5),
                          Text(unit, style: const TextStyle(color: Colors.white24, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isRising ? Colors.redAccent : Colors.greenAccent).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isRising ? Icons.trending_up : Icons.trending_down,
                          color: isRising ? Colors.redAccent : Colors.greenAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          diff.abs().toStringAsFixed(2),
                          style: TextStyle(color: isRising ? Colors.redAccent : Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 80,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), getValue(e.value))).toList(),
                        isCurved: true,
                        color: color,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.05)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveLegend(String label, Color color, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? color.withValues(alpha: 0.2) : Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? color : Colors.white10,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : Colors.white24,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTable(BuildContext context, List<WaterQualityData> history) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final recentLogs = history.reversed.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SENSOR LOG ARCHIVE', style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: recentLogs.map((log) => _buildLogRow(log, isDark)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLogRow(WaterQualityData log, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}', 
                style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('Seq #${log.timestamp.millisecondsSinceEpoch.toString().substring(10)}', 
                style: TextStyle(color: subColor, fontSize: 10)),
            ],
          ),
          Text('${log.ph.toStringAsFixed(1)} pH', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          Text('${log.tds.toInt()} ppm', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          Text('${log.turbidity.toStringAsFixed(1)} NTU', style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          _buildStatusDot(log.status),
        ],
      ),
    );
  }

  Widget _buildStatusDot(String status) {
    Color color = status == 'Good' ? Colors.greenAccent : (status == 'Fair' ? Colors.orangeAccent : Colors.redAccent);
    return Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
