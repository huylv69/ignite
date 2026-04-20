import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final localAuthProvider = Provider<LocalAuthentication>((ref) {
  return LocalAuthentication();
});

// Session-level: reset to false every app launch
final biometricUnlockedProvider = StateProvider<bool>((ref) => false);

// Whether the device supports biometrics at all
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  final auth = ref.read(localAuthProvider);
  try {
    final canCheck = await auth.canCheckBiometrics;
    final isSupported = await auth.isDeviceSupported();
    return canCheck || isSupported;
  } catch (_) {
    return false;
  }
});
