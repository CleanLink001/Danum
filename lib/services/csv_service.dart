import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../models/water_quality.dart';
import '../models/audit_log.dart';

class CsvService {
  /// Generate CSV string for Water Quality Telemetry logs
  static String generateTelemetryCsv(List<WaterQualityData> logs) {
    final StringBuffer buffer = StringBuffer();
    // Headers
    buffer.writeln('Timestamp,pH Level,TDS (ppm),Turbidity (NTU),Solar Voltage (V),Filter Health (%),Valve Status,Safety Status');

    for (var log in logs) {
      final dt = log.timestamp.toIso8601String().replaceAll('T', ' ').split('.')[0];
      final ph = log.ph.toStringAsFixed(2);
      final tds = log.tds.toInt().toString();
      final turb = log.turbidity.toStringAsFixed(2);
      final solar = log.solarVoltage.toStringAsFixed(2);
      final filter = log.filterHealth.toStringAsFixed(1);
      final valve = log.valveOpen ? 'OPEN' : 'CLOSED';
      final status = log.isSafe ? 'SAFE' : 'UNSAFE';

      buffer.writeln('"$dt",$ph,$tds,$turb,$solar,$filter,"$valve","$status"');
    }

    return buffer.toString();
  }

  /// Generate CSV string for Audit Trail activity logs
  static String generateAuditTrailCsv(List<AuditLog> auditLogs) {
    final StringBuffer buffer = StringBuffer();
    // Headers
    buffer.writeln('ID,Timestamp,User Name,User Email,Category,Action,Details,IP Address');

    for (var log in auditLogs) {
      final id = log.id ?? '';
      final dt = log.timestamp.toIso8601String().replaceAll('T', ' ').split('.')[0];
      final user = log.userName.replaceAll('"', '""');
      final email = log.userEmail.replaceAll('"', '""');
      final category = log.category.replaceAll('"', '""');
      final action = log.action.replaceAll('"', '""');
      final details = log.details.replaceAll('"', '""');
      final ip = log.ipAddress;

      buffer.writeln('$id,"$dt","$user","$email","$category","$action","$details","$ip"');
    }

    return buffer.toString();
  }

  /// Download or share CSV file with user
  static Future<String?> exportAndSaveCsv({
    required String csvContent,
    required String filename,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(csvContent));

    try {
      // 1. Try path_provider local save on mobile/desktop if non-web
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        try {
          Directory? dir;
          if (Platform.isAndroid) {
            dir = Directory('/storage/emulated/0/Download');
            if (!dir.existsSync()) {
              dir = await getExternalStorageDirectory();
            }
          } else {
            dir = await getApplicationDocumentsDirectory();
          }

          if (dir != null) {
            final filePath = '${dir.path}/$filename';
            final file = File(filePath);
            await file.writeAsBytes(bytes);
            debugPrint('CSV saved locally to: $filePath');
          }
        } catch (e) {
          debugPrint('Local file write error: $e');
        }
      }

      // 2. Share / Save using native system dialog (works across Android/iOS/Desktop/Web)
      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );

      return 'CSV exported successfully as $filename';
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      return 'Failed to export CSV: $e';
    }
  }
}
