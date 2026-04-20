import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as ul;
import '../../core/models/app_model.dart';
import '../../core/providers/codemagic_provider.dart';
import '../../core/theme/app_theme.dart';

Future<void> _launchUrl(BuildContext context, String rawUrl) async {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid URL: $rawUrl'), backgroundColor: AppTheme.error),
      );
    }
    return;
  }
  try {
    final ok = await ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open URL: $rawUrl'), backgroundColor: AppTheme.error),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}

class BuildDetailSheet extends ConsumerStatefulWidget {
  final CmBuild build;
  final VoidCallback? onCanceled;

  const BuildDetailSheet({super.key, required this.build, this.onCanceled});

  static Future<void> show(BuildContext context, CmBuild build, {VoidCallback? onCanceled}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => BuildDetailSheet(build: build, onCanceled: onCanceled),
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
          const SnackBar(content: Text('Build canceled.'), backgroundColor: AppTheme.warning),
        );
        widget.onCanceled?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isCanceling = false);
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
      builder: (context, scrollController) => Column(
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
                        child: CircularProgressIndicator(color: statusColor, strokeWidth: 2.5),
                      )
                    else
                      Icon(statusIcon, color: statusColor, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.workflowName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Build #${b.buildNumber ?? '?'} · ${b.status.toUpperCase()}',
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13),
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
                        value: b.commitHash!.length > 8 ? b.commitHash!.substring(0, 8) : b.commitHash!,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: b.commitHash!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Commit hash copied'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    _InfoRow(icon: Icons.call_split, label: 'Branch', value: b.branch ?? 'unknown'),
                  ],
                ),
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
                if (b.artifacts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Artifacts (${b.artifacts.length})',
                    children: b.artifacts.map((a) => _ArtifactRow(artifact: a)).toList(),
                  ),
                ],
                if (b.buildUrl != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _launchUrl(context, b.buildUrl!),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _isCanceling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel, color: Colors.white),
                      label: Text(
                        _isCanceling ? 'Canceling...' : 'Cancel Build',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  const _InfoRow({required this.icon, required this.label, required this.value, this.onTap});

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
              child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null)
              const Icon(Icons.copy, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ArtifactRow extends StatelessWidget {
  final CmArtifact artifact;
  const _ArtifactRow({required this.artifact});

  @override
  Widget build(BuildContext context) {
    final sizeLabel = artifact.size != null ? _formatSize(artifact.size!) : '';
    return InkWell(
      onTap: artifact.url != null ? () => _launchUrl(context, artifact.url!) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.file_download_outlined, size: 16, color: AppTheme.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(artifact.name, style: const TextStyle(fontSize: 13)),
                  if (sizeLabel.isNotEmpty)
                    Text(sizeLabel, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            if (artifact.url != null)
              const Icon(Icons.open_in_new, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
