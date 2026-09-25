import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/main_screen.dart';
import 'services/simulation_service.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'services/audit_service.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Authenticate app instance with Firebase so Realtime Database rules (auth != null) pass
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint('Firebase Auth: Signed in anonymously (UID: ${FirebaseAuth.instance.currentUser?.uid})');
    } else {
      debugPrint('Firebase Auth: Already authenticated (UID: ${FirebaseAuth.instance.currentUser?.uid})');
    }
  } catch (e) {
    debugPrint('Firebase Auth initialization warning: $e');
  }
  
  final notificationService = NotificationService();
  await notificationService.init();

  final settingsService = SettingsService();
  await settingsService.init();

  final authService = AuthService();
  await authService.init();

  final auditService = AuditService();
  await auditService.init();
  auditService.fetchAuditLogs(authService);

  final simulationService = SimulationService();
  simulationService.startSimulation(settings: settingsService, auth: authService);

  // Smart anti-flooding map to space out parameter alerts (at most once every 5 minutes)
  final Map<String, DateTime> lastNotificationTimes = {};

  bool shouldNotify(String category) {
    final now = DateTime.now();
    final lastTime = lastNotificationTimes[category];
    if (lastTime == null || now.difference(lastTime) > const Duration(minutes: 5)) {
      lastNotificationTimes[category] = now;
      return true;
    }
    return false;
  }

  // Listen for critical levels to trigger notifications
  simulationService.dataStream.listen((data) {
    if (!settingsService.notificationsEnabled) return;

    // 1. Quality Status alert (general fallback)
    if (data.status == 'Poor' && shouldNotify('general_poor')) {
      notificationService.showNotification(
        id: 0,
        title: settingsService.translate('alert_unsafe_quality_title'),
        body: settingsService.translate('alert_unsafe_quality_body', {'score': data.score.toString()}),
      );
    }

    // 2. pH Acidic alert
    if (data.ph < 6.5 && shouldNotify('ph_acidic')) {
      notificationService.showNotification(
        id: 10,
        title: settingsService.translate('alert_ph_acidic_title'),
        body: settingsService.translate('alert_ph_acidic_body', {'value': data.ph.toStringAsFixed(1)}),
      );
    } 
    // 3. pH Alkaline alert
    else if (data.ph > 8.5 && shouldNotify('ph_alkaline')) {
      notificationService.showNotification(
        id: 11,
        title: settingsService.translate('alert_ph_alkaline_title'),
        body: settingsService.translate('alert_ph_alkaline_body', {'value': data.ph.toStringAsFixed(1)}),
      );
    }

    // 4. TDS (Total Dissolved Solids) alert
    if (data.tds > 300.0 && shouldNotify('tds_high')) {
      notificationService.showNotification(
        id: 12,
        title: settingsService.translate('alert_tds_high_title'),
        body: settingsService.translate('alert_tds_high_body', {'value': data.tds.toStringAsFixed(0)}),
      );
    }

    // 5. Turbidity (Cloudiness) alert
    if (data.turbidity > 5.0 && shouldNotify('turbidity_high')) {
      notificationService.showNotification(
        id: 13,
        title: settingsService.translate('alert_turb_high_title'),
        body: settingsService.translate('alert_turb_high_body', {'value': data.turbidity.toStringAsFixed(1)}),
      );
    }

    // 6. Filter Replacement alert
    if (data.filterHealth < 20.0 && shouldNotify('filter_health')) {
      notificationService.showNotification(
        id: 1,
        title: settingsService.translate('alert_filter_replace_title'),
        body: settingsService.translate('alert_filter_replace_body', {'value': data.filterHealth.toStringAsFixed(0)}),
      );
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>(create: (_) => settingsService),
        ChangeNotifierProvider<SimulationService>(create: (_) => simulationService),
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider<AuthService>(create: (_) => authService),
        ChangeNotifierProvider<AuditService>(create: (_) => auditService),
      ],
      child: const DanumApp(),
    ),
  );
}

class DanumApp extends StatelessWidget {
  const DanumApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    
    return MaterialApp(
      title: 'Danum Water Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          return StreamBuilder<bool>(
            stream: auth.authState,
            initialData: auth.isLoggedIn,
            builder: (context, snapshot) {
              // Ensure we have a valid state
              final bool loggedIn = snapshot.data ?? auth.isLoggedIn;
              
              if (loggedIn) {
                return const MainScreen();
              }
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
