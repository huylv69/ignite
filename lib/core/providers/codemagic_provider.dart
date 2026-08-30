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

/// Newest build per app, from a single unfiltered request rather than one per
/// app. Builds age out of this endpoint, so an app missing here has simply not
/// built recently — it is not an error.
final latestBuildsProvider = FutureProvider<Map<String, CmBuild>>((ref) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) return {};
  final builds = await api.getBuilds(limit: 100);
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
