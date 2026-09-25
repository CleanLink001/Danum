import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/simulation_service.dart';
import '../services/notification_service.dart';
import '../services/audit_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditingProfile = false;
  bool _isEditingAccount = false;
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _oldPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _nameController = TextEditingController(text: auth.currentUser?['name'] ?? '');
    _emailController = TextEditingController(text: auth.currentUser?['email'] ?? '');
    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final settings = Provider.of<SettingsService>(context);
    final audit = Provider.of<AuditService>(context, listen: false);
    final user = auth.currentUser;
    
    // Auto-sync controllers if not actively in edit mode
    if (!_isEditingProfile && user != null && user['name'] != null) {
      if (_nameController.text != user['name']) {
        _nameController.text = user['name']!;
      }
    }
    if (!_isEditingAccount && user != null && user['email'] != null) {
      if (_emailController.text != user['email']) {
        _emailController.text = user['email']!;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
        actions: [
          IconButton(
            onPressed: () async {
              if (_isEditingProfile) {
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  final error = await auth.updateProfile(newName, null);
                  if (error == null) {
                    audit.logEvent(
                      authService: auth,
                      category: 'USER_PROFILE',
                      action: 'Profile Name Updated',
                      details: 'User display name changed to "$newName"',
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Profile updated: $newName'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                }
              } else {
                _nameController.text = user?['name'] ?? '';
              }
              if (mounted) {
                setState(() => _isEditingProfile = !_isEditingProfile);
              }
            },
            icon: Icon(_isEditingProfile ? Icons.check_rounded : Icons.edit_rounded, color: const Color(0xFF818CF8)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(user, isDark, textColor, subColor),
            const SizedBox(height: 40),
            
            _buildSectionTitle(context, 'ACCOUNT SETTINGS'),
            _buildAccountSettings(auth, isDark, textColor, subColor),
            
            const SizedBox(height: 40),
            _buildSectionTitle(context, settings.translate('general_settings')),
            _buildGeneralSettings(settings, textColor, subColor),
            
            const SizedBox(height: 20),
            _buildSectionTitle(context, settings.translate('sys_prefs')),
            _buildSystemPrefs(settings, textColor, subColor),
            
            const SizedBox(height: 30),
            _buildSectionTitle(context, 'APP & REPOSITORY'),
            _buildAppInfoCard(context, isDark, textColor, subColor),
            
            const SizedBox(height: 40),
            _buildLogoutButton(auth),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic>? user, bool isDark, Color textColor, Color subColor) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFF818CF8),
              child: Text(
                (user?['name'] ?? 'G').substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            if (_isEditingProfile)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image upload coming soon'))),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (_isEditingProfile)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: TextField(
              controller: _nameController,
              autofocus: true,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              decoration: InputDecoration(
                hintText: 'Enter Name',
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.black12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          )
        else
          Text(
            user?['name'] ?? 'John Doe',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
          ),
        Text(user?['email'] ?? '', style: TextStyle(color: subColor)),
      ],
    );
  }

  Widget _buildAccountSettings(AuthService auth, bool isDark, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildEditField(
            label: 'Email Address',
            controller: _emailController,
            enabled: _isEditingAccount,
            icon: Icons.email_outlined,
            textColor: textColor,
          ),
          if (_isEditingAccount) ...[
            const SizedBox(height: 20),
            _buildEditField(
              label: 'Old Password',
              controller: _oldPasswordController,
              enabled: true,
              isPassword: true,
              icon: Icons.lock_open_rounded,
              textColor: textColor,
            ),
            const SizedBox(height: 20),
            _buildEditField(
              label: 'New Password',
              controller: _newPasswordController,
              enabled: true,
              isPassword: true,
              icon: Icons.lock_outline,
              textColor: textColor,
            ),
            const SizedBox(height: 20),
            _buildEditField(
              label: 'Confirm New Password',
              controller: _confirmPasswordController,
              enabled: true,
              isPassword: true,
              icon: Icons.verified_user_outlined,
              textColor: textColor,
            ),
          ],
          const SizedBox(height: 30),
          if (!_isEditingAccount)
            TextButton.icon(
              onPressed: () => setState(() => _isEditingAccount = true),
              icon: const Icon(Icons.security_rounded, size: 18),
              label: const Text('Update Credentials'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF818CF8)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _isEditingAccount = false);
                      _oldPasswordController.clear();
                      _newPasswordController.clear();
                      _confirmPasswordController.clear();
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                      foregroundColor: Colors.redAccent,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_oldPasswordController.text.isEmpty) {
                        _showError('Old password is required');
                        return;
                      }
                      if (_newPasswordController.text.isEmpty) {
                        _showError('New password cannot be empty');
                        return;
                      }
                      if (_newPasswordController.text != _confirmPasswordController.text) {
                        _showError('Passwords do not match');
                        return;
                      }

                      final error = await auth.updateAccount(
                        _emailController.text,
                        _oldPasswordController.text,
                        _newPasswordController.text,
                      );
                      
                      if (!mounted) return;
                      
                      if (error == null) {
                        setState(() => _isEditingAccount = false);
                        _oldPasswordController.clear();
                        _newPasswordController.clear();
                        _confirmPasswordController.clear();
                        final audit = Provider.of<AuditService>(context, listen: false);
                        audit.logEvent(
                          authService: auth,
                          category: 'SECURITY',
                          action: 'Account Credentials Updated',
                          details: 'Password / security credentials successfully updated for ${_emailController.text.trim()}',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account updated successfully'), backgroundColor: Colors.green));
                      } else {
                        _showError(error);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required IconData icon,
    required Color textColor,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: isPassword,
          style: TextStyle(color: enabled ? textColor : textColor.withValues(alpha: 0.5), fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: enabled ? const Color(0xFF818CF8) : Colors.white24),
            filled: true,
            fillColor: enabled ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 15),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF818CF8), letterSpacing: 1.5),
          ),
          const SizedBox(width: 15),
          Expanded(child: Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black.withValues(alpha: 0.1))),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings(SettingsService settings, Color textColor, Color subColor) {
    return Column(
      children: [
        _buildSwitchTile(
          Icons.notifications_active, 
          settings.translate('notifications'), 
          settings.notificationsEnabled, 
          (v) async {
            if (v) {
              final notificationService = Provider.of<NotificationService>(context, listen: false);
              final granted = await notificationService.requestPermission();
              if (granted) {
                await settings.toggleNotifications(true);
                await notificationService.showNotification(
                  id: 99,
                  title: '🔔 Notifications Enabled',
                  body: 'You will receive real-time push alerts when water quality is unsafe.',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Notifications enabled successfully!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              } else {
                await settings.toggleNotifications(false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Notification permission denied by system.'),
                      backgroundColor: Colors.orangeAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              }
            } else {
              await settings.toggleNotifications(false);
            }
          }, 
          textColor, 
          subColor,
        ),
        _buildDropdownTile(
          Icons.dark_mode, 
          settings.translate('theme_mode'), 
          settings.themeMode == ThemeMode.dark ? 'Dark' : 'Light', 
          ['Dark', 'Light'], 
          (v) => settings.setThemeMode(v == 'Dark' ? ThemeMode.dark : ThemeMode.light), 
          textColor, 
          subColor,
        ),
        _buildDropdownTile(
          Icons.language, 
          settings.translate('language'), 
          settings.language, 
          ['English', 'Tagalog', 'Kapampangan'], 
          (v) => settings.setLanguage(v!), 
          textColor, 
          subColor,
        ),
      ],
    );
  }

  Widget _buildSystemPrefs(SettingsService settings, Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSliderTile(
          Icons.sync,
          settings.translate('sync_interval'),
          '${settings.syncInterval}s',
          settings.syncInterval.toDouble(),
          10,
          60,
          (val) {
            settings.setSyncInterval(val.toInt());
            Provider.of<SimulationService>(context, listen: false).updateSyncInterval(val.toInt());
          },
          textColor,
          subColor,
          onChangeEnd: (val) {
            final audit = Provider.of<AuditService>(context, listen: false);
            final auth = Provider.of<AuthService>(context, listen: false);
            audit.logEvent(
              authService: auth,
              category: 'SETTINGS',
              action: 'Cloud Sync Interval Updated',
              details: 'Cloud database telemetry sync interval configured to ${val.toInt()} seconds',
            );
          },
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF0284C7).withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Cloud Sync Rate & Database Lifetime',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• How It Works:\n'
                'Controls how frequently the system uploads real-time water quality sensor metrics (pH, TDS, turbidity, battery) to the cloud database.\n\n'
                '• Impact on Database Lifetime & Quotas:\n'
                '• Faster Sync (10s): Provides near-instant telemetry updates and faster emergency alerting, but generates high write traffic, consumes more bandwidth and power, and reaches cloud database storage quotas sooner.\n'
                '• Slower Sync (30s–60s): Minimizes write frequency, significantly reduces database size accumulation, prevents quota exhaustion, and dramatically extends database lifetime while preserving reliable monitoring.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: subColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(AuthService auth) {
    return ElevatedButton.icon(
      onPressed: () => auth.logout(),
      icon: const Icon(Icons.logout),
      label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
        foregroundColor: const Color(0xFFEF4444),
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, bool value, Function(bool) onChanged, Color textColor, Color subColor) {
    return ListTile(
      leading: Icon(icon, color: subColor),
      title: Text(title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFF22D3EE)),
    );
  }

  Widget _buildDropdownTile(IconData icon, String title, String current, List<String> options, Function(String?) onChanged, Color textColor, Color subColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(icon, color: subColor),
      title: Text(title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: DropdownButton<String>(
        value: current,
        underline: const SizedBox(),
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        items: options.map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: textColor)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSliderTile(
    IconData icon,
    String title,
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    Color textColor,
    Color subColor, {
    ValueChanged<double>? onChangeEnd,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: subColor),
          title: Text(title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
          trailing: Text(label, style: const TextStyle(color: Color(0xFF22D3EE), fontWeight: FontWeight.bold)),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 5,
          activeColor: const Color(0xFF818CF8),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }

  Widget _buildAppInfoCard(BuildContext context, bool isDark, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Image.asset(
                    'web/icons/Icon-Danum.jpeg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.water_drop_rounded, size: 28, color: Color(0xFF0284C7)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Danum Monitor',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version 1.0.0 (Build 1)',
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Latest',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.code_rounded, size: 18, color: Color(0xFF818CF8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'github.com/CleanLink001/Danum',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openUrl('https://github.com/CleanLink001/Danum'),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('GitHub Repo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl('https://github.com/CleanLink001/Danum/raw/main/app-release.apk'),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download APK'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }
}
