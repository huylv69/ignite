// One-tap update for the signed iOS build. Same file in every app; only the
// slug and bundle id passed to [OtaGate] differ. The running version comes
// from `--dart-define=APP_VERSION` (set by CI); a local build without it never
// checks.
//
// CI signs each iOS build and puts it next to an itms-services manifest on the
// drive (ci/ota_publish.sh). [OtaUpdate] asks that manifest which version is
// newest. Three things show the result:
//   - [OtaGate]: a card at the bottom of the screen; "Để sau" hides it until
//     the next launch or the next build.
//   - [OtaUpdateTile]: a row for the settings screen, with a dot while a build
//     is waiting. It never goes away, so a dismissed card is not lost.
//   - [OtaUpdatePage]: the version, the install button and the changelog.
// Install hands the link to iOS, which asks "Install?" itself: an app cannot
// replace itself silently.
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class OtaRelease {
  const OtaRelease(this.version, this.date, this.notes);
  final String version;
  final String date;
  final List<String> notes;
}

class OtaState {
  const OtaState({
    this.latest,
    this.releases = const [],
    this.checking = false,
    this.failed = false,
    this.checkedAt,
  });

  /// Newest signed build on the drive, null until the first check succeeds.
  final String? latest;

  /// Recent builds from the store source, newest first.
  final List<OtaRelease> releases;
  final bool checking;
  final bool failed;
  final DateTime? checkedAt;

  bool get hasUpdate =>
      latest != null && OtaUpdate.newer(latest!, OtaUpdate.current);
}

class OtaUpdate {
  OtaUpdate._();

  static const current = String.fromEnvironment('APP_VERSION');
  static const _base =
      'https://drive.huylv.tech/public.php/dav/files/AKH743YcoJRnBHa';

  static String _slug = '';
  static String _bundleId = '';
  static final state = ValueNotifier(const OtaState());

  /// Only the signed iPhone build built by CI can update itself.
  static bool get supported => !kIsWeb && Platform.isIOS && current.isNotEmpty;

  static String get _manifest => '$_base/$_slug/ota/manifest.plist';

  static void configure(String slug, String bundleId) {
    _slug = slug;
    _bundleId = bundleId;
  }

  static Future<void> check() async {
    if (!supported || _slug.isEmpty || state.value.checking) return;
    final prev = state.value;
    state.value = OtaState(
      latest: prev.latest,
      releases: prev.releases,
      checking: true,
      checkedAt: prev.checkedAt,
    );
    try {
      final m = await http
          .get(Uri.parse(_manifest))
          .timeout(const Duration(seconds: 10));
      final v = RegExp(
        r'<key>bundle-version</key>\s*<string>([^<]+)</string>',
      ).firstMatch(m.body)?.group(1);
      if (m.statusCode != 200 || v == null) throw StateError('no manifest');
      state.value = OtaState(
        latest: v,
        releases: await _releases(),
        checkedAt: DateTime.now(),
      );
    } catch (_) {
      state.value = OtaState(
        latest: prev.latest,
        releases: prev.releases,
        failed: true,
        checkedAt: prev.checkedAt,
      );
    }
  }

  static Future<void> install() => launchUrl(
    Uri.parse('itms-services://?action=download-manifest&url=$_manifest'),
    mode: LaunchMode.externalApplication,
  );

  static bool newer(String a, String b) {
    final x = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final y = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < x.length || i < y.length; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d > 0;
    }
    return false;
  }

  /// Changelog per build from the store source; missing it hides nothing else.
  static Future<List<OtaRelease>> _releases() async {
    try {
      final r = await http
          .get(Uri.parse('$_base/apps.json'))
          .timeout(const Duration(seconds: 10));
      final apps = jsonDecode(utf8.decode(r.bodyBytes))['apps'] as List;
      final app = apps.firstWhere((a) => a['bundleIdentifier'] == _bundleId);
      return [
        for (final e in app['versions'] as List)
          OtaRelease(
            e['version'] as String? ?? '',
            e['date'] as String? ?? '',
            (e['localizedDescription'] as String? ?? '')
                .split('\n')
                .map((l) => l.replaceFirst(RegExp(r'^•\s*'), '').trim())
                .where((l) => l.isNotEmpty)
                .toList(),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// Checks on launch and whenever the app comes back, and shows a card at the
/// bottom while a newer build waits. Mounted from MaterialApp.router's
/// `builder`, above the Navigator, so the card lives in a Stack.
class OtaGate extends StatefulWidget {
  const OtaGate({
    super.key,
    required this.slug,
    required this.bundleId,
    required this.child,
  });

  final String slug;
  final String bundleId;
  final Widget child;

  @override
  State<OtaGate> createState() => _OtaGateState();
}

class _OtaGateState extends State<OtaGate> with WidgetsBindingObserver {
  String? _dismissed;

  @override
  void initState() {
    super.initState();
    OtaUpdate.configure(widget.slug, widget.bundleId);
    WidgetsBinding.instance.addObserver(this);
    OtaUpdate.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) OtaUpdate.check();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OtaState>(
      valueListenable: OtaUpdate.state,
      builder: (context, s, _) {
        final v = s.latest;
        if (!s.hasUpdate || v == _dismissed) return widget.child;
        final notes = s.releases
            .where((r) => r.version == v)
            .expand((r) => r.notes)
            .take(3);
        final theme = Theme.of(context);
        return Stack(
          children: [
            widget.child,
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(18),
                color: theme.colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Có bản mới $v', style: theme.textTheme.titleMedium),
                      for (final n in notes)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '· $n',
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _dismissed = v),
                            child: const Text('Để sau'),
                          ),
                          const SizedBox(width: 6),
                          FilledButton(
                            onPressed: OtaUpdate.install,
                            child: const Text('Cập nhật'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "Cập nhật" row for a settings screen. Hidden where the app cannot update
/// itself (web, Android, local builds).
class OtaUpdateTile extends StatelessWidget {
  const OtaUpdateTile({super.key});

  @override
  Widget build(BuildContext context) {
    if (!OtaUpdate.supported) return const SizedBox.shrink();
    return ValueListenableBuilder<OtaState>(
      valueListenable: OtaUpdate.state,
      builder:
          (context, s, _) => ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('Cập nhật'),
            subtitle: Text(
              s.hasUpdate
                  ? 'Có bản mới ${s.latest}'
                  : 'Đang dùng ${OtaUpdate.current}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.hasUpdate)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OtaUpdatePage(),
                  ),
                ),
          ),
    );
  }
}

class OtaUpdatePage extends StatefulWidget {
  const OtaUpdatePage({super.key});

  @override
  State<OtaUpdatePage> createState() => _OtaUpdatePageState();
}

class _OtaUpdatePageState extends State<OtaUpdatePage> {
  @override
  void initState() {
    super.initState();
    OtaUpdate.check();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cập nhật ứng dụng')),
      body: ValueListenableBuilder<OtaState>(
        valueListenable: OtaUpdate.state,
        builder: (context, s, _) {
          final status =
              s.checking
                  ? 'Đang kiểm tra…'
                  : s.hasUpdate
                  ? 'Có bản mới ${s.latest}'
                  : s.latest == null
                  ? (s.failed ? 'Không kiểm tra được, thử lại sau' : '')
                  : 'Đang dùng bản mới nhất';
          return RefreshIndicator(
            onRefresh: OtaUpdate.check,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text('Bản đang dùng', style: theme.textTheme.labelMedium),
                Text(
                  OtaUpdate.current.isEmpty ? '—' : OtaUpdate.current,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(status, style: theme.textTheme.bodyMedium),
                if (s.checkedAt != null)
                  Text(
                    'Kiểm tra lúc ${TimeOfDay.fromDateTime(s.checkedAt!).format(context)}',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (s.hasUpdate) ...[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: OtaUpdate.install,
                          icon: const Icon(Icons.download_rounded),
                          label: Text('Cập nhật lên ${s.latest}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    OutlinedButton(
                      onPressed: s.checking ? null : OtaUpdate.check,
                      child: const Text('Kiểm tra lại'),
                    ),
                  ],
                ),
                if (s.releases.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Thay đổi gần đây', style: theme.textTheme.titleMedium),
                  for (final r in s.releases) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(r.version, style: theme.textTheme.titleSmall),
                        const SizedBox(width: 8),
                        if (r.version == OtaUpdate.current)
                          Text('· đang dùng', style: theme.textTheme.bodySmall)
                        else if (OtaUpdate.newer(r.version, OtaUpdate.current))
                          Text(
                            '· mới',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        const Spacer(),
                        Text(r.date, style: theme.textTheme.bodySmall),
                      ],
                    ),
                    for (final n in r.notes)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('· $n', style: theme.textTheme.bodySmall),
                      ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
