import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/accounts_provider.dart';
import '../../core/providers/biometric_provider.dart';
import '../../core/services/codemagic_api.dart';
import '../../core/theme/app_theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _tokenController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _tokenController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'API token is required');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = CodemagicApi(token);
      // Validate token + try to get a name from the API
      String accountName = _nameController.text.trim();
      final futures = await Future.wait([
        api.getApplications(),
        if (accountName.isEmpty) api.getUser().catchError((_) => <String, dynamic>{}),
      ]);
      if (accountName.isEmpty) {
        final user = futures.length > 1 ? futures[1] as Map<String, dynamic> : {};
        accountName = user['user']?['email']?.toString()
            ?? user['email']?.toString()
            ?? 'Account';
      }
      await ref.read(accountsProvider.notifier).addAccount(token, accountName);
      ref.read(biometricUnlockedProvider.notifier).state = true;
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = 'Invalid token or connection failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Glow background
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          colors: [AppTheme.primaryLight, AppTheme.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 0.96, end: 1.04, duration: 2400.ms, curve: Curves.easeInOut),
                  ),
                  const SizedBox(height: 28),
                  // Brand name
                  const Text(
                    'Ignite',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 6),
                  const Text(
                    'Codemagic CI/CD Admin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 48),
                  // Token field
                  TextField(
                    controller: _tokenController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Personal Access Token',
                      hintText: 'Paste your Codemagic token',
                      prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppTheme.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      errorText: _error,
                      errorMaxLines: 2,
                    ),
                    onSubmitted: (_) => _login(),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 12),
                  Text(
                    'Find your token in Codemagic → Team settings → Integrations → Codemagic API',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 28),
                  // Connect button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Connect',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
