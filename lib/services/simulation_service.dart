import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/water_quality.dart';
import 'auth_service.dart';
import 'settings_service.dart';

class SimulationService extends ChangeNotifier {
  static const String _firebaseDatabaseUrl = 
      'https://danum-3bbe4-default-rtdb.asia-southeast1.firebasedatabase.app';

  final _controller = StreamController<WaterQualityData>.broadcast();
  Timer? _timer;
  final _random = Random();
  int _tickCount = 0;

  final List<WaterQualityData> _history = [];
  final List<WaterQualityData> _logs = []; // Historical logs
  bool _manualValveOverride = false;
  bool _lastManualState = true;
  
  SettingsService? _settings;
  AuthService? _auth;

  int _syncIntervalSeconds = 3;

  StreamSubscription<DatabaseEvent>? _metricsSubscription;
  StreamSubscription<DatabaseEvent>? _logsSubscription;
  StreamSubscription<DatabaseEvent>? _controlsSubscription;

  Stream<WaterQualityData> get dataStream => _controller.stream;
  List<WaterQualityData> get history => List.unmodifiable(_history);
  List<WaterQualityData> get logs => List.unmodifiable(_logs);
  bool get manualValveOverride => _manualValveOverride;
  bool get lastManualState => _lastManualState;

  FirebaseDatabase _getFirebaseDatabase() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _firebaseDatabaseUrl,
      );
    } catch (e) {
      debugPrint('Error getting regional FirebaseDatabase instance: $e');
      return FirebaseDatabase.instance;
    }
  }

  void _cancelFirebaseSubscriptions() {
    _metricsSubscription?.cancel();
    _metricsSubscription = null;
    _logsSubscription?.cancel();
    _logsSubscription = null;
    _controlsSubscription?.cancel();
    _controlsSubscription = null;
  }

  void updateSyncInterval(int seconds) {
    _syncIntervalSeconds = seconds;
    if (_settings != null && !_settings!.isSimulationMode) {
      _getFirebaseDatabase().ref().child('controls').update({
        'sync_interval': seconds,
      }).catchError((e) {
        debugPrint('Error updating sync interval on Firebase: $e');
      });
    } else if (_timer != null && _timer!.isActive) {
      startSimulation(settings: _settings, auth: _auth, initialInterval: seconds);
    }
  }

  void setValveState(bool open) {
    _manualValveOverride = true;
    _lastManualState = open;
    if (_history.isNotEmpty) {
      final last = _history.last;
      final updated = WaterQualityData(
        ph: last.ph,
        tds: last.tds,
        turbidity: last.turbidity,
        filterHealth: last.filterHealth,
        valveOpen: _lastManualState,
        solarVoltage: last.solarVoltage,
        timestamp: DateTime.now(),
      );
      _history[_history.length - 1] = updated;
      _controller.add(updated);
    }
    notifyListeners();

    if (_settings != null && !_settings!.isSimulationMode) {
      _sendValveUpdateToFirebase();
    }
  }

  void toggleValve() {
    setValveState(!_lastManualState);
  }

  Future<void> _sendValveUpdateToFirebase() async {
    try {
      final dbRef = _getFirebaseDatabase().ref();
      await dbRef.child('controls').update({
        'manual_valve_override': 1,
        'valve_state': _lastManualState ? 1 : 0,
      });
    } catch (e) {
      debugPrint('Error sending valve update to Firebase: $e');
    }
  }
  
  Future<void> disableValveOverride() async {
    _manualValveOverride = false;
    
    // Evaluate automatic valve state immediately based on latest water reading safety
    bool autoOpen = true;
    if (_history.isNotEmpty) {
      final last = _history.last;
      autoOpen = last.isSafe;
      _lastManualState = autoOpen;
      
      final updated = WaterQualityData(
        ph: last.ph,
        tds: last.tds,
        turbidity: last.turbidity,
        filterHealth: last.filterHealth,
        valveOpen: autoOpen,
        solarVoltage: last.solarVoltage,
        timestamp: DateTime.now(),
      );
      _history[_history.length - 1] = updated;
      _controller.add(updated);
    }
    
    notifyListeners();

    if (_settings != null && !_settings!.isSimulationMode) {
      try {
        final dbRef = _getFirebaseDatabase().ref();
        await dbRef.child('controls').update({
          'manual_valve_override': 0,
          'valve_state': autoOpen ? 1 : 0,
        });
      } catch (e) {
        debugPrint('Error disabling valve override on Firebase: $e');
      }
    }
  }

  void startSimulation({SettingsService? settings, AuthService? auth, int initialInterval = 3}) {
    _settings = settings;
    _auth = auth;
    _syncIntervalSeconds = initialInterval;
    final now = DateTime.now();
    
    // Seed initial baseline data so UI never blocks indefinitely
    final defaultInitial = WaterQualityData(
      ph: 7.10,
      tds: 145.0,
      turbidity: 1.2,
      filterHealth: 98.0,
      valveOpen: true,
      solarVoltage: 12.8,
      timestamp: now,
    );

    if (_history.isEmpty) {
      _history.add(defaultInitial);
    }

    if (_logs.isEmpty) {
      for (int i = 7; i >= 0; i--) {
        _logs.add(WaterQualityData(
          ph: 6.95 + _random.nextDouble() * 0.30,
          tds: 100 + _random.nextDouble() * 200,
          turbidity: 1 + _random.nextDouble() * 3,
          filterHealth: 100 - (i * 2.0),
          valveOpen: true,
          solarVoltage: 13.5 + _random.nextDouble(),
          timestamp: now.subtract(Duration(days: i)),
        ));
      }
    }

    // Immediately push initial item into controller so StreamBuilder displays dashboard
    _controller.add(_history.last);

    double currentFilterHealth = 100.0;
    if (_history.isNotEmpty) currentFilterHealth = _history.last.filterHealth;

    _timer?.cancel();
    _cancelFirebaseSubscriptions();

    // 1. If in Live IoT Mode, subscribe to Firebase RTDB streams
    if (_settings != null && !_settings!.isSimulationMode) {
      _initFirebaseListeners();
      return;
    }

    // 2. Otherwise, run simulated data generator (Simulation Mode)
    _timer = Timer.periodic(Duration(seconds: _syncIntervalSeconds), (timer) {
      _tickCount++;
      currentFilterHealth -= 0.001 * _syncIntervalSeconds;
      if (currentFilterHealth < 0) currentFilterHealth = 0;

      final ph = 6.95 + _random.nextDouble() * 0.30;
      final tds = 50 + _random.nextDouble() * 500;
      final turbidity = _random.nextDouble() * 8;
      final solarVoltage = 11.5 + _random.nextDouble() * 3.3;

      double score = 100;
      score -= (ph - 7.0).abs() * 15;
      if (tds > 50) score -= (tds - 50) * 0.1;
      if (turbidity > 1) score -= (turbidity - 1) * 10;
      
      bool automaticValveOpen = score > 50;
      bool finalValveState;

      if (_manualValveOverride) {
        finalValveState = _lastManualState;
      } else {
        finalValveState = automaticValveOpen;
        _lastManualState = finalValveState;
      }

      final newData = WaterQualityData(
        ph: ph,
        tds: tds,
        turbidity: turbidity,
        filterHealth: currentFilterHealth,
        valveOpen: finalValveState,
        solarVoltage: solarVoltage,
        timestamp: DateTime.now(),
      );
      
      _history.add(newData);
      if (_history.length > 20) {
        _history.removeAt(0);
      }
      
      if (_tickCount % 5 == 0) {
        _logs.add(newData);
        if (_logs.length > 100) _logs.removeAt(0);
        notifyListeners();
      }
      
      _controller.add(newData);
    });
  }

  void _initFirebaseListeners() {
    final dbRef = _getFirebaseDatabase().ref();

    // 1. Listen to live metrics
    _metricsSubscription = dbRef.child('live/metrics').onValue.listen((event) {
      if (event.snapshot.value != null) {
        try {
          final dataMap = Map<String, dynamic>.from(event.snapshot.value as Map);
          final newData = WaterQualityData.fromJson(dataMap);

          if (_history.isEmpty) {
            _history.add(newData);
          } else {
            if (_history.last.timestamp != newData.timestamp) {
              _history.add(newData);
              if (_history.length > 20) {
                _history.removeAt(0);
              }
            } else {
              _history[_history.length - 1] = newData;
            }
          }
          
          _controller.add(newData);
          notifyListeners();
        } catch (e) {
          debugPrint('Error parsing live metrics from Firebase: $e');
        }
      }
    }, onError: (error) {
      debugPrint('Firebase metrics stream error: $error');
    });

    // 2. Listen to historical logs
    _logsSubscription = dbRef.child('history/logs').limitToLast(100).onValue.listen((event) {
      if (event.snapshot.value != null) {
        try {
          final logsMap = event.snapshot.value as Map<dynamic, dynamic>;
          final List<WaterQualityData> tempLogs = [];
          
          logsMap.forEach((key, val) {
            if (val != null) {
              final dataMap = Map<String, dynamic>.from(val as Map);
              tempLogs.add(WaterQualityData.fromJson(dataMap));
            }
          });

          tempLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          
          _logs.clear();
          _logs.addAll(tempLogs);
          _purgeOldLogs();
          notifyListeners();
        } catch (e) {
          debugPrint('Error parsing historical logs from Firebase: $e');
        }
      }
    }, onError: (error) {
      debugPrint('Firebase logs stream error: $error');
    });

    // 3. Listen to controls
    _controlsSubscription = dbRef.child('controls').onValue.listen((event) {
      if (event.snapshot.value != null) {
        try {
          final controlsMap = Map<String, dynamic>.from(event.snapshot.value as Map);
          _manualValveOverride = (controlsMap['manual_valve_override'] == 1 || controlsMap['manual_valve_override'] == true);
          _lastManualState = (controlsMap['valve_state'] == 1 || controlsMap['valve_state'] == true);
          
          int serverInterval = controlsMap['sync_interval'] ?? 30;
          if (serverInterval != _syncIntervalSeconds) {
            _syncIntervalSeconds = serverInterval;
          }
          notifyListeners();
        } catch (e) {
          debugPrint('Error parsing controls from Firebase: $e');
        }
      }
    }, onError: (error) {
      debugPrint('Firebase controls stream error: $error');
    });
  }

  void _purgeOldLogs() {
    final cutoff = DateTime.now().subtract(const Duration(days: 180));
    _logs.removeWhere((log) => log.timestamp.isBefore(cutoff));
  }

  void stopSimulation() {
    _timer?.cancel();
    _cancelFirebaseSubscriptions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelFirebaseSubscriptions();
    _controller.close();
    super.dispose();
  }
}
