import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
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
  
  final notificationService = NotificationService();
  await notificationService.init();

  final settingsService = SettingsService();
  await settingsService.init();

  final authService = AuthService();
  await authService.init();

  final auditService = AuditService();
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
        title: '🔴 UNSAFE WATER QUALITY',
        body: 'Overall Score: ${data.score}/100. Please check your water filter and source.',
      );
    }

    // 2. pH Acidic alert
    if (data.ph < 6.5 && shouldNotify('ph_acidic')) {
      notificationService.showNotification(
        id: 10,
        title: '🔴 ACIDIC WATER DETECTED',
        body: 'Critical pH level: ${data.ph.toStringAsFixed(1)} (Too Acidic). Water may be corrosive.',
      );
    } 
    // 3. pH Alkaline alert
    else if (data.ph > 8.5 && shouldNotify('ph_alkaline')) {
      notificationService.showNotification(
        id: 11,
        title: '🔴 ALKALINE WATER DETECTED',
        body: 'Critical pH level: ${data.ph.toStringAsFixed(1)} (Too Alkaline). High mineral/scale risk.',
      );
    }

    // 4. TDS (Total Dissolved Solids) alert
    if (data.tds > 300.0 && shouldNotify('tds_high')) {
      notificationService.showNotification(
        id: 12,
        title: '⚠️ HIGH SOLIDS (TDS) ALERT',
        body: 'TDS: ${data.tds.toStringAsFixed(0)} ppm. High dissolved minerals, check filter membrane.',
      );
    }

    // 5. Turbidity (Cloudiness) alert
    if (data.turbidity > 5.0 && shouldNotify('turbidity_high')) {
      notificationService.showNotification(
        id: 13,
        title: '⚠️ CLOUDY WATER DETECTED',
        body: 'Turbidity: ${data.turbidity.toStringAsFixed(1)} NTU. High turbidity indicates muddy/dirty water.',
      );
    }

    // 6. Filter Replacement alert
    if (data.filterHealth < 20.0 && shouldNotify('filter_health')) {
      notificationService.showNotification(
        id: 1,
        title: '⚠️ FILTER REPLACEMENT NEEDED',
        body: 'Your filter health is at ${data.filterHealth.toStringAsFixed(0)}%. Please replace filter soon.',
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
