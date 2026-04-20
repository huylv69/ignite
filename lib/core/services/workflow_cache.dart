import 'package:shared_preferences/shared_preferences.dart';

/// Persists workflow IDs per app so file-based private repos don't need
/// YAML re-fetch after first manual entry.
class WorkflowCache {
  static const _prefix = 'wf_cache_';

  static String _key(String appId) => '$_prefix$appId';

  static Future<List<String>> load(SharedPreferences prefs, String appId) {
    final raw = prefs.getStringList(_key(appId)) ?? [];
    return Future.value(raw);
  }

  static Future<void> add(SharedPreferences prefs, String appId, String workflowId) async {
    final current = prefs.getStringList(_key(appId)) ?? [];
    if (!current.contains(workflowId)) {
      await prefs.setStringList(_key(appId), [workflowId, ...current]);
    }
  }

  static Future<void> remove(SharedPreferences prefs, String appId, String workflowId) async {
    final current = prefs.getStringList(_key(appId)) ?? [];
    await prefs.setStringList(_key(appId), current.where((e) => e != workflowId).toList());
  }
}
