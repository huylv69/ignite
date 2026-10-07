// One-tap update for the signed iOS build. Same file in every app; only the
// slug and bundle id passed to [OtaGate] differ. The running version comes
// from `--dart-define=APP_VERSION` (set by CI); a local build without it never
// checks.
//
// CI signs each iOS build and puts it next to an itms-services manifest on the
// drive (ci/ota_publish.sh). This asks that manifest which version is newest
// and, if it is newer than the running one, shows a card with the install
// link. iOS then asks "Install?" itself: an app cannot replace itself silently.
//
// Mounted from MaterialApp.router's `builder`, which sits above the Navigator,
// so the card is drawn in a Stack instead of through showDialog.
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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

  static const version = String.fromEnvironment('APP_VERSION');

  @override
  State<OtaGate> createState() => _OtaGateState();
}

class _OtaGateState extends State<OtaGate> with WidgetsBindingObserver {
  static const _base =
      'https://drive.huylv.tech/public.php/dav/files/AKH743YcoJRnBHa';

  String? _newVersion;
  List<String> _notes = const [];
  bool _dismissed = false;

  String get _manifest => '$_base/${widget.slug}/ota/manifest.plist';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back to the app is when a fresh build is most likely waiting.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (kIsWeb || !Platform.isIOS || OtaGate.version.isEmpty) return;
    try {
      final m = await http
          .get(Uri.parse(_manifest))
          .timeout(const Duration(seconds: 10));
      final v = RegExp(
        r'<key>bundle-version</key>\s*<string>([^<]+)</string>',
      ).firstMatch(m.body)?.group(1);
      if (m.statusCode != 200 || v == null || !_newer(v, OtaGate.version)) {
        return;
      }
      if (v == _newVersion) return;
      final notes = await _changelog(v);
      if (!mounted) return;
      setState(() {
        _newVersion = v;
        _notes = notes;
        _dismissed = false;
      });
    } catch (_) {
      // Offline or the drive is down: say nothing, try again later.
    }
  }

  static bool _newer(String a, String b) {
    final x = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final y = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < x.length || i < y.length; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d > 0;
    }
    return false;
  }

  /// Changelog lines for [version] from the SideStore source.
  Future<List<String>> _changelog(String version) async {
    try {
      final r = await http
          .get(Uri.parse('$_base/apps.json'))
          .timeout(const Duration(seconds: 10));
      final apps = jsonDecode(utf8.decode(r.bodyBytes))['apps'] as List;
      final app = apps.firstWhere(
        (a) => a['bundleIdentifier'] == widget.bundleId,
      );
      final entry = (app['versions'] as List).firstWhere(
        (e) => e['version'] == version,
      );
      return (entry['localizedDescription'] as String? ?? '')
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^•\s*'), '').trim())
          .where((l) => l.isNotEmpty)
          .take(4)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _newVersion;
    if (v == null || _dismissed) return widget.child;
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
                  for (final n in _notes)
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
                        onPressed: () => setState(() => _dismissed = true),
                        child: const Text('Để sau'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed:
                            () => launchUrl(
                              Uri.parse(
                                'itms-services://?action=download-manifest'
                                '&url=$_manifest',
                              ),
                              mode: LaunchMode.externalApplication,
                            ),
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
  }
}
