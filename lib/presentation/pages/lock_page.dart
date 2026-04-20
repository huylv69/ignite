import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/providers/accounts_provider.dart';
import '../../core/providers/biometric_provider.dart';
import '../../core/theme/app_theme.dart';

class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> with WidgetsBindingObserver {
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-prompt when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      final unlocked = ref.read(biometricUnlockedProvider);
      if (!unlocked) _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() { _authenticating = true; _error = null; });

    final auth = ref.read(localAuthProvider);
    try {
      final success = await auth.authenticate(
        localizedReason: 'Unlock Ignite to access your builds',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN/passcode fallback
          stickyAuth: true,
        ),
      );
      if (success && mounted) {
        ref.read(biometricUnlockedProvider.notifier).state = true;
        context.go('/');
      } else if (mounted) {
        setState(() => _error = 'Authentication cancelled');
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(accountsProvider.notifier).logoutActive();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -120, left: -80,
            child: Container(
              width: 340, height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.primary.withValues(alpha: 0.15),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -80, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.accent.withValues(alpha: 0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Lock icon
                  Container(
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
                    child: const Icon(Icons.lock_rounded, size: 44, color: Colors.white),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 0.96, end: 1.04, duration: 2400.ms, curve: Curves.easeInOut),
                  const SizedBox(height: 32),
                  const Text(
                    'Ignite',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 8),
                  const Text(
                    'Verify your identity to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 48),

                  // Biometric button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _authenticating ? null : _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        disabledBackgroundColor: AppTheme.bgCard,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _authenticating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.fingerprint, color: Colors.white, size: 22),
                      label: Text(
                        _authenticating ? 'Verifying…' : 'Unlock with Biometrics',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.error, fontSize: 13),
                    ).animate().fadeIn(),
                  ],

                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _logout,
                    child: const Text(
                      'Use a different account',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
