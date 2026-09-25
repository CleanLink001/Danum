import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  static const String _firebaseDatabaseUrl = 
      'https://danum-3bbe4-default-rtdb.asia-southeast1.firebasedatabase.app';

  final _controller = StreamController<bool>.broadcast();
  bool _isLoggedIn = false;
  Map<String, dynamic>? _currentUser;
  
  static const String _sessionKey = 'danum_session';
  static const String _currentUserKey = 'danum_current_user';

  Stream<bool> get authState => _controller.stream;
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get currentUser => _currentUser;
  User? get firebaseUser => FirebaseAuth.instance.currentUser;

  // Backward compatibility getters
  String get serverIp => 'Firebase Cloud';
  String get baseUrl => _firebaseDatabaseUrl;

  FirebaseDatabase _getFirebaseDatabase() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _firebaseDatabaseUrl,
      );
    } catch (e) {
      return FirebaseDatabase.instance;
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_sessionKey) ?? false;
    final userJson = prefs.getString(_currentUserKey);
    if (userJson != null) {
      try {
        _currentUser = jsonDecode(userJson);
      } catch (e) {
        debugPrint('Error decoding cached user: $e');
      }
    }

    // Check if Firebase Auth already has a signed-in user
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      if (!fbUser.isAnonymous) {
        _isLoggedIn = true;
        await _syncUserProfileFromFirebase(fbUser.uid, fbUser);
      }
    }

    _controller.add(_isLoggedIn);
    notifyListeners();
  }

  Future<void> _syncUserProfileFromFirebase(String uid, User fbUser) async {
    try {
      final dbRef = _getFirebaseDatabase().ref('users/$uid');
      final snapshot = await dbRef.get();
      String name = fbUser.displayName ?? '';
      String? image = fbUser.photoURL;
      String role = 'Operator';

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        if (data['name'] != null && (data['name'] as String).isNotEmpty) {
          name = data['name'];
        }
        if (data['image'] != null) {
          image = data['image'];
        }
        if (data['role'] != null) {
          role = data['role'];
        }
      } else {
        if (name.isEmpty) {
          name = fbUser.email?.split('@').first ?? 'Danum User';
        }
        await dbRef.set({
          'name': name,
          'email': fbUser.email ?? '',
          'role': role,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      _currentUser = {
        'uid': uid,
        'name': name,
        'email': fbUser.email ?? '',
        'image': image,
        'role': role,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(_currentUser));
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing profile from Firebase RTDB: $e');
      _currentUser ??= {
        'uid': uid,
        'name': fbUser.displayName ?? fbUser.email?.split('@').first ?? 'Danum User',
        'email': fbUser.email ?? '',
        'image': fbUser.photoURL,
        'role': 'Operator',
      };
    }
  }

  static const String _authorizedUserKey = 'danum_auth_user_email';
  static const String _authorizedTestKey = 'danum_auth_test_email';

  Future<String> getAuthorizedUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authorizedUserKey) ?? 'user@example.com';
  }

  Future<String> getAuthorizedTestEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authorizedTestKey) ?? 'test@example.com';
  }

  Future<bool> isAuthorizedAccount(String email) async {
    final clean = email.trim().toLowerCase();
    final userEmail = (await getAuthorizedUserEmail()).toLowerCase();
    final testEmail = (await getAuthorizedTestEmail()).toLowerCase();
    return clean == 'user@example.com' ||
           clean == 'test@example.com' ||
           clean == userEmail ||
           clean == testEmail;
  }

  Future<String?> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    // Enforce internal-only policy: Only User and Tester accounts allowed
    if (!await isAuthorizedAccount(cleanEmail)) {
      return 'Access Denied: This application is for internal use only. Only the authorized User and Tester accounts can sign in.';
    }

    try {
      UserCredential? credential;
      try {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password.trim(),
        );
      } on FirebaseAuthException catch (authErr) {
        // If this authorized account hasn't been created in Firebase yet, auto-create it seamlessly
        if (authErr.code == 'user-not-found' || authErr.code == 'invalid-credential') {
          try {
            credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: cleanEmail,
              password: password.trim(),
            );
            final defaultName = cleanEmail.contains('test') ? 'Tester Account' : 'User Account';
            await credential.user?.updateDisplayName(defaultName);
          } catch (_) {
            rethrow; // If creation fails (e.g. wrong password on existing account), show auth error
          }
        } else {
          rethrow;
        }
      }

      final user = credential.user;
      if (user != null) {
        await _onUserAuthenticated(user);
        return null;
      }
      return 'Login failed. Please check credentials.';
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase login exception: ${e.code} - ${e.message}');
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Incorrect password. Please verify your credentials.';
      } else if (e.code == 'weak-password') {
        return 'Password must be at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        return 'The email address is badly formatted.';
      } else if (e.code == 'user-disabled') {
        return 'This internal account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        return 'Too many failed attempts. Please try again later.';
      }
      return e.message ?? 'Authentication error: ${e.code}';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  Future<String?> signUp(String email, String password, String name) async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user != null) {
        final trimmedName = name.trim().isEmpty ? email.split('@').first : name.trim();
        await user.updateDisplayName(trimmedName);

        // Store profile in Firebase Realtime Database
        try {
          await _getFirebaseDatabase().ref('users/${user.uid}').set({
            'name': trimmedName,
            'email': user.email ?? email.trim(),
            'role': 'Operator',
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (dbErr) {
          debugPrint('Error writing new user to RTDB: $dbErr');
        }

        await _onUserAuthenticated(user, initialName: trimmedName);
        return null;
      }
      return 'Account creation failed.';
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase signUp exception: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        return 'An account already exists for that email. Please sign in instead.';
      } else if (e.code == 'weak-password') {
        return 'The password is too weak. Please use at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        return 'Please enter a valid email address.';
      }
      return e.message ?? 'Sign up error: ${e.code}';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  Future<String?> signInDemo() async {
    try {
      final credential = await FirebaseAuth.instance.signInAnonymously();
      final user = credential.user;
      if (user != null) {
        await _onUserAuthenticated(user, initialName: 'Danum Operator');
        return null;
      }
      return 'Guest login failed.';
    } catch (e) {
      // Local fallback for offline testing
      _isLoggedIn = true;
      _currentUser = {
        'uid': 'demo_user',
        'name': 'Danum Operator',
        'email': 'operator@danum.local',
        'role': 'Operator',
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, true);
      await prefs.setString(_currentUserKey, jsonEncode(_currentUser));
      _controller.add(true);
      notifyListeners();
      return null;
    }
  }

  Future<void> _onUserAuthenticated(User user, {String? initialName}) async {
    _isLoggedIn = true;
    String displayName = user.displayName ?? initialName ?? '';

    try {
      final snapshot = await _getFirebaseDatabase().ref('users/${user.uid}').get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        if (data['name'] != null && (data['name'] as String).isNotEmpty) {
          displayName = data['name'];
        }
      } else {
        if (displayName.isEmpty) {
          displayName = user.email?.split('@').first ?? 'Danum Operator';
        }
        await _getFirebaseDatabase().ref('users/${user.uid}').set({
          'name': displayName,
          'email': user.email ?? 'operator@danum.local',
          'role': 'Operator',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('RTDB profile sync error: $e');
      if (displayName.isEmpty) {
        displayName = user.email?.split('@').first ?? 'Danum Operator';
      }
    }

    _currentUser = {
      'uid': user.uid,
      'name': displayName.isNotEmpty ? displayName : 'Danum Operator',
      'email': user.email ?? 'operator@danum.local',
      'image': user.photoURL,
      'role': 'Operator',
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, true);
    await prefs.setString(_currentUserKey, jsonEncode(_currentUser));
    _controller.add(true);
    notifyListeners();
  }

  Future<String?> updateProfile(String name, String? image) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return 'Name cannot be empty';

    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. Update Firebase Auth Display Name
      if (user != null && !user.isAnonymous) {
        try {
          await user.updateDisplayName(trimmedName);
        } catch (authErr) {
          debugPrint('Error updating Firebase Auth displayName: $authErr');
        }
      }

      // 2. Update Firebase Realtime Database at /users/{uid}
      if (user != null) {
        try {
          final Map<String, dynamic> updateMap = {
            'name': trimmedName,
            'updated_at': DateTime.now().toIso8601String(),
          };
          if (image != null) {
            updateMap['image'] = image;
          }
          await _getFirebaseDatabase().ref('users/${user.uid}').update(updateMap);
        } catch (dbErr) {
          debugPrint('Error updating profile in RTDB: $dbErr');
        }
      }

      // 3. Immediately update local memory
      _currentUser ??= {};
      _currentUser!['name'] = trimmedName;
      if (image != null) {
        _currentUser!['image'] = image;
      }

      // 4. Save to persistent SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(_currentUser));

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Profile update exception: $e');
      _currentUser ??= {};
      _currentUser!['name'] = trimmedName;
      if (image != null) _currentUser!['image'] = image;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(_currentUser));
      notifyListeners();
      return null;
    }
  }

  Future<String?> updateAccount(String newEmail, String oldPassword, String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (newEmail.isNotEmpty) {
        _currentUser ??= {};
        _currentUser!['email'] = newEmail.trim();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentUserKey, jsonEncode(_currentUser));
        notifyListeners();
      }
      return null;
    }

    try {
      // Re-authenticate if old password provided
      if (user.email != null && oldPassword.isNotEmpty) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: oldPassword.trim(),
        );
        await user.reauthenticateWithCredential(credential);
      }

      // Update password
      if (newPassword.isNotEmpty) {
        await user.updatePassword(newPassword.trim());
      }

      // Update email
      if (newEmail.isNotEmpty && newEmail.trim() != user.email) {
        await user.verifyBeforeUpdateEmail(newEmail.trim());
        final prefs = await SharedPreferences.getInstance();
        final currentEmail = user.email?.toLowerCase();
        final currentAuthUser = (await getAuthorizedUserEmail()).toLowerCase();
        if (currentEmail == 'user@example.com' || currentEmail == currentAuthUser) {
          await prefs.setString(_authorizedUserKey, newEmail.trim());
        } else {
          await prefs.setString(_authorizedTestKey, newEmail.trim());
        }
      }

      // Update Firebase RTDB
      try {
        await _getFirebaseDatabase().ref('users/${user.uid}').update({
          'email': newEmail.isNotEmpty ? newEmail.trim() : user.email,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (dbErr) {
        debugPrint('Error updating account in RTDB: $dbErr');
      }

      _currentUser ??= {};
      if (newEmail.isNotEmpty) _currentUser!['email'] = newEmail.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(_currentUser));
      notifyListeners();

      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase updateAccount error: ${e.code} - ${e.message}');
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Incorrect old password.';
      } else if (e.code == 'weak-password') {
        return 'New password is too weak (minimum 6 characters).';
      } else if (e.code == 'email-already-in-use') {
        return 'The new email is already in use by another account.';
      }
      return e.message ?? 'Account update error: ${e.code}';
    } catch (e) {
      return 'Error updating credentials: $e';
    }
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Firebase sign out error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, false);
    await prefs.remove(_currentUserKey);
    _isLoggedIn = false;
    _currentUser = null;
    _controller.add(false);
    notifyListeners();
  }

  // Compatibility stubs for legacy screens
  Future<void> updateServerIp(String ip) async {}
  Future<bool> testConnection(String ip) async => true;
  Future<String?> autoDiscoverServer() async => 'Firebase Cloud';

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
