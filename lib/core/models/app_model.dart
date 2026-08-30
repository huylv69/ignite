class CmApplication {
  final String id;
  final String appName;
  final String? repositoryUrl;
  final String? teamId;
  final String? teamName;
  final String? defaultBranch;
  final List<String> branches;
  // "file" = codemagic.yaml in repo; "ui" = workflow editor on console
  final String settingsSource;
  // GitHub info for fetching codemagic.yaml
  final String? repoOwner;
  final String? repoName;
  final String? repoProvider;
  final String? lastBuildId;

  const CmApplication({
    required this.id,
    required this.appName,
    this.repositoryUrl,
    this.teamId,
    this.teamName,
    this.defaultBranch,
    this.branches = const [],
    this.settingsSource = 'ui',
    this.repoOwner,
    this.repoName,
    this.repoProvider,
    this.lastBuildId,
  });

  bool get isFileBased => settingsSource == 'file';

  factory CmApplication.fromJson(Map<String, dynamic> j) {
    final repo = j['repository'] as Map<String, dynamic>?;
    final repoUrl =
        repo?['htmlUrl'] ??
        repo?['url'] ??
        repo?['httpsUrl'] ??
        repo?['sshUrl'] ??
        repo?['cloneUrl'] ??
        j['repositoryUrl'];

    final rawBranches = j['branches'] as List? ?? [];
    final branches = rawBranches.map((b) => b.toString()).toList();

    final owner = repo?['owner'] as Map<String, dynamic>?;
    final repoOwner = owner?['name']?.toString() ?? owner?['login']?.toString();

    // Try direct field first, then extract from URL
    final repoNameRaw =
        repo?['name']?.toString() ??
        repo?['repoName']?.toString() ??
        _extractRepoName(repoUrl?.toString());

    return CmApplication(
      id: j['_id'] ?? j['id'] ?? '',
      appName: j['appName'] ?? j['name'] ?? 'Unknown App',
      repositoryUrl: repoUrl?.toString(),
      teamId: j['teamId'] ?? j['ownerTeam'],
      teamName: j['teams']?[0]?['name'],
      defaultBranch: repo?['defaultBranch'] ?? 'main',
      branches: branches,
      settingsSource: j['settingsSource']?.toString() ?? 'ui',
      repoOwner: repoOwner,
      repoName: repoNameRaw,
      repoProvider: repo?['provider']?.toString(),
      lastBuildId: j['lastBuildId']?.toString(),
    );
  }
}

String? _extractRepoName(String? url) {
  if (url == null) return null;
  // https://github.com/owner/repo or https://github.com/owner/repo.git
  // git@github.com:owner/repo.git
  try {
    final cleaned = url.replaceFirst(RegExp(r'\.git$'), '');
    final parts = cleaned
        .replaceFirst('git@github.com:', 'https://github.com/')
        .split('/');
    if (parts.length >= 2) return parts.last;
  } catch (_) {}
  return null;
}

class CmWorkflow {
  final String id;
  final String name;
  final String? environment;

  const CmWorkflow({required this.id, required this.name, this.environment});

  factory CmWorkflow.fromEntry(MapEntry<String, dynamic> e) => CmWorkflow(
    id: e.key,
    name: e.value['name'] ?? e.key,
    environment: e.value['environment']?.toString(),
  );
}

class CmBuild {
  final String id;
  final String appId;
  final String? appName;
  final String workflowId;
  final String? fileWorkflowId;
  final String workflowName;
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? branch;
  final String? commitMessage;
  final String? commitHash;
  final String? buildNumber;
  final List<CmArtifact> artifacts;
  final String? buildUrl;
  final List<CmBuildAction> buildActions;
  final String? instanceType;
  final String? tag;

  const CmBuild({
    required this.id,
    required this.appId,
    this.appName,
    required this.workflowId,
    this.fileWorkflowId,
    required this.workflowName,
    required this.status,
    this.startedAt,
    this.finishedAt,
    this.branch,
    this.commitMessage,
    this.commitHash,
    this.buildNumber,
    this.artifacts = const [],
    this.buildUrl,
    this.buildActions = const [],
    this.instanceType,
    this.tag,
  });

  factory CmBuild.fromJson(Map<String, dynamic> j) {
    final commit = j['commit'] as Map<String, dynamic>?;
    final artsRaw =
        j['artefacts'] ?? j['artifacts'] ?? j['artifactsList'] ?? [];

    final commitMsg =
        commit?['message'] ??
        commit?['commitMessage'] ??
        commit?['msg'] ??
        j['commitMessage'] ??
        j['message'];

    final commitHash =
        commit?['commitHash'] ??
        commit?['hash'] ??
        commit?['sha'] ??
        commit?['id'] ??
        j['commitHash'];

    final artsList = artsRaw as List;
    final wf = j['workflow'] as Map<String, dynamic>?;
    final workflowId =
        j['workflowId']?.toString() ??
        wf?['_id']?.toString() ??
        wf?['id']?.toString() ??
        '';
    final fileWorkflowId = j['fileWorkflowId']?.toString();
    final workflowName =
        wf?['name']?.toString() ??
        wf?['workflowName']?.toString() ??
        j['workflowName']?.toString() ??
        j['workflow_name']?.toString() ??
        fileWorkflowId ??
        workflowId;

    final arts =
        artsList
            .map((a) => CmArtifact.fromJson(a as Map<String, dynamic>))
            .toList();

    return CmBuild(
      id: j['_id'] ?? j['id'] ?? '',
      appId: j['appId'] ?? '',
      appName: j['app']?['appName'] ?? j['appName'],
      workflowId: workflowId,
      fileWorkflowId: fileWorkflowId,
      workflowName: workflowName,
      status: j['status'] ?? 'unknown',
      startedAt: _parseDate(j['startedAt'] ?? j['createdAt']),
      finishedAt: _parseDate(j['finishedAt'] ?? j['completedAt']),
      branch: j['branch'] ?? j['branchName'],
      commitMessage: commitMsg?.toString(),
      commitHash: commitHash?.toString(),
      buildNumber:
          j['buildNumber']?.toString() ??
          j['index']?.toString() ??
          j['number']?.toString(),
      artifacts: arts,
      buildUrl: j['buildUrl'] ?? j['url'],
      buildActions:
          (j['buildActions'] as List? ?? [])
              .map((a) => CmBuildAction.fromJson(a as Map<String, dynamic>))
              .toList(),
      instanceType: j['instanceType']?.toString(),
      tag: j['tag']?.toString(),
    );
  }

  Duration? get duration {
    if (startedAt == null || finishedAt == null) return null;
    return finishedAt!.difference(startedAt!);
  }

  bool get isRunning =>
      status == 'building' || status == 'preparing' || status == 'publishing';
  bool get isSuccess => status == 'finished';
  bool get isFailed => status == 'failed' || status == 'error';
  bool get isCanceled => status == 'canceled' || status == 'cancelled';

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }
}

class CmArtifact {
  final String name;
  final String? url;
  final String? type;
  final int? size;

  /// The artifact's secure filename — the `owner/build/file` segment the
  /// public-url endpoint is addressed by. Falls back to slicing it out of
  /// [url] for responses that omit the field.
  final String? path;
  final String? versionName;

  const CmArtifact({
    required this.name,
    this.url,
    this.type,
    this.size,
    this.path,
    this.versionName,
  });

  factory CmArtifact.fromJson(Map<String, dynamic> j) {
    final url =
        j['url'] ??
        j['downloadUrl'] ??
        j['artifactUrl'] ??
        j['link'] ??
        j['publicUrl'];
    return CmArtifact(
      name: j['name'] ?? j['filename'] ?? 'Unknown',
      url: url?.toString(),
      type: j['type'] ?? j['fileType'],
      size: j['size'] as int? ?? j['fileSize'] as int?,
      path: j['path']?.toString() ?? _pathFromUrl(url?.toString()),
      versionName: j['versionName']?.toString() ?? j['version']?.toString(),
    );
  }

  static String? _pathFromUrl(String? url) {
    if (url == null) return null;
    const marker = '/artifacts/';
    final i = url.indexOf(marker);
    if (i == -1) return null;
    final rest = url.substring(i + marker.length);
    return rest.isEmpty ? null : rest;
  }
}

/// One step of a build, as returned in `build.buildActions`.
class CmBuildAction {
  final String id;
  final String name;
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const CmBuildAction({
    required this.id,
    required this.name,
    required this.status,
    this.startedAt,
    this.finishedAt,
  });

  factory CmBuildAction.fromJson(Map<String, dynamic> j) => CmBuildAction(
    id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? 'Unnamed step',
    status: j['status']?.toString() ?? 'unknown',
    startedAt: CmBuild._parseDate(j['startedAt']),
    finishedAt: CmBuild._parseDate(j['finishedAt']),
  );

  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';
  bool get isSkipped => status == 'skipped';
  bool get isCanceled => status == 'canceled' || status == 'cancelled';

  Duration? get duration {
    if (startedAt == null || finishedAt == null) return null;
    return finishedAt!.difference(startedAt!);
  }
}

/// A build cache stored for an app, from `GET /apps/:id/caches`.
class CmCache {
  final String id;
  final String? appId;
  final String? workflowId;
  final int size;
  final DateTime? lastUsed;

  const CmCache({
    required this.id,
    this.appId,
    this.workflowId,
    this.size = 0,
    this.lastUsed,
  });

  factory CmCache.fromJson(Map<String, dynamic> j) => CmCache(
    id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
    appId: j['appId']?.toString(),
    workflowId: j['workflowId']?.toString(),
    size: (j['size'] as num?)?.toInt() ?? 0,
    lastUsed: CmBuild._parseDate(j['lastUsed']),
  );
}

/// An environment variable belonging to an app.
///
/// Secure values come back from the API already masked as `********`, so there
/// is no plaintext to reveal on the client.
class CmVariable {
  final String id;
  final String key;
  final String value;
  final String group;
  final bool secure;

  const CmVariable({
    this.id = '',
    required this.key,
    required this.value,
    this.group = '',
    this.secure = false,
  });

  factory CmVariable.fromJson(Map<String, dynamic> j) => CmVariable(
    id: j['id']?.toString() ?? j['_id']?.toString() ?? '',
    key: j['key']?.toString() ?? '',
    value: j['value']?.toString() ?? '',
    group: j['group']?.toString() ?? '',
    secure: j['secure'] == true,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'group': group,
    'secure': secure,
  };

  CmVariable copyWith({
    String? key,
    String? value,
    String? group,
    bool? secure,
  }) => CmVariable(
    id: id,
    key: key ?? this.key,
    value: value ?? this.value,
    group: group ?? this.group,
    secure: secure ?? this.secure,
  );
}

class BuildStats {
  final int total;
  final int succeeded;
  final int failed;
  final int running;
  final int canceled;

  const BuildStats({
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.running,
    required this.canceled,
  });

  double get successRate => total == 0 ? 0 : succeeded / total;
}
