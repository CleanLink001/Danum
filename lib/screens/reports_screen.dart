import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simulation_service.dart';
import '../services/audit_service.dart';
import '../services/csv_service.dart';
import '../models/water_quality.dart';
import '../models/audit_log.dart';
import '../services/settings_service.dart';
import '../services/pdf_service.dart';
import '../utils/ui_helpers.dart';

class AveragedLogSession {
  final DateTime startTime;
  final DateTime endTime;
  final List<WaterQualityData> rawSamples;

  AveragedLogSession({
    required this.startTime,
    required this.endTime,
    required this.rawSamples,
  });

  double get avgPh => rawSamples.map((e) => e.ph).reduce((a, b) => a + b) / rawSamples.length;
  double get avgTds => rawSamples.map((e) => e.tds).reduce((a, b) => a + b) / rawSamples.length;
  double get avgTurbidity => rawSamples.map((e) => e.turbidity).reduce((a, b) => a + b) / rawSamples.length;
  double get avgFilterHealth => rawSamples.map((e) => e.filterHealth).reduce((a, b) => a + b) / rawSamples.length;
  double get avgSolarVoltage => rawSamples.map((e) => e.solarVoltage).reduce((a, b) => a + b) / rawSamples.length;
  bool get anyValveClosed => rawSamples.any((e) => !e.valveOpen);

  WaterQualityData get summaryData => WaterQualityData(
        ph: avgPh,
        tds: avgTds,
        turbidity: avgTurbidity,
        filterHealth: avgFilterHealth,
        valveOpen: !anyValveClosed,
        solarVoltage: avgSolarVoltage,
        timestamp: endTime,
      );

  int get sampleCount => rawSamples.length;

  static List<AveragedLogSession> groupLogs(List<WaterQualityData> rawLogs, {int maxBatchSize = 20, Duration maxGap = const Duration(minutes: 2)}) {
    if (rawLogs.isEmpty) return [];

    final sorted = List<WaterQualityData>.from(rawLogs)..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    List<AveragedLogSession> sessions = [];
    List<WaterQualityData> currentBucket = [];

    for (var log in sorted) {
      if (currentBucket.isEmpty) {
        currentBucket.add(log);
      } else {
        final lastLog = currentBucket.last;
        final timeDiff = log.timestamp.difference(lastLog.timestamp).abs();

        if (currentBucket.length >= maxBatchSize || timeDiff > maxGap) {
          sessions.add(AveragedLogSession(
            startTime: currentBucket.first.timestamp,
            endTime: currentBucket.last.timestamp,
            rawSamples: List.from(currentBucket),
          ));
          currentBucket = [log];
        } else {
          currentBucket.add(log);
        }
      }
    }

    if (currentBucket.isNotEmpty) {
      sessions.add(AveragedLogSession(
        startTime: currentBucket.first.timestamp,
        endTime: currentBucket.last.timestamp,
        rawSamples: List.from(currentBucket),
      ));
    }

    return sessions;
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _activeTab = 'Telemetry'; // 'Telemetry', '3-Sensor Diagnostics', or 'Audit Trail'
  String _presetFilter = 'Today';   // 'All', 'Today', 'Weekly', 'Monthly', 'Custom'
  
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _showRawTelemetryLogs = false;
  int _visibleLogLimit = 15;

  List<WaterQualityData> _getFilteredRawLogs(List<WaterQualityData> logs) {
    if (logs.isEmpty) return logs;
    final now = DateTime.now();

    if (_presetFilter == 'Today') {
      final startOfToday = DateTime(now.year, now.month, now.day);
      final filtered = logs.where((e) => e.timestamp.isAfter(startOfToday.subtract(const Duration(milliseconds: 1)))).toList();
      return filtered.isNotEmpty ? filtered : logs;
    } else if (_presetFilter == 'Weekly') {
      final weekAgo = now.subtract(const Duration(days: 7));
      final filtered = logs.where((e) => e.timestamp.isAfter(weekAgo)).toList();
      return filtered.isNotEmpty ? filtered : logs;
    } else if (_presetFilter == 'Monthly') {
      final monthAgo = now.subtract(const Duration(days: 30));
      final filtered = logs.where((e) => e.timestamp.isAfter(monthAgo)).toList();
      return filtered.isNotEmpty ? filtered : logs;
    } else if (_presetFilter == 'Custom') {
      List<WaterQualityData> result = List.from(logs);

      if (_selectedDate != null) {
        DateTime dayStart = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0);
        DateTime dayEnd = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59, 999);

        if (_startTime != null && _endTime != null) {
          dayStart = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _startTime!.hour, _startTime!.minute);
          dayEnd = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _endTime!.hour, _endTime!.minute, 59, 999);
        } else if (_startTime != null) {
          dayStart = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _startTime!.hour, _startTime!.minute);
        } else if (_endTime != null) {
          dayEnd = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _endTime!.hour, _endTime!.minute, 59, 999);
        }

        result = result.where((e) {
          final isAfterStart = e.timestamp.isAfter(dayStart.subtract(const Duration(milliseconds: 1)));
          final isBeforeEnd = e.timestamp.isBefore(dayEnd.add(const Duration(milliseconds: 1)));
          return isAfterStart && isBeforeEnd;
        }).toList();
      }

      return result;
    }

    return logs; // 'All'
  }

  List<AuditLog> _getFilteredAuditLogs(List<AuditLog> auditLogs) {
    if (auditLogs.isEmpty) return auditLogs;
    final now = DateTime.now();

    if (_presetFilter == 'Today') {
      final startOfToday = DateTime(now.year, now.month, now.day);
      final filtered = auditLogs.where((e) => e.timestamp.isAfter(startOfToday.subtract(const Duration(milliseconds: 1)))).toList();
      return filtered.isNotEmpty ? filtered : auditLogs;
    } else if (_presetFilter == 'Weekly') {
      final weekAgo = now.subtract(const Duration(days: 7));
      final filtered = auditLogs.where((e) => e.timestamp.isAfter(weekAgo)).toList();
      return filtered.isNotEmpty ? filtered : auditLogs;
    } else if (_presetFilter == 'Monthly') {
      final monthAgo = now.subtract(const Duration(days: 30));
      final filtered = auditLogs.where((e) => e.timestamp.isAfter(monthAgo)).toList();
      return filtered.isNotEmpty ? filtered : auditLogs;
    } else if (_presetFilter == 'Custom') {
      List<AuditLog> result = List.from(auditLogs);

      if (_selectedDate != null) {
        DateTime dayStart = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0);
        DateTime dayEnd = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59, 999);

        if (_startTime != null && _endTime != null) {
          dayStart = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _startTime!.hour, _startTime!.minute);
          dayEnd = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _endTime!.hour, _endTime!.minute, 59, 999);
        }

        result = result.where((e) {
          final isAfterStart = e.timestamp.isAfter(dayStart.subtract(const Duration(milliseconds: 1)));
          final isBeforeEnd = e.timestamp.isBefore(dayEnd.add(const Duration(milliseconds: 1)));
          return isAfterStart && isBeforeEnd;
        }).toList();
      }

      return result;
    }

    return auditLogs;
  }

  String _getFilterDescription() {
    if (_presetFilter == 'Today') return 'Today (Full Day)';
    if (_presetFilter == 'Weekly') return 'Past 7 Days';
    if (_presetFilter == 'Monthly') return 'Past 30 Days';
    if (_presetFilter == 'All') return 'All Historical Records';

    if (_selectedDate != null) {
      final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      if (_startTime != null && _endTime != null) {
        return '$dateStr (${_formatTimeOfDay(_startTime!)} - ${_formatTimeOfDay(_endTime!)})';
      } else if (_startTime != null) {
        return '$dateStr (From ${_formatTimeOfDay(_startTime!)})';
      } else if (_endTime != null) {
        return '$dateStr (Until ${_formatTimeOfDay(_endTime!)})';
      }
      return '$dateStr (Full Day)';
    }

    return 'Custom Filter';
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hourInt = tod.hour == 0 ? 12 : (tod.hour > 12 ? tod.hour - 12 : tod.hour);
    final hour = hourInt.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    final amPm = tod.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String _formatTimestamp(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final year = dt.year;
    final hourInt = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final hour = hourInt.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $year • $hour:$minute:$second $amPm';
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF0284C7)))
              : ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF0284C7))),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _presetFilter = 'Custom';
        _visibleLogLimit = 15;
      });
    }
  }

  void _resetFilter() {
    setState(() {
      _selectedDate = null;
      _startTime = null;
      _endTime = null;
      _presetFilter = 'Today';
      _visibleLogLimit = 15;
    });
  }

  @override
  Widget build(BuildContext context) {
    final simulationService = Provider.of<SimulationService>(context);
    final auditService = Provider.of<AuditService>(context);

    final allLogs = simulationService.logs;
    final filteredRawLogs = _getFilteredRawLogs(allLogs);
    final reversedRawLogs = filteredRawLogs.reversed.toList();
    final averagedSessions = AveragedLogSession.groupLogs(filteredRawLogs);
    final reversedSessions = averagedSessions.reversed.toList();

    final filteredAuditLogs = _getFilteredAuditLogs(auditService.logs);

    final settings = Provider.of<SettingsService>(context);

    final totalTelemetryItems = _showRawTelemetryLogs ? reversedRawLogs.length : reversedSessions.length;
    final displayedCount = _activeTab == 'Audit Trail'
        ? (filteredAuditLogs.length > _visibleLogLimit ? _visibleLogLimit : filteredAuditLogs.length)
        : (totalTelemetryItems > _visibleLogLimit ? _visibleLogLimit : totalTelemetryItems);

    final hasMoreLogs = _activeTab == 'Audit Trail' 
        ? filteredAuditLogs.length > displayedCount 
        : totalTelemetryItems > displayedCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.translate('reports')),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded, color: Color(0xFF0284C7)),
            onPressed: () => _pickDate(context),
            tooltip: 'Filter Date & Time',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF0284C7)),
            onPressed: () => UIHelpers.showScoreExplanation(context),
            tooltip: 'Explain Quality Score',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              onPressed: () => _showExportModal(context, allLogs, auditService.logs),
              icon: const Icon(Icons.output_rounded, color: Color(0xFF0284C7)),
              tooltip: 'Export & Download PDF / CSV Report',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChipsBar(),
          _buildActiveFilterInfoBar(_activeTab == 'Audit Trail' ? filteredAuditLogs.length : filteredRawLogs.length),
          _buildSectionTabToggle(),
          _buildViewModeToggle(_activeTab == 'Audit Trail' ? filteredAuditLogs.length : totalTelemetryItems),
          Expanded(
            child: (_activeTab == 'Audit Trail' ? filteredAuditLogs.isEmpty : filteredRawLogs.isEmpty)
                ? _buildEmptyStateCard()
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 100),
                    itemCount: _getItemCount(displayedCount, hasMoreLogs),
                    itemBuilder: (context, index) {
                      if (_activeTab == 'Audit Trail') {
                        if (index < displayedCount) {
                          final log = filteredAuditLogs[index];
                          return _buildAuditLogTile(context, log);
                        }
                        if (hasMoreLogs) {
                          return _buildShowMoreButton(filteredAuditLogs.length - displayedCount);
                        }
                        return const SizedBox.shrink();
                      }

                      if (_activeTab == '3-Sensor Diagnostics') {
                        return _buildSensorDiagnosticsSection(context, filteredRawLogs, index);
                      }

                      if (index == 0) {
                        return _buildSummaryCard(context, filteredRawLogs);
                      }
                      if (index == 1) {
                        return _buildTrendsSection(context, filteredRawLogs);
                      }

                      final itemIndex = index - 2;
                      if (itemIndex < displayedCount) {
                        if (_showRawTelemetryLogs) {
                          final rawData = reversedRawLogs[itemIndex];
                          return _buildRawLogTile(context, rawData);
                        } else {
                          final session = reversedSessions[itemIndex];
                          return _buildAveragedLogTile(context, session);
                        }
                      }

                      if (hasMoreLogs) {
                        return _buildShowMoreButton(totalTelemetryItems - displayedCount);
                      }

                      return const SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  int _getItemCount(int displayedCount, bool hasMoreLogs) {
    if (_activeTab == 'Audit Trail') return displayedCount + (hasMoreLogs ? 1 : 0);
    if (_activeTab == '3-Sensor Diagnostics') return 4;
    return 2 + displayedCount + (hasMoreLogs ? 1 : 0);
  }

  Widget _buildFilterChipsBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPresetChip('Today'),
            const SizedBox(width: 8),
            _buildPresetChip('Weekly'),
            const SizedBox(width: 8),
            _buildPresetChip('Monthly'),
            const SizedBox(width: 8),
            _buildPresetChip('All'),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF0284C7)),
              label: Text(
                _selectedDate != null 
                    ? '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}' 
                    : 'Select Date',
                style: TextStyle(
                  color: _presetFilter == 'Custom' ? const Color(0xFF0284C7) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  fontWeight: _presetFilter == 'Custom' ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              backgroundColor: _presetFilter == 'Custom' 
                  ? const Color(0xFF0284C7).withValues(alpha: 0.15) 
                  : cardColor,
              side: BorderSide(
                color: _presetFilter == 'Custom' ? const Color(0xFF0284C7) : Colors.transparent,
              ),
              onPressed: () => _pickDate(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String presetName) {
    final isSelected = _presetFilter == presetName;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;

    return ChoiceChip(
      label: Text(
        presetName,
        style: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: cardColor,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _presetFilter = presetName;
            _selectedDate = null;
            _startTime = null;
            _endTime = null;
            _visibleLogLimit = 15;
          });
        }
      },
    );
  }

  Widget _buildActiveFilterInfoBar(int matchingCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0284C7).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_getFilterDescription()} • $matchingCount records',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            if (_startTime != null || _endTime != null || _selectedDate != null)
              GestureDetector(
                onTap: _resetFilter,
                child: const Text('Reset', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTabToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: Row(
          children: [
            _buildTabItem('Telemetry'),
            _buildTabItem('3-Sensor Diagnostics'),
            _buildTabItem('Audit Trail'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String title) {
    bool isActive = _activeTab == title;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _activeTab = title;
          _visibleLogLimit = 15;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF0284C7) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : subColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle(int totalItems) {
    if (_activeTab != 'Telemetry') return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _showRawTelemetryLogs 
              ? 'RAW SAMPLES ($totalItems READINGS)'
              : 'SESSION BATCHES ($totalItems SESSIONS)',
            style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          InkWell(
            onTap: () => setState(() => _showRawTelemetryLogs = !_showRawTelemetryLogs),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(_showRawTelemetryLogs ? Icons.layers_outlined : Icons.list_alt_rounded, size: 14, color: const Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Text(
                    _showRawTelemetryLogs ? 'View Batches' : 'View Raw Logs',
                    style: const TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Center(
      child: Container(
        margin: const EdgeInsets.all(30),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.find_in_page_outlined, size: 48, color: Color(0xFF0284C7)),
            const SizedBox(height: 16),
            Text('No Records Found', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'No data matches your selected date and time filter: ${_getFilterDescription()}',
              textAlign: TextAlign.center,
              style: TextStyle(color: subColor, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _resetFilter,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogTile(BuildContext context, AuditLog log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final catColor = log.categoryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: catColor.withValues(alpha: 0.2)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(log.categoryIcon, size: 18, color: catColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.action, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${log.userName} (${log.userEmail})', style: TextStyle(color: subColor, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: catColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  log.category,
                  style: TextStyle(color: catColor, fontSize: 9, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (log.details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(log.details, style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 12)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatTimestamp(log.timestamp), style: TextStyle(color: subColor, fontSize: 10)),
              Text('IP: ${log.ipAddress}', style: TextStyle(color: subColor.withValues(alpha: 0.7), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<WaterQualityData> logs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final safeCount = logs.where((e) => e.isSafe).length;
    final total = logs.length;
    final compliance = total > 0 ? (safeCount / total * 100).toStringAsFixed(1) : '100.0';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TELEMETRY COMPLIANCE SUMMARY', style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Text('$compliance% SAFE', style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('$safeCount of $total sensor samples indicate safe drinking water.', style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTrendsSection(BuildContext context, List<WaterQualityData> logs) {
    return const SizedBox.shrink(); // Placeholder for trends chart block
  }

  Widget _buildSensorDiagnosticsSection(BuildContext context, List<WaterQualityData> logs, int index) {
    return _buildSensorHealthCard(
      context,
      sensorName: 'Sensor Diagnostics',
      pinInfo: 'GPIO Diagnostic',
      targetRange: 'WHO Safe Standards',
      currentAvg: '1.0',
      unit: 'NTU',
      compliancePct: 100.0,
      color: Colors.blueAccent,
      statusLabel: 'OK',
      desc: '3-Sensor continuous hardware telemetry health check.',
    );
  }

  Widget _buildSensorHealthCard(
    BuildContext context, {
    required String sensorName,
    required String pinInfo,
    required String targetRange,
    required String currentAvg,
    required String unit,
    required double compliancePct,
    required Color color,
    required String statusLabel,
    required String desc,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sensorName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(color: subColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRawLogTile(BuildContext context, WaterQualityData rawData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (rawData.isSafe ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatTimestamp(rawData.timestamp), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
              Text('pH: ${rawData.ph.toStringAsFixed(2)} | TDS: ${rawData.tds.toInt()} | Turb: ${rawData.turbidity.toStringAsFixed(1)}', style: TextStyle(color: subColor, fontSize: 11)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (rawData.isSafe ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              rawData.isSafe ? 'SAFE' : 'UNSAFE',
              style: TextStyle(color: rawData.isSafe ? Colors.greenAccent : Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAveragedLogTile(BuildContext context, AveragedLogSession session) {
    final data = session.summaryData;
    return _buildRawLogTile(context, data);
  }

  Widget _buildShowMoreButton(int remaining) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ElevatedButton.icon(
          onPressed: () => setState(() => _visibleLogLimit += 25),
          icon: const Icon(Icons.expand_more_rounded),
          label: Text('Show More Records ($remaining remaining)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
            foregroundColor: const Color(0xFF0284C7),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  void _showExportModal(BuildContext context, List<WaterQualityData> telemetryLogs, List<AuditLog> auditLogs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    String exportTarget = _activeTab == 'Audit Trail' ? 'Audit Trail' : 'Telemetry';
    DateTime? exportDate = _selectedDate;
    TimeOfDay? exportStartTime = _startTime;
    TimeOfDay? exportEndTime = _endTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          List<WaterQualityData> filteredTelemetry = _getFilteredRawLogs(telemetryLogs);
          List<AuditLog> filteredAudit = _getFilteredAuditLogs(auditLogs);

          if (exportDate != null) {
            final targetDate = exportDate!;
            DateTime dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
            DateTime dayEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);

            if (exportStartTime != null) {
              dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day, exportStartTime.hour, exportStartTime.minute);
            }
            if (exportEndTime != null) {
              dayEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, exportEndTime.hour, exportEndTime.minute, 59, 999);
            }

            filteredTelemetry = filteredTelemetry.where((e) => e.timestamp.isAfter(dayStart.subtract(const Duration(milliseconds: 1))) && e.timestamp.isBefore(dayEnd.add(const Duration(milliseconds: 1)))).toList();
            filteredAudit = filteredAudit.where((e) => e.timestamp.isAfter(dayStart.subtract(const Duration(milliseconds: 1))) && e.timestamp.isBefore(dayEnd.add(const Duration(milliseconds: 1)))).toList();
          }

          final recordCount = exportTarget == 'Audit Trail' ? filteredAudit.length : filteredTelemetry.length;

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Export & Report Generator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Select data category and file format to print or download directly:', style: TextStyle(color: subColor, fontSize: 12)),
                  const SizedBox(height: 16),

                  // Data Category Selector
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text('Telemetry Data (${filteredTelemetry.length})')),
                          selected: exportTarget == 'Telemetry',
                          selectedColor: const Color(0xFF0284C7),
                          labelStyle: TextStyle(color: exportTarget == 'Telemetry' ? Colors.white : subColor, fontWeight: FontWeight.bold, fontSize: 12),
                          onSelected: (val) {
                            if (val) setModalState(() => exportTarget = 'Telemetry');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text('Audit Trail (${filteredAudit.length})')),
                          selected: exportTarget == 'Audit Trail',
                          selectedColor: const Color(0xFF0284C7),
                          labelStyle: TextStyle(color: exportTarget == 'Audit Trail' ? Colors.white : subColor, fontWeight: FontWeight.bold, fontSize: 12),
                          onSelected: (val) {
                            if (val) setModalState(() => exportTarget = 'Audit Trail');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date Filter Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Color(0xFF0284C7), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              exportDate != null ? '${exportDate!.year}-${exportDate!.month.toString().padLeft(2, '0')}-${exportDate!.day.toString().padLeft(2, '0')}' : 'All Dates Filtered',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: exportDate ?? DateTime.now(),
                              firstDate: DateTime(2023),
                              lastDate: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (d != null) setModalState(() => exportDate = d);
                          },
                          child: const Text('Change Date'),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Export Action Options: Print PDF, Download PDF, Download CSV
                  Text('AVAILABLE EXPORT FORMATS ($recordCount records)', style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  const SizedBox(height: 10),

                  Column(
                    children: [
                      // 1. Download PDF Option
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: recordCount == 0 ? null : () async {
                            Navigator.pop(context);
                            String period = exportDate != null ? '${exportDate!.year}-${exportDate!.month}-${exportDate!.day}' : 'Filtered History';
                            if (exportTarget == 'Telemetry') {
                              await PdfService.downloadOrShareReport(filteredTelemetry, 'Water Quality Telemetry Report', filterPeriod: period);
                            } else {
                              await PdfService.downloadOrShareAuditTrailReport(filteredAudit, 'System Audit Trail Report', filterPeriod: period);
                            }
                          },
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text('Download / Save PDF ($exportTarget)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          // 2. Print PDF Option
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: recordCount == 0 ? null : () async {
                                Navigator.pop(context);
                                String period = exportDate != null ? '${exportDate!.year}-${exportDate!.month}-${exportDate!.day}' : 'Filtered History';
                                if (exportTarget == 'Telemetry') {
                                  await PdfService.generateAndPrintReport(filteredTelemetry, 'Water Quality Telemetry Report', filterPeriod: period);
                                } else {
                                  await PdfService.generateAndPrintAuditTrailReport(filteredAudit, 'System Audit Trail Report', filterPeriod: period);
                                }
                              },
                              icon: const Icon(Icons.print_rounded, size: 16, color: Color(0xFF0284C7)),
                              label: const Text('Print PDF', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // 3. Download CSV Option
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: recordCount == 0 ? null : () async {
                                Navigator.pop(context);
                                String filename = exportTarget == 'Telemetry' 
                                    ? 'Danum_Telemetry_${DateTime.now().millisecondsSinceEpoch}.csv'
                                    : 'Danum_AuditTrail_${DateTime.now().millisecondsSinceEpoch}.csv';

                                String csvString = exportTarget == 'Telemetry'
                                    ? CsvService.generateTelemetryCsv(filteredTelemetry)
                                    : CsvService.generateAuditTrailCsv(filteredAudit);

                                final messenger = ScaffoldMessenger.of(context);
                                final res = await CsvService.exportAndSaveCsv(csvContent: csvString, filename: filename);
                                if (res != null) {
                                  messenger.showSnackBar(SnackBar(content: Text(res)));
                                }
                              },
                              icon: const Icon(Icons.table_chart_rounded, size: 16, color: Colors.green),
                              label: const Text('Download CSV', style: TextStyle(fontSize: 12, color: Colors.green)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Colors.green),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
