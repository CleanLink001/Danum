import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService with ChangeNotifier {
  bool _notificationsEnabled = false; // Default OFF as requested
  String _language = 'English';
  ThemeMode _themeMode = ThemeMode.dark;
  int _syncInterval = 10; // seconds
  bool _isSimulationMode = false; // Default to Live Firebase RTDB Mode

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
    _language = prefs.getString('language') ?? 'English';
    _isSimulationMode = prefs.getBool('simulation_mode') ?? false;
    _syncInterval = prefs.getInt('sync_interval') ?? 10;
    
    final themeStr = prefs.getString('theme_mode') ?? 'dark';
    if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  final Map<String, Map<String, String>> _translations = {
    'English': {
      'nav_dashboard': 'DASHBOARD',
      'nav_monitor': 'MONITOR',
      'nav_reports': 'REPORTS',
      'nav_profile': 'PROFILE',
      'dashboard': 'DASHBOARD',
      'monitor': 'MONITOR',
      'reports': 'REPORTS',
      'profile': 'PROFILE',
      'water_quality': 'Water Quality',
      'live_analysis': 'Live Sensor Telemetry',
      'cloud_status': 'CLOUD CONNECT',
      'system_status': '3 SENSORS ONLINE',
      'current_metrics': 'Live Sensor Metrics',
      'dynamic_insights': 'AI Predictive Insights',
      'system_stable': 'System Nominal',
      'stable_msg': 'All 3 sensors (pH, TDS, Turbidity) indicate safe, clean drinking water.',
      'real_time_monitor': 'REAL-TIME MONITOR',
      'ph_trends': 'pH Level Trends (Acid/Alkaline)',
      'tds_trends': 'TDS Trends (Dissolved Minerals)',
      'turb_trends': 'Turbidity Trends (Water Clarity)',
      'device_uptime': 'SYSTEM STABILITY',
      'sensor_perf': 'Sensor Calibration & Health',
      'maintenance': 'Predictive Maintenance History',
      'general_settings': 'General Settings',
      'notifications': 'Alert Notifications',
      'theme_mode': 'App Theme',
      'language': 'Language',
      'sys_prefs': 'Data Refresh Preferences',
      'sync_interval': 'Cloud Sync Rate',
      'monthly_overview': 'MONTHLY OVERVIEW',
      'system_perf': '3-SENSOR PERFORMANCE',
      'score': 'Score',
      'avg_monthly_quality': 'Average Monthly Quality',
      'avg_weekly_quality': 'Average Weekly Quality',
      'ph_sub': 'Acidity level (6.5 - 8.5 is safe)',
      'tds_sub': 'Mineral pureness (< 600 ppm is safe)',
      'turb_sub': 'Water clarity (< 5 NTU is clear)',
      'safe_tag': 'SAFE TO DRINK',
      'moderate_tag': 'CHECK FILTER',
      'unsafe_tag': 'UNSAFE / FLUSH NEEDED',
      'ai_predictor_title': 'AI FILTER FLUSHING PREDICTOR',
      'view_flush_guide': 'VIEW SIMPLE FLUSHING STEPS',
      'guide_title': 'How to Flush Your Water Filter',
      'valve_control_title': 'SOLENOID VALVE CONTROL',
      'valve_status': 'VALVE STATUS',
      'valve_open': 'VALVE OPEN (Flow Active)',
      'valve_closed': 'VALVE CLOSED (Water Shut-off)',
      'mode': 'MODE',
      'auto_safety': 'AUTO SAFETY MODE',
      'manual_override': 'MANUAL OVERRIDE ACTIVE',
      'resume_auto': 'RESUME AUTO MODE',
      'force_open_warning_title': 'UNSAFE WATER WARNING',
      'force_open_confirm_btn': 'FORCE OPEN VALVE',
      'cancel': 'CANCEL',
      'report_summary_title': 'AVERAGED REPORT SUMMARY',
      'quality_score_title': 'QUALITY SCORE',
      'averaged_metrics_title': 'AVERAGED SENSOR METRICS',
      'system_status_title': 'SYSTEM & ACTUATOR STATUS',
      'raw_samples_title': 'RAW SENSOR SAMPLES INCLUDED',
      'show_more_logs': 'SHOW MORE LOGS',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'system': 'System',
      'export_pdf': 'Export PDF',
      'account_settings': 'ACCOUNT SETTINGS',
      'update_credentials': 'Update Credentials',
      'logout': 'LOGOUT',
    },
    'Tagalog': {
      'nav_dashboard': 'HOME',
      'nav_monitor': 'MONITOR',
      'nav_reports': 'ULAT',
      'nav_profile': 'PROFILE',
      'dashboard': 'PANGUNAHING PAHINA',
      'monitor': 'MONITORING',
      'reports': 'MGA ULAT',
      'profile': 'PROFILE',
      'water_quality': 'Kalidad ng Tubig',
      'live_analysis': 'Kasalukuyang Sukat sa Cloud',
      'cloud_status': 'KONEKSYON SA CLOUD',
      'system_status': '3 SENSOR GUMAGANA',
      'current_metrics': 'Mga Sukat ng Sensor Ngayon',
      'dynamic_insights': 'AI Pagsusuri at Payo',
      'system_stable': 'Maayos at Ligtas ang Tubig',
      'stable_msg': 'Lahat ng 3 sukat (pH, TDS, Turbidity) ay malinis at ligtas inumin.',
      'real_time_monitor': 'MONITORING NGAYON',
      'ph_trends': 'Antas ng pH (Asim ng Tubig)',
      'tds_trends': 'Antas ng TDS (Dami ng Mineral)',
      'turb_trends': 'Antas ng Turbidity (Linaw ng Tubig)',
      'device_uptime': 'TATAG NG SISTEMA',
      'sensor_perf': 'Kalagayan ng 3 Sensor',
      'maintenance': 'Kasaysayan ng Pagbanlaw',
      'general_settings': 'Settings ng App',
      'notifications': 'Mga Notipikasyon at Babala',
      'theme_mode': 'Kulay ng App (Theme)',
      'language': 'Wika / Salita',
      'sys_prefs': 'Settings ng Sistema',
      'sync_interval': 'Bilis ng Pag-update',
      'monthly_overview': 'BUWANANG ULAT',
      'system_perf': 'PERFORMANCE NG 3 SENSOR',
      'score': 'Puntos',
      'avg_monthly_quality': 'Karaniwang Kalidad (Buwan)',
      'avg_weekly_quality': 'Karaniwang Kalidad (Linggo)',
      'ph_sub': 'Antas ng asim (Ligtas kung 6.5 - 8.5)',
      'tds_sub': 'Dami ng mineral (Ligtas kapag mas mababa sa 600 ppm)',
      'turb_sub': 'Linaw ng tubig (Ligtas kapag malinis at mas mababa sa 5 NTU)',
      'safe_tag': 'MALINIS AT LIGTAS INUMIN',
      'moderate_tag': 'KATAMTAMAN / I-TSITSEK ANG PILTRO',
      'unsafe_tag': 'HINDI LIGTAS / KAILANGAN BANLAWAN',
      'ai_predictor_title': 'AI TAGAPAGSURI NG PAGBANLAW NG PILTRO',
      'view_flush_guide': 'TINGNAN ANG MGA HAKBANG SA PAGBANLAW',
      'guide_title': 'Paano Banlawan ang Filtro ng Tubig',
      'valve_control_title': 'KONTROL NG BALBULA NG TUBIG',
      'valve_status': 'KALAGAYAN NG BALBULA',
      'valve_open': 'NAKABUKAS (BUMAGOS ANG TUBIG)',
      'valve_closed': 'NAKASARA (PINIGILAN ANG TUBIG)',
      'mode': 'PARAAN NG KONTROL',
      'auto_safety': 'AUTOMATIC NA LIGTAS',
      'manual_override': 'SARILING KONTROL GAMIT',
      'resume_auto': 'BUMALIK SA AUTOMATIC',
      'force_open_warning_title': 'BABALA: HINDI LIGTAS ANG TUBIG',
      'force_open_confirm_btn': 'PILITIN IBUKAS ANG BALBULA',
      'cancel': 'KANSELAHIN',
      'report_summary_title': 'BUOD NG ULAT NG TUBIG',
      'quality_score_title': 'PUNTOS NG KALIDAD',
      'averaged_metrics_title': 'KATAMTAMANG SUKAT NG SENSOR',
      'system_status_title': 'KALAGAYAN NG PILTRO AT BALBULA',
      'raw_samples_title': 'MGA SUKAT NA ISINAMA',
      'show_more_logs': 'IPAKITA ANG IBA PANG ULAT',
      'weekly': 'Lingguhan',
      'monthly': 'Buwanan',
      'system': 'Sistema',
      'export_pdf': 'I-download ang PDF',
      'account_settings': 'SETTINGS NG AKOUNT',
      'update_credentials': 'Baguhin ang Password',
      'logout': 'MAG-LOGOUT',
    },
    'Kapampangan': {
      'nav_dashboard': 'HOME',
      'nav_monitor': 'MONITOR',
      'nav_reports': 'ULAT',
      'nav_profile': 'PROFILE',
      'dashboard': 'PANGUNAHING PAHINA',
      'monitor': 'PAMANALANSAG',
      'reports': 'MGA ULAT',
      'profile': 'PROFILE',
      'water_quality': 'Kalidad ning Danum',
      'live_analysis': 'Sukat ngeni king Cloud',
      'cloud_status': 'KONEKSYON SA CLOUD',
      'system_status': '3 SENSOR TITIPA',
      'current_metrics': 'Sukat ning Sensor Ngeni',
      'dynamic_insights': 'AI Kabaluan at Payu',
      'system_stable': 'Masalese at Ligtas ing Danum',
      'stable_msg': 'Eganaganang 3 sukat (pH, TDS, Turbidity) malinis at ligtas inuman.',
      'real_time_monitor': 'PAMANTABAY NGENI',
      'ph_trends': 'Lebel ning pH (Aslam ning Danum)',
      'tds_trends': 'Lebel ning TDS (Karakal ning Mineral)',
      'turb_trends': 'Lebel ning Turbidity (Linaw ning Danum)',
      'device_uptime': 'TATAG NING SISTEMA',
      'sensor_perf': 'Performance ning 3 Sensor',
      'maintenance': 'Kasalesayan ning Pamag-banlaw',
      'general_settings': 'Settings ning App',
      'notifications': 'Notipikasyun at Babala',
      'theme_mode': 'Itsura ning App (Theme)',
      'language': 'Amanung Gamit',
      'sys_prefs': 'Settings ning Sistema',
      'sync_interval': 'Bilis ning Pamag-update',
      'monthly_overview': 'PABALU NING BULAN',
      'system_perf': 'PERFORMANCE NING 3 SENSOR',
      'score': 'Lebel',
      'avg_monthly_quality': 'Karaniwang Kalidad (Bulan)',
      'avg_weekly_quality': 'Karaniwang Kalidad (Paruminggu)',
      'ph_sub': 'Lebel ning aslam (Ligtas nung 6.5 - 8.5)',
      'tds_sub': 'Karakal ning mineral (Ligtas nung mababa king 600 ppm)',
      'turb_sub': 'Linaw ning danum (Ligtas nung malinis at mababa king 5 NTU)',
      'safe_tag': 'MALINIS AT LIGTAS INUMAN',
      'moderate_tag': 'KATAMTAMAN / SURIAN ING FILTRO',
      'unsafe_tag': 'E LIGTAS / KAILANGAN PAMLUSAYAN',
      'ai_predictor_title': 'AI TAGAPANGSURI NING PAMAGBANLAW NING FILTRO',
      'view_flush_guide': 'LAWEAN DENG HAKBANG KING PAMAGBANLAW',
      'guide_title': 'Mano Pamag-banlaw king Filtro ning Danum',
      'valve_control_title': 'KONTROL NING BALBULA NING DANUM',
      'valve_status': 'KALAGAYAN NING BALBULA',
      'valve_open': 'NAKABUKAS (TITIPUS ING DANUM)',
      'valve_closed': 'NAKASARA (PETIKAN ING DANUM)',
      'mode': 'PARAAN NING KONTROL',
      'auto_safety': 'AUTOMATIC A LIGTAS',
      'manual_override': 'SARILING KONTROL GAMIT',
      'resume_auto': 'MAGBALIK SA AUTOMATIC',
      'force_open_warning_title': 'BABALA: E LIGTAS ING DANUM',
      'force_open_confirm_btn': 'PILITIN IBUKAS ING BALBULA',
      'cancel': 'KANSELAHIN',
      'report_summary_title': 'BUOD NING ULAT NING DANUM',
      'quality_score_title': 'PUNTOS NING KALIDAD',
      'averaged_metrics_title': 'KATAMTAMANG SUKAT NING SENSOR',
      'system_status_title': 'KALAGAYAN NING FILTRO AT BALBULA',
      'raw_samples_title': 'MGA SUKAT A MIKASAMA',
      'show_more_logs': 'IPAKITA DENG ALIWA PANG ULAT',
      'weekly': 'Paruminggu',
      'monthly': 'Babuwan',
      'system': 'Sistema',
      'export_pdf': 'I-download ing PDF',
      'account_settings': 'SETTINGS NING AKOUNT',
      'update_credentials': 'Bayuan ing Password',
      'logout': 'MAG-LOGOUT',
    },
  };

  String translate(String key) {
    return _translations[_language]?[key] ?? key;
  }

  bool get notificationsEnabled => _notificationsEnabled;
  String get language => _language;
  ThemeMode get themeMode => _themeMode;
  int get syncInterval => _syncInterval;
  bool get isSimulationMode => _isSimulationMode;

  Future<void> toggleSimulationMode(bool value) async {
    _isSimulationMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('simulation_mode', value);
    notifyListeners();
  }

  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    String themeStr = 'dark';
    if (mode == ThemeMode.light) themeStr = 'light';
    if (mode == ThemeMode.system) themeStr = 'system';
    await prefs.setString('theme_mode', themeStr);
    notifyListeners();
  }

  Future<void> setSyncInterval(int seconds) async {
    _syncInterval = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sync_interval', seconds);
    notifyListeners();
  }
}
