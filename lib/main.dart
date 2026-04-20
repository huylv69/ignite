import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/models/app_model.dart';
import 'presentation/pages/login_page.dart';
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
  final token = ref.watch(authProvider);

  return GoRouter(
    initialLocation: token == null ? '/login' : '/',
    redirect: (context, state) {
      final isAuth = token != null && token.isNotEmpty;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuth && !isLoggingIn) return '/login';
      if (isAuth && isLoggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const AppsPage(),
      ),
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
