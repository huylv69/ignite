import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_model.dart';
import '../services/build_notifier.dart';
import 'codemagic_provider.dart';

/// Builds that were running last time we looked and are not running now.
///
/// Pure so it can be tested without a clock or a network: the caller keeps
/// the previous set of running ids and hands over the fresh list.
List<CmBuild> detectFinished(Set<String> previouslyRunning, List<CmBuild> now) {
  if (previouslyRunning.isEmpty) return const [];
  return now
      .where((b) => previouslyRunning.contains(b.id) && !b.isRunning)
      .toList();
}

Set<String> runningIds(List<CmBuild> builds) =>
    builds.where((b) => b.isRunning).map((b) => b.id).toSet();

final buildNotifierProvider = Provider<BuildNotifier>((ref) => BuildNotifier());

/// The most recent build the watcher saw finish. UI listens to this for an
/// in-app banner; the native notification is posted by the watcher itself.
final lastFinishedBuildProvider = StateProvider<CmBuild?>((ref) => null);

/// Polls the team's recent builds while the app is open and reports each one
/// that stops running. Nothing is sent until a build has first been *seen*
/// running, so opening the app does not announce yesterday's results.
class BuildWatcher {
  final Ref _ref;
  Timer? _timer;
  Set<String> _running = {};
  bool _primed = false;

  static const interval = Duration(seconds: 20);

  BuildWatcher(this._ref) {
    _tick();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  Future<void> _tick() async {
    final api = _ref.read(codemagicApiProvider);
    final team = _ref.read(teamIdProvider);
    if (api == null || team == null) return;
    try {
      final builds = await api.getRecentTeamBuilds(team, pageSize: 30);
      if (_primed) {
        for (final b in detectFinished(_running, builds)) {
          _ref.read(lastFinishedBuildProvider.notifier).state = b;
          final label =
              b.isSuccess
                  ? 'passed'
                  : b.isFailed
                  ? 'failed'
                  : b.isCanceled
                  ? 'was canceled'
                  : b.status;
          await _ref
              .read(buildNotifierProvider)
              .show(
                id: b.id.hashCode & 0x7fffffff,
                title:
                    '${b.workflowName.isNotEmpty ? b.workflowName : 'Build'} $label',
                body: [
                  if (b.buildNumber != null) '#${b.buildNumber}',
                  if (b.branch != null) b.branch!,
                  if (b.commitMessage != null) b.commitMessage!,
                ].join(' · '),
              );
        }
      }
      _running = runningIds(builds);
      _primed = true;
    } catch (_) {
      // A missed poll is not worth surfacing; the next one is 20s away.
    }
  }

  void dispose() => _timer?.cancel();
}

final buildWatcherProvider = Provider<BuildWatcher>((ref) {
  final w = BuildWatcher(ref);
  ref.onDispose(w.dispose);
  // Recreate when the account changes so the running set is not carried over.
  ref.watch(codemagicApiProvider);
  return w;
});
