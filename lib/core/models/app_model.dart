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
  });

  bool get isFileBased => settingsSource == 'file';

  factory CmApplication.fromJson(Map<String, dynamic> j) {
    final repo = j['repository'] as Map<String, dynamic>?;
    final repoUrl = repo?['htmlUrl']
        ?? repo?['url']
        ?? repo?['httpsUrl']
        ?? repo?['sshUrl']
        ?? repo?['cloneUrl']
        ?? j['repositoryUrl'];

    final rawBranches = j['branches'] as List? ?? [];
    final branches = rawBranches.map((b) => b.toString()).toList();

    final owner = repo?['owner'] as Map<String, dynamic>?;
    final repoOwner = owner?['name']?.toString() ?? owner?['login']?.toString();

    // Try direct field first, then extract from URL
    final repoNameRaw = repo?['name']?.toString()
        ?? repo?['repoName']?.toString()
        ?? _extractRepoName(repoUrl?.toString());

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
    );
  }
}

String? _extractRepoName(String? url) {
  if (url == null) return null;
  // https://github.com/owner/repo or https://github.com/owner/repo.git
  // git@github.com:owner/repo.git
  try {
    final cleaned = url.replaceFirst(RegExp(r'\.git$'), '');
    final parts = cleaned.replaceFirst('git@github.com:', 'https://github.com/').split('/');
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
  });

  factory CmBuild.fromJson(Map<String, dynamic> j) {
    final commit = j['commit'] as Map<String, dynamic>?;
    final artsRaw = j['artefacts'] ?? j['artifacts'] ?? j['artifactsList'] ?? [];

    final commitMsg = commit?['message']
        ?? commit?['commitMessage']
        ?? commit?['msg']
        ?? j['commitMessage']
        ?? j['message'];

    final commitHash = commit?['commitHash']
        ?? commit?['hash']
        ?? commit?['sha']
        ?? commit?['id']
        ?? j['commitHash'];

    final artsList = artsRaw as List;
    final wf = j['workflow'] as Map<String, dynamic>?;
    final workflowId = j['workflowId']?.toString()
        ?? wf?['_id']?.toString()
        ?? wf?['id']?.toString()
        ?? '';
    final fileWorkflowId = j['fileWorkflowId']?.toString();
    final workflowName = wf?['name']?.toString()
        ?? wf?['workflowName']?.toString()
        ?? j['workflowName']?.toString()
        ?? j['workflow_name']?.toString()
        ?? fileWorkflowId
        ?? workflowId;

    final arts = artsList
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
      buildNumber: j['buildNumber']?.toString() ?? j['index']?.toString() ?? j['number']?.toString(),
      artifacts: arts,
      buildUrl: j['buildUrl'] ?? j['url'],
    );
  }

  Duration? get duration {
    if (startedAt == null || finishedAt == null) return null;
    return finishedAt!.difference(startedAt!);
  }

  bool get isRunning => status == 'building' || status == 'preparing' || status == 'publishing';
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

  const CmArtifact({required this.name, this.url, this.type, this.size});

  factory CmArtifact.fromJson(Map<String, dynamic> j) {
    final url = j['url']
        ?? j['downloadUrl']
        ?? j['artifactUrl']
        ?? j['link']
        ?? j['publicUrl'];
    return CmArtifact(
      name: j['name'] ?? j['filename'] ?? 'Unknown',
      url: url?.toString(),
      type: j['type'] ?? j['fileType'],
      size: j['size'] as int? ?? j['fileSize'] as int?,
    );
  }
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
