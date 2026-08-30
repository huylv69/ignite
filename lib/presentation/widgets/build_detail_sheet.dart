import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' hide ShareResult;
import 'package:url_launcher/url_launcher.dart' as ul;
import '../../core/models/app_model.dart';
import '../../core/providers/accounts_provider.dart';
import '../../core/providers/codemagic_provider.dart';
import '../../core/theme/app_theme.dart';
import '../pages/step_log_page.dart';

class BuildDetailSheet extends ConsumerStatefulWidget {
  final CmBuild build;
  final String? workflowDisplayName;
  final VoidCallback? onCanceled;

  const BuildDetailSheet({
    super.key,
    required this.build,
    this.workflowDisplayName,
    this.onCanceled,
  });

  static Future<void> show(
    BuildContext context,
    CmBuild build, {
    String? workflowDisplayName,
    VoidCallback? onCanceled,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => BuildDetailSheet(
            build: build,
            workflowDisplayName: workflowDisplayName,
            onCanceled: onCanceled,
          ),
    );
  }

  @override
  ConsumerState<BuildDetailSheet> createState() => _BuildDetailSheetState();
}

class _BuildDetailSheetState extends ConsumerState<BuildDetailSheet> {
  bool _isCanceling = false;

  Future<void> _cancelBuild() async {
    setState(() => _isCanceling = true);
    try {
      final api = ref.read(codemagicApiProvider);
      if (api == null) return;
      await api.cancelBuild(widget.build.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Build canceled.'),
            backgroundColor: AppTheme.warning,
          ),
        );
        widget.onCanceled?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCanceling = false);
    }
  }

  Future<void> _launchUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    try {
      await ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.build;
    final fmt = DateFormat('MMM d, yyyy HH:mm');

    Color statusColor;
    IconData statusIcon;
    if (b.isSuccess) {
      statusColor = AppTheme.success;
      statusIcon = Icons.check_circle;
    } else if (b.isFailed) {
      statusColor = AppTheme.error;
      statusIcon = Icons.error;
    } else if (b.isRunning) {
      statusColor = AppTheme.warning;
      statusIcon = Icons.sync;
    } else if (b.isCanceled) {
      statusColor = AppTheme.textMuted;
      statusIcon = Icons.cancel;
    } else {
      statusColor = AppTheme.textSecondary;
      statusIcon = Icons.help_outline;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder:
          (context, scrollController) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Row(
                      children: [
                        if (b.isRunning)
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              color: statusColor,
                              strokeWidth: 2.5,
                            ),
                          )
                        else
                          Icon(statusIcon, color: statusColor, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.workflowDisplayName?.isNotEmpty == true
                                    ? widget.workflowDisplayName!
                                    : b.workflowName.isNotEmpty
                                    ? b.workflowName
                                    : b.workflowId,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Build #${b.buildNumber ?? '?'} · ${b.status.toUpperCase()}',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _Section(
                      title: 'Commit',
                      children: [
                        _InfoRow(
                          icon: Icons.commit,
                          label: 'Message',
                          value: b.commitMessage ?? 'No commit message',
                        ),
                        if (b.commitHash != null)
                          _InfoRow(
                            icon: Icons.tag,
                            label: 'Hash',
                            value:
                                b.commitHash!.length > 8
                                    ? b.commitHash!.substring(0, 8)
                                    : b.commitHash!,
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: b.commitHash!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Commit hash copied'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        if (b.authorName != null)
                          _InfoRow(
                            icon: Icons.person_outline,
                            label: 'Author',
                            value: b.authorName!,
                          ),
                        if (b.pullRequestNumber != null)
                          _InfoRow(
                            icon: Icons.merge_type,
                            label: 'PR',
                            value: '#${b.pullRequestNumber}',
                          ),
                        if (b.commitUrl != null)
                          _InfoRow(
                            icon: Icons.open_in_new,
                            label: 'Link',
                            value:
                                Uri.tryParse(b.commitUrl!)?.host ??
                                b.commitUrl!,
                            onTap: () => _launchUrl(b.commitUrl!),
                            trailing: Icons.open_in_new,
                          ),
                        _InfoRow(
                          icon: Icons.call_split,
                          label: 'Branch',
                          value: b.branch ?? 'unknown',
                        ),
                      ],
                    ),
                    if (b.labels.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Labels',
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children:
                                  b.labels
                                      .map(
                                        (l) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accent.withValues(
                                              alpha: 0.14,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            l,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.accent,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (b.releaseNotes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Release notes',
                        children:
                            b.releaseNotes
                                .map(
                                  (n) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      n,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Timing',
                      children: [
                        if (b.startedAt != null)
                          _InfoRow(
                            icon: Icons.play_arrow,
                            label: 'Started',
                            value: fmt.format(b.startedAt!.toLocal()),
                          ),
                        if (b.finishedAt != null)
                          _InfoRow(
                            icon: Icons.stop,
                            label: 'Finished',
                            value: fmt.format(b.finishedAt!.toLocal()),
                          ),
                        if (b.duration != null)
                          _InfoRow(
                            icon: Icons.timer,
                            label: 'Duration',
                            value: _formatDuration(b.duration!),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StepsSection(buildId: b.id, fallback: b.buildActions),
                    if (b.artifacts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Artifacts (${b.artifacts.length})',
                        children:
                            b.artifacts
                                .map((a) => _ArtifactRow(artifact: a))
                                .toList(),
                      ),
                    ],
                    if (b.buildUrl != null) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _launchUrl(b.buildUrl!),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open in Codemagic'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ],
                    if (b.isRunning) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isCanceling ? null : _cancelBuild,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon:
                              _isCanceling
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.cancel,
                                    color: Colors.white,
                                  ),
                          label: Text(
                            _isCanceling ? 'Canceling...' : 'Cancel Build',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

/// The build's steps, each opening its own log.
///
/// Builds reached from the list may already carry their actions, but a build
/// that has aged out of the list endpoint will not, so the detail response is
/// preferred and [fallback] only fills the gap while it loads.
class _StepsSection extends ConsumerWidget {
  final String buildId;
  final List<CmBuildAction> fallback;

  const _StepsSection({required this.buildId, required this.fallback});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // v3 sends CORS headers, so the step list loads in a browser too; the
    // legacy detail (which the artifact rows still need) covers it elsewhere.
    final actions = ref.watch(buildActionsProvider(buildId));
    final detail = ref.watch(buildDetailProvider(buildId));
    final steps =
        actions.valueOrNull ?? detail.valueOrNull?.buildActions ?? fallback;

    if (steps.isEmpty) {
      if (actions.isLoading || detail.isLoading) {
        return const _Section(
          title: 'Steps',
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Loading steps…',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }
      return const _Section(
        title: 'Steps',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              'No steps recorded for this build.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ),
        ],
      );
    }

    return _Section(
      title: 'Steps (${steps.length})',
      children:
          steps
              .map(
                (s) => _StepRow(
                  step: s,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => StepLogPage(buildId: buildId, step: s),
                        ),
                      ),
                ),
              )
              .toList(),
    );
  }
}

class _StepRow extends StatelessWidget {
  final CmBuildAction step;
  final VoidCallback onTap;
  const _StepRow({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style(step);
    final d = step.duration;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                step.name,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (d != null) ...[
              Text(
                d.inMinutes > 0
                    ? '${d.inMinutes}m ${d.inSeconds % 60}s'
                    : '${d.inSeconds}s',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              Icons.chevron_right,
              size: 15,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  static (Color, IconData) _style(CmBuildAction a) {
    if (a.isSuccess) return (AppTheme.success, Icons.check_circle_outline);
    if (a.isFailed) return (AppTheme.error, Icons.error_outline);
    if (a.isSkipped) return (AppTheme.textMuted, Icons.skip_next_outlined);
    if (a.isCanceled) return (AppTheme.textMuted, Icons.block_outlined);
    return (AppTheme.warning, Icons.hourglass_empty);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing = Icons.copy,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null)
              Icon(trailing, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ArtifactRow extends ConsumerStatefulWidget {
  final CmArtifact artifact;
  const _ArtifactRow({required this.artifact});

  @override
  ConsumerState<_ArtifactRow> createState() => _ArtifactRowState();
}

class _ArtifactRowState extends ConsumerState<_ArtifactRow> {
  bool _downloading = false;
  bool _sharing = false;
  double? _progress;
  final _key = GlobalKey();

  /// Streams the artifact to a temp file and hands it to the share sheet.
  ///
  /// Native platforms only — `getTemporaryDirectory()` throws on web, which is
  /// why the tap is routed to [_shareLink] there instead.
  Future<void> _download() async {
    final url = widget.artifact.url;
    if (url == null) return;
    final token = ref.read(activeTokenProvider);
    setState(() {
      _downloading = true;
      _progress = null;
    });
    try {
      final uri = Uri.parse(url);
      final req = http.Request('GET', uri);
      if (token != null && token.isNotEmpty) {
        req.headers['x-auth-token'] = token;
      }
      final response = await req.send();
      if (response.statusCode >= 400) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.artifact.name}');
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _progress = received / total);
        }
      }
      await sink.close();
      if (mounted) {
        final box = _key.currentContext?.findRenderObject() as RenderBox?;
        final origin =
            box != null
                ? box.localToGlobal(Offset.zero) & box.size
                : const Rect.fromLTWH(0, 0, 200, 50);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: widget.artifact.name,
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = null;
        });
      }
    }
  }

  /// Mints a time-limited public link that needs no auth token, so the
  /// artifact can be passed to someone who has no Codemagic access.
  Future<void> _shareLink() async {
    final path = widget.artifact.path;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This artifact has no shareable path.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _sharing = true);
    try {
      final api = ref.read(codemagicApiProvider);
      if (api == null) return;
      final expiresAt = DateTime.now().add(const Duration(hours: 24));
      final url = await api.createArtifactPublicUrl(path, expiresAt);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: AppTheme.bgCard,
              title: const Text('Public link ready'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.artifact.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Copied to the clipboard. Anyone with this link can download '
                    'the artifact until it expires in 24 hours.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    url,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppTheme.accent,
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ],
            ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create link: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.artifact;
    final sizeLabel = a.size != null ? _formatSize(a.size!) : '';
    final busy = _downloading || _sharing;
    // Writing to disk is impossible on web, so the primary action there is the
    // public link rather than a download that would throw.
    final primary = kIsWeb ? _shareLink : _download;

    return Padding(
      key: _key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          if (_downloading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 2,
                color: AppTheme.accent,
              ),
            )
          else
            Icon(_iconFor(a.type), size: 16, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: a.url != null && !busy ? primary : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name, style: const TextStyle(fontSize: 13)),
                  if (_downloading && _progress != null)
                    Text(
                      '${(_progress! * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.accent,
                      ),
                    )
                  else
                    Text(
                      [
                        if (a.versionName != null) 'v${a.versionName}',
                        if (sizeLabel.isNotEmpty) sizeLabel,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!kIsWeb)
            IconButton(
              tooltip: 'Download',
              icon: const Icon(Icons.download_rounded, size: 18),
              color: AppTheme.textMuted,
              onPressed: a.url != null && !busy ? _download : null,
            ),
          IconButton(
            tooltip: 'Copy public link',
            icon:
                _sharing
                    ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.link_rounded, size: 18),
            color: AppTheme.textMuted,
            onPressed: a.path != null && !busy ? _shareLink : null,
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String? type) {
    switch (type) {
      case 'apk':
      case 'aab':
        return Icons.android_rounded;
      case 'ipa':
        return Icons.phone_iphone_rounded;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
