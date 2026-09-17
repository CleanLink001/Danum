import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
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

  void _showServerSettingsDialog() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final ipController = TextEditingController(text: authService.serverIp);
    bool testing = false;
    String? testResult;
    bool testSuccess = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.dns_rounded, color: Color(0xFF3B82F6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Server Settings',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Set the IP address of your local XAMPP backend. Use 10.0.3.2 for Genymotion, or your PC\'s Wi-Fi IP for real phones.',
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: ipController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Server IP Address',
                        labelStyle: TextStyle(color: Colors.white38, fontSize: 12),
                        border: InputBorder.none,
                        hintText: 'e.g., 10.0.3.2',
                        hintStyle: TextStyle(color: Colors.white12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (testing)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (testResult != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: testSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: testSuccess ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            testSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                            color: testSuccess ? Colors.greenAccent : Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              testResult!,
                              style: TextStyle(
                                color: testSuccess ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F2937),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      setDialogState(() {
                        testing = true;
                        testResult = null;
                      });
                      final success = await authService.testConnection(ipController.text);
                      setDialogState(() {
                        testing = false;
                        testSuccess = success;
                        testResult = success
                            ? 'Connection Successful! Server is active.'
                            : 'Connection Failed. Verify XAMPP is running & IP is correct.';
                      });
                    },
                    icon: const Icon(Icons.network_check_rounded, size: 18),
                    label: const Text('Test Connection'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      setDialogState(() {
                        testing = true;
                        testResult = null;
                      });
                      final foundIp = await authService.autoDiscoverServer();
                      setDialogState(() {
                        testing = false;
                        if (foundIp != null) {
                          ipController.text = foundIp;
                          testSuccess = true;
                          testResult = 'Server Auto-Detected at: $foundIp';
                        } else {
                          testSuccess = false;
                          testResult = 'Server Discovery Failed. Make sure PC server is active & on same Wi-Fi.';
                        }
                      });
                    },
                    icon: const Icon(Icons.travel_explore_rounded, size: 18),
                    label: const Text('Auto-Detect Server'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                ),
                TextButton(
                  onPressed: () async {
                    await authService.updateServerIp(ipController.text);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Server IP updated to: ${ipController.text}'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  child: const Text('Apply', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final iconColor = isDark ? Colors.white38 : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_suggest_rounded, color: iconColor),
            tooltip: 'Server Settings',
            onPressed: _showServerSettingsDialog,
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top),
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
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'web/icons/Icon-Danum.jpeg',
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF3B82F6),
                              child: const Icon(Icons.water_drop_rounded, size: 50, color: Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sign in to your Danum Monitor account',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subColor, fontSize: 14),
                  ),
                  const SizedBox(height: 50),
                  _buildInputField(
                    label: 'Email',
                    hint: 'Enter your email address',
                    icon: Icons.email_rounded,
                    controller: _emailController,
                    isDark: isDark,
                    textColor: textColor,
                    subColor: subColor,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    label: 'Password',
                    hint: 'Enter your password',
                    icon: Icons.lock_rounded,
                    controller: _passwordController,
                    isPassword: true,
                    obscureText: _obscurePassword,
                    onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                    isDark: isDark,
                    textColor: textColor,
                    subColor: subColor,
                  ),
                  const SizedBox(height: 30),
                  _buildLoginButton(),
                  const SizedBox(height: 40),
                  Text(
                    'Danum System - Internal Use Only',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subColor.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const DanumLoadingScreen(
              message: 'Authenticating Danum Account...',
              fullScreen: true,
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
            child: const Icon(Icons.water_drop_rounded, color: Color(0xFF3B82F6), size: 20),
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

  Widget _buildLoginButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleLogin,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('SIGN IN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    final error = await Provider.of<AuthService>(context, listen: false).login(
      _emailController.text,
      _passwordController.text,
    );
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error), 
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}
