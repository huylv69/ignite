import 'dart:convert';
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

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? params,
  }) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    return _handle(res);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.post(uri, headers: _headers, body: jsonEncode(body));
    return _handle(res);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.delete(uri, headers: _headers);
    if (res.statusCode >= 400) {
      throw CodemagicApiException(res.statusCode, _messageOf(res));
    }
    // Cache deletion answers 202 and may return a non-map body.
    if (res.body.isEmpty) return {};
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Map<String, dynamic> _handle(http.Response res) {
    if (res.statusCode >= 400) {
      throw CodemagicApiException(res.statusCode, _messageOf(res));
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Reads the error text out of a failed response without assuming it is JSON.
  String _messageOf(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['message']?.toString() ??
          body['error']?.toString() ??
          'HTTP ${res.statusCode}';
    } catch (_) {
      return 'HTTP ${res.statusCode}';
    }
  }

  // ── Applications ─────────────────────────────────────────────────────────

  Future<List<CmApplication>> getApplications() async {
    final data = await _get('/apps');
    final apps = data['applications'] as List? ?? [];
    return apps
        .map((a) => CmApplication.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getApplication(String appId) async {
    return await _get('/apps/$appId');
  }

  Future<List<CmWorkflow>> getWorkflows(String appId) async {
    final data = await getApplication(appId);
    final workflows =
        data['application']?['workflows'] as Map<String, dynamic>? ?? {};
    return workflows.entries.map((e) => CmWorkflow.fromEntry(e)).toList();
  }

  // ── Builds ────────────────────────────────────────────────────────────────

  /// The API ignores `page`; `skip` is what actually paginates.
  Future<List<CmBuild>> getBuilds({
    String? appId,
    int? limit,
    String? workflowId,
    String? status,
    String? branch,
    int skip = 0,
  }) async {
    final params = <String, String>{};
    if (appId != null) params['appId'] = appId;
    if (limit != null) params['limit'] = limit.toString();
    if (workflowId != null) params['workflowId'] = workflowId;
    if (status != null) params['status'] = status;
    if (branch != null) params['branch'] = branch;
    if (skip > 0) params['skip'] = skip.toString();

    final data = await _get('/builds', params: params);
    final builds = data['builds'] as List? ?? [];
    return builds
        .map((b) => CmBuild.fromJson(b as Map<String, dynamic>))
        .toList();
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

  /// Cancels a running build.
  ///
  /// The API rejects `DELETE /builds/:id` with 405 — cancelling is a POST to a
  /// dedicated path. A 208 means the build had already finished, which is a
  /// no-op rather than a failure.
  Future<void> cancelBuild(String buildId) async {
    final uri = Uri.parse('$_base/builds/$buildId/cancel');
    final res = await http.post(uri, headers: _headers);
    if (res.statusCode == 208) return;
    if (res.statusCode >= 400) {
      throw CodemagicApiException(res.statusCode, _messageOf(res));
    }
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<BuildStats> getBuildStats(String appId) async {
    final builds = await getBuilds(appId: appId, limit: 100);
    int succeeded = 0, failed = 0, running = 0, canceled = 0;
    for (final b in builds) {
      if (b.isSuccess) {
        succeeded++;
      } else if (b.isFailed) {
        failed++;
      } else if (b.isRunning) {
        running++;
      } else if (b.isCanceled) {
        canceled++;
      }
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

  /// Resolves workflows for a file-based app via GitHub raw (public repos only).
  Future<YamlResolution> resolveFileWorkflows({
    required String appId,
    required String branch,
    String? owner,
    String? repo,
  }) async {
    if (owner != null && repo != null) {
      try {
        final url =
            'https://raw.githubusercontent.com/$owner/$repo/$branch/codemagic.yaml';
        final res = await http.get(Uri.parse(url));
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
  final String? detail;

  const YamlResolution._({
    this.yaml,
    this.workflowIds,
    this.failed = false,
    this.detail,
  });
  factory YamlResolution.yaml(String y) => YamlResolution._(yaml: y);
  factory YamlResolution.ids(List<String> ids) =>
      YamlResolution._(workflowIds: ids);
  factory YamlResolution.failed({String? detail}) =>
      YamlResolution._(failed: true, detail: detail);
}
