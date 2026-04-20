import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/app_model.dart';

class CodemagicApiException implements Exception {
  final int statusCode;
  final String message;
  const CodemagicApiException(this.statusCode, this.message);
  @override
  String toString() => 'CodemagicApiException($statusCode): $message';
}

class CodemagicApi {
  static const String _base = 'https://api.codemagic.io';
  final String token;

  CodemagicApi(this.token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-auth-token': token,
      };

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    return _handle(res);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.post(uri, headers: _headers, body: jsonEncode(body));
    return _handle(res);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.delete(uri, headers: _headers);
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw CodemagicApiException(res.statusCode, body['message']?.toString() ?? 'Error');
    }
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Map<String, dynamic> _handle(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw CodemagicApiException(res.statusCode, body['message']?.toString() ?? 'HTTP ${res.statusCode}');
    }
    debugPrint('[Ignite API] ${res.request?.url}\n${res.body.substring(0, res.body.length.clamp(0, 1200))}');
    return body;
  }

  Future<String> getRawJson(String path) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.get(uri, headers: _headers);
    return res.body;
  }

  // ── Applications ─────────────────────────────────────────────────────────

  Future<List<CmApplication>> getApplications() async {
    final data = await _get('/apps');
    final apps = data['applications'] as List? ?? [];
    return apps.map((a) => CmApplication.fromJson(a as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getApplication(String appId) async {
    return await _get('/apps/$appId');
  }

  Future<List<CmWorkflow>> getWorkflows(String appId) async {
    final data = await getApplication(appId);
    final workflows = data['application']?['workflows'] as Map<String, dynamic>? ?? {};
    return workflows.entries.map((e) => CmWorkflow.fromEntry(e)).toList();
  }

  // ── Builds ────────────────────────────────────────────────────────────────

  Future<List<CmBuild>> getBuilds({
    String? appId,
    int? limit,
    String? workflowId,
    String? status,
    int page = 0,
  }) async {
    final params = <String, String>{};
    if (appId != null) params['appId'] = appId;
    if (limit != null) params['limit'] = limit.toString();
    if (workflowId != null) params['workflowId'] = workflowId;
    if (status != null) params['status'] = status;
    if (page > 0) params['page'] = page.toString();

    final data = await _get('/builds', params: params);
    final builds = data['builds'] as List? ?? [];
    return builds.map((b) => CmBuild.fromJson(b as Map<String, dynamic>)).toList();
  }

  Future<CmBuild> getBuild(String buildId) async {
    final data = await _get('/builds/$buildId');
    return CmBuild.fromJson(data['build'] as Map<String, dynamic>);
  }

  Future<String> triggerBuild({
    required String appId,
    required String workflowId,
    String branch = 'main',
    Map<String, String>? environment,
  }) async {
    final body = <String, dynamic>{
      'appId': appId,
      'workflowId': workflowId,
      'branch': branch,
    };
    if (environment != null && environment.isNotEmpty) {
      body['environment'] = {'variables': environment};
    }
    final data = await _post('/builds', body);
    return data['buildId'] as String? ?? data['_id'] as String? ?? '';
  }

  Future<void> cancelBuild(String buildId) async {
    await _delete('/builds/$buildId');
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<BuildStats> getBuildStats(String appId) async {
    final builds = await getBuilds(appId: appId, limit: 100);
    int succeeded = 0, failed = 0, running = 0, canceled = 0;
    for (final b in builds) {
      if (b.isSuccess) { succeeded++; }
      else if (b.isFailed) { failed++; }
      else if (b.isRunning) { running++; }
      else if (b.isCanceled) { canceled++; }
    }
    return BuildStats(
      total: builds.length,
      succeeded: succeeded,
      failed: failed,
      running: running,
      canceled: canceled,
    );
  }

  // ── User ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUser() async {
    return await _get('/user');
  }

  // ── File-based workflow resolution ────────────────────────────────────────

  /// Resolves workflows for a file-based app via the official internal endpoint.
  Future<YamlResolution> resolveFileWorkflows({
    required String appId,
    required String branch,
    String? owner,
    String? repo,
  }) async {
    // 1. Official endpoint used by Codemagic web console
    try {
      final uri = Uri.parse('$_base/apps/$appId/fetch-file-configuration');
      final res = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({'branch': branch, 'commitHash': null, 'tag': null}),
      );
      debugPrint('[fetch-file-configuration] → ${res.statusCode} ${res.body.substring(0, res.body.length.clamp(0, 400))}');
      if (res.statusCode == 200) {
        final body = res.body.trim();
        // Raw YAML
        if (body.startsWith('workflows:') || body.contains('\nworkflows:')) {
          return YamlResolution.yaml(body);
        }
        // JSON wrapper
        if (body.startsWith('{')) {
          final j = jsonDecode(body) as Map<String, dynamic>;
          final yaml = j['yaml'] ?? j['content'] ?? j['fileContent'] ?? j['configuration'];
          if (yaml is String && yaml.trim().isNotEmpty) return YamlResolution.yaml(yaml);
          final ids = j['workflowIds'] ?? j['fileWorkflowIds'];
          if (ids is List && ids.isNotEmpty) {
            return YamlResolution.ids(ids.map((e) => e.toString()).toList());
          }
        }
      }
    } catch (e) {
      debugPrint('[fetch-file-configuration] error: $e');
    }

    // 2. Fallback: GitHub raw (public repos only)
    if (owner != null && repo != null) {
      try {
        final url = 'https://raw.githubusercontent.com/$owner/$repo/$branch/codemagic.yaml';
        final res = await http.get(Uri.parse(url));
        debugPrint('[github-raw] → ${res.statusCode}');
        if (res.statusCode == 200) return YamlResolution.yaml(res.body);
      } catch (_) {}
    }

    return YamlResolution.failed();
  }
}

class YamlResolution {
  final String? yaml;
  final List<String>? workflowIds;
  final bool failed;

  const YamlResolution._({this.yaml, this.workflowIds, this.failed = false});
  factory YamlResolution.yaml(String y) => YamlResolution._(yaml: y);
  factory YamlResolution.ids(List<String> ids) => YamlResolution._(workflowIds: ids);
  factory YamlResolution.failed() => YamlResolution._(failed: true);
}
