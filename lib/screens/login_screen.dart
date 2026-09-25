import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../widgets/loading_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language_rounded, color: Color(0xFF38BDF8)),
            tooltip: settings.translate('language'),
            onSelected: (String lang) => settings.setLanguage(lang),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'English', child: Text('English')),
              const PopupMenuItem(value: 'Tagalog', child: Text('Tagalog')),
              const PopupMenuItem(value: 'Kapampangan', child: Text('Kapampangan')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(45),
                        child: Image.asset(
                          'web/icons/Icon-Danum.jpeg',
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.water_drop_rounded, size: 80, color: Color(0xFF3B82F6)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    settings.translate('danum_monitor'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 6),
                          Text(
                            settings.translate('internal_use_only'),
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    settings.translate('login_subtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subColor, fontSize: 13),
                  ),
                  const SizedBox(height: 35),

                  _buildInputField(
                    label: settings.translate('account_email'),
                    hint: settings.translate('email_hint'),
                    icon: Icons.email_rounded,
                    controller: _emailController,
                    isDark: isDark,
                    textColor: textColor,
                    subColor: subColor,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: settings.translate('password'),
                    hint: settings.translate('password_hint'),
                    icon: Icons.lock_rounded,
                    controller: _passwordController,
                    isPassword: true,
                    obscureText: _obscurePassword,
                    onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                    isDark: isDark,
                    textColor: textColor,
                    subColor: subColor,
                  ),
                  const SizedBox(height: 25),
                  _buildLoginButton(settings),
                  const SizedBox(height: 25),
                  Text(
                    settings.translate('login_footer_note'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subColor.withValues(alpha: 0.6), fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            DanumLoadingScreen(
              statusText: settings.translate('authenticating_account'),
              isOverlay: true,
            ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required bool isDark,
    required Color textColor,
    required Color subColor,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggle,
  }) {
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final iconBg = isDark ? const Color(0xFF1F2937) : const Color(0xFFEFF6FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.08)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  obscureText: obscureText,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: subColor.withValues(alpha: 0.6), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          if (isPassword)
            IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: subColor,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(SettingsService settings) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : () => _handleLogin(settings),
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  settings.translate('sign_in'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin(SettingsService settings) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showToast(settings.translate('err_fill_email_password'), isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);

    final error = await auth.login(email, password);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        String localizedError = error;
        if (error.contains('Access Denied')) {
          localizedError = settings.translate('err_access_denied');
        } else if (error.contains('Incorrect password')) {
          localizedError = settings.translate('err_incorrect_password');
        } else if (error.contains('at least 6 characters')) {
          localizedError = settings.translate('err_weak_password');
        } else if (error.contains('badly formatted')) {
          localizedError = settings.translate('err_invalid_email');
        } else if (error.contains('disabled')) {
          localizedError = settings.translate('err_account_disabled');
        } else if (error.contains('Too many failed')) {
          localizedError = settings.translate('err_too_many_requests');
        } else if (error.contains('Login failed')) {
          localizedError = settings.translate('err_login_failed');
        }
        _showToast(localizedError, isError: true);
      }
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
