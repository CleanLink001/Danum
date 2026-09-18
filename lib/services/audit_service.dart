import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audit_log.dart';
import 'auth_service.dart';

class AuditService with ChangeNotifier {
  static const String _storageKey = 'danum_audit_logs_cache';
  final List<AuditLog> _logs = [];
  bool _isLoading = false;

  List<AuditLog> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;

  AuditService() {
    _initFromStorage();
  }

  Future<void> init() async {
    await _initFromStorage();
  }

  /// Automatically purges records that are older than 6 months (180 days)
  void _purgeOldLogs() {
    final cutoff = DateTime.now().subtract(const Duration(days: 180));
    _logs.removeWhere((log) => log.timestamp.isBefore(cutoff));
  }

  Future<void> _initFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString(_storageKey);
      if (storedJson != null && storedJson.isNotEmpty) {
        final decoded = jsonDecode(storedJson);
        if (decoded is List) {
          final loaded = decoded.map((e) => AuditLog.fromJson(Map<String, dynamic>.from(e))).toList();
          _logs.clear();
          _logs.addAll(loaded);
        }
      }
    } catch (e) {
      debugPrint('Error loading cached audit logs: $e');
    }

    _purgeOldLogs();

    if (_logs.isEmpty) {
      _seedDefaultLogs();
      _saveToPrefs();
    } else {
      notifyListeners();
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_logs.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Error saving audit logs to cache: $e');
    }
  }

  void _seedDefaultLogs() {
    _logs.addAll([
      AuditLog(
        id: 1,
        userName: 'System',
        userEmail: 'system@danum.local',
        category: 'VALVE_CONTROL',
        action: 'Auto Safety Rule Active',
        details: 'Monitoring water quality sensors (pH, TDS, Turbidity) for solenoid safety',
        ipAddress: '127.0.0.1',
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
      AuditLog(
        id: 2,
        userName: 'Operator',
        userEmail: 'operator@danum.local',
        category: 'SECURITY',
        action: 'User Session Started',
        details: 'Logged into Danum Water Monitor system',
        ipAddress: '192.168.1.102',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      AuditLog(
        id: 3,
        userName: 'Operator',
        userEmail: 'operator@danum.local',
        category: 'SETTINGS',
        action: 'Cloud Sync Interval Updated',
        details: 'Sync interval configured to 10 seconds',
        ipAddress: '192.168.1.102',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
    ]);
  }

  Future<void> fetchAuditLogs(AuthService authService) async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = '${authService.baseUrl}/get_audit_logs.php';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['logs'] is List) {
          final fetched = (data['logs'] as List).map((e) => AuditLog.fromJson(e)).toList();
          
          if (fetched.isNotEmpty) {
            final existingIds = _logs.map((e) => e.id).whereType<int>().toSet();
            for (var log in fetched) {
              if (log.id != null && !existingIds.contains(log.id)) {
                _logs.add(log);
              }
            }
            _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            _purgeOldLogs();
            await _saveToPrefs();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching audit logs from API: $e. Retaining local persistent audit trail.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logEvent({
    AuthService? authService,
    required String category,
    required String action,
    required String details,
  }) async {
    final currentUser = authService?.currentUser;
    final userName = currentUser?['name'] ?? 'System Operator';
    final userEmail = currentUser?['email'] ?? 'operator@danum.local';

    final localLog = AuditLog(
      id: DateTime.now().millisecondsSinceEpoch,
      userName: userName,
      userEmail: userEmail,
      category: category,
      action: action,
      details: details,
      ipAddress: '127.0.0.1',
      timestamp: DateTime.now(),
    );

    _logs.insert(0, localLog);
    _purgeOldLogs();
    await _saveToPrefs();
    notifyListeners();

    if (authService != null) {
      try {
        final url = '${authService.baseUrl}/log_audit.php';
        await http.post(
          Uri.parse(url),
          body: jsonEncode({
            'user_name': userName,
            'user_email': userEmail,
            'category': category,
            'action': action,
            'details': details,
          }),
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Failed to post audit log to backend: $e');
      }
    }
  }
}
