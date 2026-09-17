import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'discovery_helper.dart';

class AuthService with ChangeNotifier {
  final _controller = StreamController<bool>.broadcast();
  bool _isLoggedIn = false;
  Map<String, dynamic>? _currentUser;
  
  String _serverIp = '10.0.3.2'; // Optimized default for Genymotion
  static const String _sessionKey = 'danum_session';
  static const String _currentUserKey = 'danum_current_user';
  static const String _serverIpKey = 'danum_server_ip';

  Stream<bool> get authState => _controller.stream;
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get currentUser => _currentUser;
  String get serverIp => _serverIp;
  String get baseUrl => 'http://$_serverIp/danum/api';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_sessionKey) ?? false;
    _serverIp = prefs.getString(_serverIpKey) ?? '10.0.3.2';
    final userJson = prefs.getString(_currentUserKey);
    if (userJson != null) {
      _currentUser = jsonDecode(userJson);
    }
    _controller.add(_isLoggedIn);
    notifyListeners();
  }

  Future<void> updateServerIp(String ip) async {
    _serverIp = ip.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverIpKey, _serverIp);
    notifyListeners();
  }

  Future<bool> testConnection(String ip) async {
    try {
      final testUrl = 'http://${ip.trim()}/danum/api/get_sensor_data.php';
      final response = await http.get(Uri.parse(testUrl)).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed for $ip: $e');
      return false;
    }
  }

  Future<String?> autoDiscoverServer() async {
    // 1. Try shayon.local first
    final testHost = 'shayon.local';
    if (await testConnection(testHost)) {
      await updateServerIp(testHost);
      return testHost;
    }
    
    // 2. Try the Genymotion emulator default IP
    if (await testConnection('10.0.3.2')) {
      await updateServerIp('10.0.3.2');
      return '10.0.3.2';
    }

    // 3. Try standard Windows Hotspot IP
    if (await testConnection('192.168.137.1')) {
      await updateServerIp('192.168.137.1');
      return '192.168.137.1';
    }

    // 4. Fetch local subnets on mobile
    try {
      final subnets = await getLocalSubnets();
      
      // Ensure we add standard private IP subnets just in case
      for (var stdSubnet in ['192.168.100.', '192.168.1.', '192.168.0.', '192.168.137.']) {
        if (!subnets.contains(stdSubnet)) {
          subnets.add(stdSubnet);
        }
      }

      final completer = Completer<String?>();
      bool found = false;

      void checkIp(String targetIp) async {
        if (found) return;
        final ok = await testConnection(targetIp);
        if (ok && !found) {
          found = true;
          await updateServerIp(targetIp);
          if (!completer.isCompleted) completer.complete(targetIp);
        }
      }

      // Scan the most common host indices first (gateways and common dhcp starts)
      final commonIndices = [1, 2, 3, 4, 5, 100, 101, 102, 103, 104, 105, 137, 200];
      
      for (var subnet in subnets) {
        for (var i in commonIndices) {
          checkIp('$subnet$i');
        }
      }

      // Start a wider background scan in batches
      Future.delayed(const Duration(milliseconds: 150), () {
        if (found) return;
        for (var subnet in subnets) {
          for (int i = 1; i <= 254; i++) {
            if (!commonIndices.contains(i)) {
              checkIp('$subnet$i');
            }
          }
        }
      });

      // Timeout after 6 seconds if not found
      Future.delayed(const Duration(seconds: 6), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      return completer.future;
    } catch (e) {
      debugPrint('Subnet discovery failed: $e');
      return null;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login.php'),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 4));

      final result = jsonDecode(response.body);

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        _isLoggedIn = true;
        _currentUser = result['user'];
        // Note: Password is not returned by API for security, 
        // we might want to store it locally if we need to show it in settings,
        // but usually we just allow changing to a new one.
        await prefs.setBool(_sessionKey, true);
        await prefs.setString(_currentUserKey, jsonEncode(_currentUser));
        _controller.add(true);
        notifyListeners();
        return null;
      } else {
        return result['error'] ?? 'Login failed';
      }
    } catch (e) {
      // Local fallback: Allow developer testing if the local XAMPP server is down/offline
      if ((email == 'test@example.com' && password == 'Password123!') ||
          (email == 'user@example.com' && password == 'Password123!')) {
        final prefs = await SharedPreferences.getInstance();
        _isLoggedIn = true;
        _currentUser = {
          'name': email == 'test@example.com' ? 'Developer' : 'User Account',
          'email': email,
          'image': null,
        };
        await prefs.setBool(_sessionKey, true);
        await prefs.setString(_currentUserKey, jsonEncode(_currentUser));
        _controller.add(true);
        notifyListeners();
        return null;
      }
      return 'Server error. Make sure MySQL & Apache are running in XAMPP.';
    }
  }

  Future<String?> updateAccount(String newEmail, String oldPassword, String newPassword) async {
    if (_currentUser == null) return 'Not logged in';
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_account.php'),
        body: jsonEncode({
          'old_email': _currentUser!['email'],
          'new_email': newEmail,
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      final result = jsonDecode(response.body);

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        _currentUser!['email'] = newEmail;
        await prefs.setString(_currentUserKey, jsonEncode(_currentUser));
        notifyListeners();
        return null;
      } else {
        return result['error'] ?? 'Update failed';
      }
    } catch (e) {
      return 'Server error during account update';
    }
  }

  Future<void> updateProfile(String name, String? image) async {
    if (_currentUser == null) return;
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_profile.php'),
        body: jsonEncode({
          'email': _currentUser!['email'],
          'name': name,
          'image': image,
        }),
      );

      final result = jsonDecode(response.body);

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        _currentUser!['name'] = name;
        _currentUser!['image'] = image;
        await prefs.setString(_currentUserKey, jsonEncode(_currentUser));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Profile update failed: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, false);
    _isLoggedIn = false;
    _currentUser = null;
    await prefs.remove(_currentUserKey);
    _controller.add(false);
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
