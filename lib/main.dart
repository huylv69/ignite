import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/auth_provider.dart';
import 'core/providers/accounts_provider.dart';
import 'core/providers/biometric_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/models/app_model.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/lock_page.dart';
import 'presentation/pages/apps_page.dart';
import 'presentation/pages/app_detail_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const CodemagicAdminApp(),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final accountsState = ref.watch(accountsProvider);
  final unlocked = ref.watch(biometricUnlockedProvider);
  final hasToken = accountsState.active != null;

  return GoRouter(
    // Web has no biometrics — treat as always unlocked
    initialLocation: !hasToken ? '/login' : (unlocked || kIsWeb ? '/' : '/unlock'),
    redirect: (context, state) {
      final loc = state.matchedLocation;

      if (!hasToken) {
        return loc == '/login' ? null : '/login';
      }
      if (!unlocked && !kIsWeb) {
        return loc == '/unlock' ? null : '/unlock';
      }
      if (loc == '/login' || loc == '/unlock') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/unlock', builder: (_, __) => const LockPage()),
      GoRoute(path: '/', builder: (_, __) => const AppsPage()),
      GoRoute(
        path: '/app/:id',
        builder: (context, state) {
          final app = state.extra as CmApplication;
          return AppDetailPage(app: app);
        },
      ),
    ],
  );
});

class CodemagicAdminApp extends ConsumerWidget {
  const CodemagicAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Ignite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
