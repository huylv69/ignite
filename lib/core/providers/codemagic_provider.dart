import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/codemagic_api.dart';
import '../models/app_model.dart';
import 'accounts_provider.dart';

final codemagicApiProvider = Provider<CodemagicApi?>((ref) {
  final token = ref.watch(activeTokenProvider);
  if (token == null || token.isEmpty) return null;
  return CodemagicApi(token);
});

final appsProvider = FutureProvider<List<CmApplication>>((ref) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) return [];
  return api.getApplications();
});

final workflowsProvider = FutureProvider.family<List<CmWorkflow>, String>((
  ref,
  appId,
) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) return [];
  return api.getWorkflows(appId);
});

final buildsProvider = FutureProvider.family<List<CmBuild>, String>((
  ref,
  appId,
) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) return [];
  return api.getBuilds(appId: appId, limit: 20);
});

final buildStatsProvider = FutureProvider.family<BuildStats, String>((
  ref,
  appId,
) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) throw Exception('Not authenticated');
  return api.getBuildStats(appId);
});

// ── Build detail & step logs ─────────────────────────────────────────────────

final buildDetailProvider = FutureProvider.family<CmBuild, String>((
  ref,
  buildId,
) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) throw Exception('Not authenticated');
  return api.getBuildDetail(buildId);
});

/// Identifies one step's log. Value equality keeps the family from refetching
/// the same log on every rebuild.
class StepLogRef {
  final String buildId;
  final String stepId;
  const StepLogRef(this.buildId, this.stepId);

  @override
  bool operator ==(Object other) =>
      other is StepLogRef && other.buildId == buildId && other.stepId == stepId;

  @override
  int get hashCode => Object.hash(buildId, stepId);
}

final stepLogProvider = FutureProvider.family<String, StepLogRef>((
  ref,
  key,
) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) throw Exception('Not authenticated');
  return api.getStepLog(key.buildId, key.stepId);
});

// ── Caches & variables ───────────────────────────────────────────────────────

final cachesProvider = FutureProvider.family<List<CmCache>, String>((
  ref,
  appId,
) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) return [];
  return api.getCaches(appId);
});

final variablesProvider = FutureProvider.family<List<CmVariable>, String>((
  ref,
  appId,
) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) return [];
  return api.getVariables(appId);
});

// ── Home screen: search and last-build status ────────────────────────────────

/// Filters apps by name or repository URL. Pure so it can be tested directly.
List<CmApplication> filterApps(List<CmApplication> apps, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return apps;
  return apps.where((a) {
    final name = a.appName.toLowerCase();
    final repo = (a.repositoryUrl ?? '').toLowerCase();
    return name.contains(q) || repo.contains(q);
  }).toList();
}

final appSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredAppsProvider = Provider<AsyncValue<List<CmApplication>>>((ref) {
  final apps = ref.watch(appsProvider);
  final query = ref.watch(appSearchQueryProvider);
  return apps.whenData((list) => filterApps(list, query));
});

/// Newest build per app, from one v3 team request rather than one per app.
/// Falls back to the legacy list until the team id is known.
final latestBuildsProvider = FutureProvider<Map<String, CmBuild>>((ref) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) return {};
  final team = ref.watch(teamIdProvider);
  final builds =
      team != null
          ? await api.getRecentTeamBuilds(team, pageSize: 50)
          : await api.getBuilds(limit: 100);
  final latest = <String, CmBuild>{};
  for (final b in builds) {
    final existing = latest[b.appId];
    if (existing == null) {
      latest[b.appId] = b;
      continue;
    }
    final a = b.startedAt;
    final e = existing.startedAt;
    if (a != null && (e == null || a.isAfter(e))) latest[b.appId] = b;
  }
  return latest;
});

/// Build-minute quota for the active account.
final quotaProvider = FutureProvider<CmQuota>((ref) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) throw Exception('Not authenticated');
  return api.getQuota();
});

// ── v3: team id, paged builds, steps ─────────────────────────────────────────

/// The team every v3 list is scoped to. v3 `/user` does not say, and for a
/// personal account `/user/teams` is empty — but legacy `/apps` (which does
/// send CORS headers) carries `ownerTeam` on each app, so that is the source.
final teamIdProvider = Provider<String?>((ref) {
  final apps = ref.watch(appsProvider).valueOrNull;
  if (apps == null) return null;
  for (final a in apps) {
    if (a.teamId != null && a.teamId!.isNotEmpty) return a.teamId;
  }
  return null;
});

/// Steps for a build via v3 — the same list the legacy detail carries as
/// `buildActions`, but readable from a browser.
final buildActionsProvider = FutureProvider.family<List<CmBuildAction>, String>(
  (ref, buildId) async {
    final api = ref.watch(codemagicApiProvider);
    if (api == null) throw Exception('Not authenticated');
    return api.getBuildActions(buildId);
  },
);

class BuildsFeedState {
  final List<CmBuild> builds;
  final String? cursor;
  final bool loadingFirst;
  final bool loadingMore;
  final Object? error;
  final BuildsQuery query;

  const BuildsFeedState({
    this.builds = const [],
    this.cursor,
    this.loadingFirst = true,
    this.loadingMore = false,
    this.error,
    this.query = const BuildsQuery(),
  });

  bool get hasMore => cursor != null && cursor!.isNotEmpty;
  bool get hasRunning => builds.any((b) => b.isRunning);

  BuildsFeedState copyWith({
    List<CmBuild>? builds,
    Object? cursor = _unset,
    bool? loadingFirst,
    bool? loadingMore,
    Object? error = _unset,
    BuildsQuery? query,
  }) => BuildsFeedState(
    builds: builds ?? this.builds,
    cursor: cursor == _unset ? this.cursor : cursor as String?,
    loadingFirst: loadingFirst ?? this.loadingFirst,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error == _unset ? this.error : error,
    query: query ?? this.query,
  );

  static const _unset = Object();
}

/// An app's build list as an append-only feed: first page on creation, more
/// pages on demand, and a filter change that starts over from the top.
class BuildsFeedNotifier extends StateNotifier<BuildsFeedState> {
  final CodemagicApi? _api;
  final String? _teamId;
  final String _appId;
  int _generation = 0;

  BuildsFeedNotifier(this._api, this._teamId, this._appId)
    : super(const BuildsFeedState()) {
    refresh();
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    final api = _api;
    final team = _teamId;
    if (api == null || team == null) {
      state = state.copyWith(
        loadingFirst: false,
        error: 'Not authenticated',
        builds: const [],
        cursor: null,
      );
      return;
    }
    // Keep what is on screen while the fresh page loads; a refresh should not
    // blank the list.
    state = state.copyWith(loadingFirst: state.builds.isEmpty, error: null);
    try {
      final page = await api.getTeamBuilds(
        teamId: team,
        appId: _appId,
        query: state.query,
      );
      if (gen != _generation) return;
      state = state.copyWith(
        builds: page.builds,
        cursor: page.nextCursor,
        loadingFirst: false,
        error: null,
      );
    } catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loadingFirst: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.loadingFirst) return;
    final api = _api;
    final team = _teamId;
    if (api == null || team == null) return;
    final gen = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await api.getTeamBuilds(
        teamId: team,
        appId: _appId,
        query: state.query,
        cursor: state.cursor,
      );
      if (gen != _generation) return;
      state = state.copyWith(
        builds: [...state.builds, ...page.builds],
        cursor: page.nextCursor,
        loadingMore: false,
      );
    } catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }

  void setQuery(BuildsQuery q) {
    if (q == state.query) return;
    state = state.copyWith(query: q, builds: const [], cursor: null);
    refresh();
  }
}

final buildsFeedProvider =
    StateNotifierProvider.family<BuildsFeedNotifier, BuildsFeedState, String>(
      (ref, appId) => BuildsFeedNotifier(
        ref.watch(codemagicApiProvider),
        ref.watch(teamIdProvider),
        appId,
      ),
    );
