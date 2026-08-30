import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Posts a local notification when a build finishes.
///
/// Codemagic has no outbound webhook for build events — its webhooks run the
/// other way, from the git host into Codemagic — so the only way to learn a
/// build ended is to poll. This is the delivery half; the polling lives in
/// `build_watch_provider.dart`.
class BuildNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationChannel(
    'builds',
    'Build results',
    description: 'A build you were watching finished, failed or was canceled.',
    importance: Importance.high,
  );

  /// Web has no notification centre worth using here; the app falls back to
  /// an in-app banner there, so this is a no-op rather than an error.
  bool get supported => !kIsWeb;

  Future<void> init() async {
    if (!supported || _ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: false,
          requestSoundPermission: true,
        ),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!supported) return;
    if (!_ready) await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
