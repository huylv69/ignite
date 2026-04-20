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

final workflowsProvider = FutureProvider.family<List<CmWorkflow>, String>((ref, appId) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) return [];
  return api.getWorkflows(appId);
});

final buildsProvider = FutureProvider.family<List<CmBuild>, String>((ref, appId) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) return [];
  return api.getBuilds(appId: appId, limit: 20);
});

final buildStatsProvider = FutureProvider.family<BuildStats, String>((ref, appId) async {
  final api = ref.watch(codemagicApiProvider);
  if (api == null) throw Exception('Not authenticated');
  return api.getBuildStats(appId);
});
