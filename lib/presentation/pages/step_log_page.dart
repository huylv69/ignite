import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_model.dart';
import '../../core/providers/codemagic_provider.dart';
import '../../core/theme/app_theme.dart';

/// Shows one build step's raw log.
///
/// The API serves this as `text/plain` from `/builds/:id/step/:stepId`, so
/// there is nothing to parse — it is rendered as-is, selectable, in a
/// horizontally scrollable monospace block so long lines are not wrapped into
/// nonsense.
class StepLogPage extends ConsumerWidget {
  final String buildId;
  final CmBuildAction step;

  const StepLogPage({super.key, required this.buildId, required this.step});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(stepLogProvider(StepLogRef(buildId, step.id)));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.name,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              step.status,
              style: TextStyle(
                fontSize: 11,
                color: _statusColor(step),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copy log',
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed:
                logAsync.valueOrNull == null
                    ? null
                    : () {
                      Clipboard.setData(ClipboardData(text: logAsync.value!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Log copied'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed:
                () => ref.invalidate(
                  stepLogProvider(StepLogRef(buildId, step.id)),
                ),
          ),
        ],
      ),
      body: logAsync.when(
        data: (log) {
          if (log.trim().isEmpty) {
            return const Center(
              child: Text(
                'This step produced no output.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          return Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  log,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.45,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
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
                      'Could not load this log.\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          () => ref.invalidate(
                            stepLogProvider(StepLogRef(buildId, step.id)),
                          ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  static Color _statusColor(CmBuildAction a) {
    if (a.isSuccess) return AppTheme.success;
    if (a.isFailed) return AppTheme.error;
    if (a.isSkipped) return AppTheme.textMuted;
    if (a.isCanceled) return AppTheme.textMuted;
    return AppTheme.warning;
  }
}
