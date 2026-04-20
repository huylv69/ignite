import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class AuthNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  static const _tokenKey = 'codemagic_api_token';

  AuthNotifier(this._prefs) : super(_prefs.getString(_tokenKey));

  Future<void> login(String token) async {
    await _prefs.setString(_tokenKey, token);
    state = token;
  }

  Future<void> logout() async {
    await _prefs.remove(_tokenKey);
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthNotifier(prefs);
});
