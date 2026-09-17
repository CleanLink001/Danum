import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/water_quality.dart';
import '../models/audit_log.dart';

class PdfService {
  /// Generate and launch native PDF print preview for Telemetry Report
  static Future<void> generateAndPrintReport(
    List<WaterQualityData> logs, 
    String reportTitle, {
    String? filterPeriod,
  }) async {
    final pdf = _buildTelemetryPdf(logs, reportTitle, filterPeriod);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Danum_Water_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Download or share Telemetry PDF directly
  static Future<void> downloadOrShareReport(
    List<WaterQualityData> logs, 
    String reportTitle, {
    String? filterPeriod,
  }) async {
    final pdf = _buildTelemetryPdf(logs, reportTitle, filterPeriod);
    final bytes = await pdf.save();
    final filename = 'Danum_Telemetry_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';

    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  /// Generate and launch native PDF print preview for Audit Trail Report
  static Future<void> generateAndPrintAuditTrailReport(
    List<AuditLog> auditLogs,
    String reportTitle, {
    String? filterPeriod,
  }) async {
    final pdf = _buildAuditTrailPdf(auditLogs, reportTitle, filterPeriod);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Danum_Audit_Trail_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Download or share Audit Trail PDF directly
  static Future<void> downloadOrShareAuditTrailReport(
    List<AuditLog> auditLogs,
    String reportTitle, {
    String? filterPeriod,
  }) async {
    final pdf = _buildAuditTrailPdf(auditLogs, reportTitle, filterPeriod);
    final bytes = await pdf.save();
    final filename = 'Danum_Audit_Trail_${DateTime.now().millisecondsSinceEpoch}.pdf';

    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  static pw.Document _buildTelemetryPdf(
    List<WaterQualityData> logs, 
    String reportTitle, 
    String? filterPeriod,
  ) {
    final pdf = pw.Document();

    final safeCount = logs.where((e) => e.isSafe).length;
    final unsafeCount = logs.length - safeCount;
    final complianceRate = logs.isNotEmpty ? (safeCount / logs.length * 100).toStringAsFixed(1) : '0.0';
    final periodLabel = filterPeriod ?? 'Full Telemetry Log';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(reportTitle, periodLabel, 'Water Quality Compliance & Telemetry Report'),
          pw.SizedBox(height: 16),
          _buildKPIOverview(logs, complianceRate, safeCount, unsafeCount),
          pw.SizedBox(height: 16),
          _buildSummaryStats(logs),
          pw.SizedBox(height: 20),
          pw.Text('Telemetry Log Breakdown (${logs.length} Total Records)', 
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 8),
          _buildTelemetryTable(logs),
          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    return pdf;
  }

  static pw.Document _buildAuditTrailPdf(
    List<AuditLog> auditLogs,
    String reportTitle,
    String? filterPeriod,
  ) {
    final pdf = pw.Document();
    final periodLabel = filterPeriod ?? 'Full Audit History';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(reportTitle, periodLabel, 'System Activity & Administrative Audit Trail'),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.blue800, width: 0.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total System Audit Records Recorded:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text('${auditLogs.length} Events', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Audit Event History (${auditLogs.length} Total Records)', 
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 8),
          _buildAuditTrailTable(auditLogs),
          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(String title, String periodLabel, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue800, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('DANUM MONITOR SYSTEM', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(color: PdfColors.blue100, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Period: $periodLabel', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.Text('Exported: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKPIOverview(List<WaterQualityData> logs, String complianceRate, int safeCount, int unsafeCount) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _buildKPICard('Compliance Rate', '$complianceRate%', PdfColors.green800, PdfColors.green50),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _buildKPICard('Safe Readings', '$safeCount', PdfColors.blue800, PdfColors.blue50),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _buildKPICard('Unsafe Alerts', '$unsafeCount', unsafeCount > 0 ? PdfColors.red800 : PdfColors.grey800, unsafeCount > 0 ? PdfColors.red50 : PdfColors.grey100),
        ),
      ],
    );
  }

  static pw.Widget _buildKPICard(String label, String value, PdfColor textColor, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: textColor, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: textColor, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryStats(List<WaterQualityData> logs) {
    if (logs.isEmpty) return pw.SizedBox();
    
    double avgPh = logs.map((e) => e.ph).reduce((a, b) => a + b) / logs.length;
    double avgTds = logs.map((e) => e.tds).reduce((a, b) => a + b) / logs.length;
    double avgTurb = logs.map((e) => e.turbidity).reduce((a, b) => a + b) / logs.length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('AVERAGE pH', avgPh.toStringAsFixed(2), '6.5 - 8.5 Safe'),
          _buildStatBox('AVERAGE TDS', '${avgTds.toInt()} ppm', '< 600 ppm Safe'),
          _buildStatBox('AVERAGE TURBIDITY', '${avgTurb.toStringAsFixed(2)} NTU', '< 5.0 NTU Safe'),
        ],
      ),
    );
  }

  static pw.Widget _buildStatBox(String label, String value, String limit) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.Text('Limit: $limit', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      ],
    );
  }

  static pw.Widget _buildTelemetryTable(List<WaterQualityData> logs) {
    if (logs.isEmpty) {
      return pw.Center(
        child: pw.Text('No sensor data recorded for the selected filter period.', 
          style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
      );
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellHeight: 20,
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.center,
      headers: ['#', 'Date & Time', 'pH', 'TDS (ppm)', 'Turbidity (NTU)', 'Valve', 'Safety Status'],
      data: logs.reversed.take(100).toList().asMap().entries.map((entry) {
        final index = entry.key + 1;
        final log = entry.value;
        final dt = log.timestamp;
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final month = months[dt.month - 1];
        final day = dt.day.toString().padLeft(2, '0');
        final hourInt = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
        final hour = hourInt.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        final second = dt.second.toString().padLeft(2, '0');
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        final formattedTime = '$month $day, ${dt.year} $hour:$minute:$second $amPm';

        return [
          '$index',
          formattedTime,
          log.ph.toStringAsFixed(2),
          log.tds.toInt().toString(),
          log.turbidity.toStringAsFixed(2),
          log.valveOpen ? 'OPEN' : 'CLOSED',
          log.isSafe ? 'SAFE' : 'UNSAFE',
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildAuditTrailTable(List<AuditLog> auditLogs) {
    if (auditLogs.isEmpty) {
      return pw.Center(
        child: pw.Text('No audit log records found for the selected filter period.', 
          style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
      );
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellHeight: 22,
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.center,
      headers: ['#', 'Date & Time', 'Category', 'User', 'Action', 'Details'],
      data: auditLogs.take(100).toList().asMap().entries.map((entry) {
        final index = entry.key + 1;
        final log = entry.value;
        final dt = log.timestamp;
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final month = months[dt.month - 1];
        final day = dt.day.toString().padLeft(2, '0');
        final hourInt = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
        final hour = hourInt.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        final second = dt.second.toString().padLeft(2, '0');
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        final formattedTime = '$month $day, ${dt.year} $hour:$minute:$second $amPm';

        return [
          '$index',
          formattedTime,
          log.category,
          log.userName,
          log.action,
          log.details,
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Danum System - Real-time Water Safety & Audit Logs', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page 1', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }
}
