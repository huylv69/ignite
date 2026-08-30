import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/models/app_model.dart';
import '../../core/providers/codemagic_provider.dart';
import '../../core/theme/app_theme.dart';

/// Lists an app's build caches and lets them be cleared.
///
/// A poisoned cache is a routine CI failure, and until now clearing one meant
/// leaving the app for the Codemagic web console.
class CachesPage extends ConsumerStatefulWidget {
  final CmApplication app;

  const CachesPage({super.key, required this.app});

  @override
  ConsumerState<CachesPage> createState() => _CachesPageState();
}

class _CachesPageState extends ConsumerState<CachesPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(cachesProvider(widget.app.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(done), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final cachesAsync = ref.watch(cachesProvider(widget.app.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Caches', style: TextStyle(fontSize: 17)),
            Text(
              widget.app.appName,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if ((cachesAsync.valueOrNull ?? []).isNotEmpty)
            TextButton.icon(
              onPressed:
                  _busy
                      ? null
                      : () async {
                        final total = cachesAsync.value!.length;
                        if (!await _confirm(
                          'Clear all caches?',
                          'All $total cached entries for "${widget.app.appName}" '
                              'will be deleted. The next build repopulates them '
                              'from scratch and will be slower.',
                        )) {
                          return;
                        }
                        final api = ref.read(codemagicApiProvider);
                        if (api == null) return;
                        await _run(
                          () => api.deleteAllCaches(widget.app.id),
                          'All caches cleared.',
                        );
                      },
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Clear all'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(cachesProvider(widget.app.id)),
        child: cachesAsync.when(
          data: (caches) {
            if (caches.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 44,
                    color: AppTheme.textMuted,
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No caches stored.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              );
            }
            final totalBytes = caches.fold<int>(0, (sum, c) => sum + c.size);
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: caches.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${caches.length} cache${caches.length == 1 ? '' : 's'} · '
                      '${_formatSize(totalBytes)} total',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                }
                final c = caches[i - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CacheCard(
                    cache: c,
                    busy: _busy,
                    onDelete: () async {
                      if (!await _confirm(
                        'Delete this cache?',
                        'The cache for "${c.workflowId ?? 'this workflow'}" '
                            '(${_formatSize(c.size)}) will be deleted.',
                      )) {
                        return;
                      }
                      final api = ref.read(codemagicApiProvider);
                      if (api == null) return;
                      await _run(
                        () => api.deleteCache(widget.app.id, c.id),
                        'Cache deleted.',
                      );
                    },
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.error,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            () => ref.invalidate(cachesProvider(widget.app.id)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

class _CacheCard extends StatelessWidget {
  final CmCache cache;
  final bool busy;
  final VoidCallback onDelete;

  const _CacheCard({
    required this.cache,
    required this.busy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.archive_outlined,
                size: 18,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cache.workflowId ?? 'Unnamed workflow',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      _formatSize(cache.size),
                      if (cache.lastUsed != null)
                        'used ${timeago.format(cache.lastUsed!)}',
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppTheme.error,
              onPressed: busy ? null : onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatSize(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
