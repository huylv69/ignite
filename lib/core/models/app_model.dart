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

  // Only the v3 API carries these; legacy responses leave them empty.
  final List<String> labels;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? commitUrl;
  final int? pullRequestNumber;
  final List<String> releaseNotes;

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
    this.labels = const [],
    this.authorName,
    this.authorAvatarUrl,
    this.commitUrl,
    this.pullRequestNumber,
    this.releaseNotes = const [],
  });

  /// Parses an item from the v3 API (`/api/v3/teams/{id}/builds`,
  /// `/api/v3/builds/{id}`), which is snake_case and resolves `workflow.name`
  /// for file-based apps — something the legacy endpoints never did.
  factory CmBuild.fromV3Json(Map<String, dynamic> j) {
    Map<String, dynamic> m(dynamic v) =>
        v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : const {};
    List<String> strs(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];

    final wf = m(j['workflow']);
    final wfId = wf['id']?.toString() ?? '';
    final isFile = wf['source'] == 'file';
    final commit = m(j['commit']);
    final pr = m(j['pull_request']);

    return CmBuild(
      id: j['id']?.toString() ?? '',
      appId: j['app_id']?.toString() ?? '',
      workflowId: wfId,
      fileWorkflowId: isFile ? wfId : null,
      workflowName: wf['name']?.toString() ?? wfId,
      status: j['status']?.toString() ?? 'unknown',
      startedAt: _parseDate(j['started_at'] ?? j['created_at']),
      finishedAt: _parseDate(j['finished_at']),
      branch: j['branch']?.toString(),
      tag: j['tag']?.toString(),
      commitMessage: commit['message']?.toString(),
      commitHash: commit['hash']?.toString(),
      commitUrl: commit['url']?.toString(),
      authorName: commit['author_name']?.toString(),
      authorAvatarUrl: commit['avatar_url']?.toString(),
      buildNumber: j['index']?.toString(),
      artifacts:
          (j['artifacts'] as List? ?? [])
              .map((a) => CmArtifact.fromV3Json(m(a)))
              .toList(),
      instanceType: j['instance_type']?.toString(),
      labels: strs(j['labels']),
      releaseNotes: strs(j['release_notes']),
      pullRequestNumber: (pr['number'] as num?)?.toInt(),
    );
  }

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

  /// v3 artifacts carry a short-lived signed url and no secure filename. The
  /// url works for a download; [path] stays null so nobody hands it to the
  /// public-url endpoint, which wants the secure filename.
  factory CmArtifact.fromV3Json(Map<String, dynamic> j) => CmArtifact(
    name: j['name']?.toString() ?? 'Unknown',
    url: j['short_lived_download_url']?.toString(),
    type: j['type']?.toString(),
    size: (j['size_in_bytes'] as num?)?.toInt(),
    versionName: j['version_name']?.toString(),
  );

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

  factory CmBuildAction.fromV3Json(Map<String, dynamic> j) => CmBuildAction(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? 'Unnamed step',
    status: j['status']?.toString() ?? 'unknown',
    startedAt: CmBuild._parseDate(j['started_at']),
    finishedAt: CmBuild._parseDate(j['finished_at']),
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

/// Build-minute quota for the signed-in account, from `GET /user`.
///
/// Codemagic reports seconds, and says nothing about when the monthly period
/// rolls over — so this carries no reset date rather than inventing one.
class CmQuota {
  final int usedSeconds;
  final int limitSeconds;
  final int previousSeconds;
  final int concurrency;

  /// Seconds per machine type, e.g. `mac_mini_m2_free`. Only non-zero entries.
  final Map<String, int> byInstanceType;

  const CmQuota({
    this.usedSeconds = 0,
    this.limitSeconds = 0,
    this.previousSeconds = 0,
    this.concurrency = 0,
    this.byInstanceType = const {},
  });

  factory CmQuota.fromUserJson(Map<String, dynamic> j) {
    // Read defensively rather than casting: this walks five levels into a
    // payload that exists to describe a user, not a quota, and a partial or
    // reshaped response should degrade to zeros instead of throwing inside a
    // provider.
    Map<String, dynamic> m(dynamic v) =>
        v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : const {};
    int n(dynamic v) => v is num ? v.toInt() : 0;

    final user = j['user'] is Map ? m(j['user']) : j;
    final bt = m(user['buildTimes']);
    final usage = m(m(user['billing'])['usage']);
    final freeLimit = m(usage['freeLimit']);

    final breakdown = <String, int>{};
    m(m(usage['currentPeriod'])['buildTime']).forEach((k, v) {
      final secs = n(v);
      if (secs > 0) breakdown[k] = secs;
    });

    final monthly = n(bt['monthlyFreeBuildTimeLimit']);

    return CmQuota(
      usedSeconds: n(m(bt['currentPeriod'])['free']),
      limitSeconds: monthly != 0 ? monthly : n(freeLimit['buildTime']),
      previousSeconds: n(m(bt['previousPeriod'])['free']),
      concurrency: n(freeLimit['concurrency']),
      byInstanceType: breakdown,
    );
  }

  /// Minutes consumed, rounded up: a build that ran 61 seconds has eaten into
  /// a second minute, and Codemagic bills it that way.
  int get usedMinutes => (usedSeconds / 60).ceil();

  int get limitMinutes => limitSeconds ~/ 60;

  /// Derived from [usedMinutes], not from the raw seconds, so the three numbers
  /// the card shows always reconcile. Flooring each independently lost a
  /// minute: 20 used + 479 left did not add up to 500.
  int get remainingMinutes =>
      limitSeconds == 0
          ? 0
          : (limitMinutes - usedMinutes).clamp(0, limitMinutes);

  /// 0..1. Zero when the account has no free-tier limit at all.
  double get fraction =>
      limitSeconds == 0 ? 0 : (usedSeconds / limitSeconds).clamp(0.0, 1.0);

  bool get hasLimit => limitSeconds > 0;
}

/// One page of `/api/v3/teams/{id}/builds`. Pagination is by cursor: pass
/// [nextCursor] back to get the page after this one; null means the end.
class CmBuildPage {
  final List<CmBuild> builds;
  final String? nextCursor;

  const CmBuildPage({required this.builds, this.nextCursor});

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  factory CmBuildPage.fromV3Json(Map<String, dynamic> j) => CmBuildPage(
    builds:
        (j['data'] as List? ?? [])
            .map((b) => CmBuild.fromV3Json(b as Map<String, dynamic>))
            .toList(),
    nextCursor: j['cursor']?.toString(),
  );
}

/// Server-side filters the v3 builds list understands.
class BuildsQuery {
  /// One of queued, building, finished, failed, canceled, timeout, skipped.
  final String? status;
  final String? branch;
  final String? tag;
  final String? workflowId;
  final List<String> labels;

  const BuildsQuery({
    this.status,
    this.branch,
    this.tag,
    this.workflowId,
    this.labels = const [],
  });

  bool get isEmpty =>
      status == null &&
      branch == null &&
      tag == null &&
      workflowId == null &&
      labels.isEmpty;

  BuildsQuery copyWith({
    Object? status = _unset,
    Object? branch = _unset,
    Object? tag = _unset,
    Object? workflowId = _unset,
    List<String>? labels,
  }) => BuildsQuery(
    status: status == _unset ? this.status : status as String?,
    branch: branch == _unset ? this.branch : branch as String?,
    tag: tag == _unset ? this.tag : tag as String?,
    workflowId: workflowId == _unset ? this.workflowId : workflowId as String?,
    labels: labels ?? this.labels,
  );

  static const _unset = Object();

  Map<String, String> toParams({
    required String appId,
    String? cursor,
    int pageSize = 30,
  }) {
    final p = <String, String>{'app_id': appId};
    if (status != null) p['status'] = status!;
    if (branch != null) p['branch'] = branch!;
    if (tag != null) p['tag'] = tag!;
    if (workflowId != null) p['workflow_id'] = workflowId!;
    // The API takes `label` repeated; a single joined value is what the
    // http package can express through a flat map, and one label at a time is
    // what the UI offers anyway.
    if (labels.isNotEmpty) p['label'] = labels.join(',');
    if (cursor != null && cursor.isNotEmpty) p['cursor'] = cursor;
    p['page_size'] = pageSize.toString();
    return p;
  }

  @override
  bool operator ==(Object other) =>
      other is BuildsQuery &&
      other.status == status &&
      other.branch == branch &&
      other.tag == tag &&
      other.workflowId == workflowId &&
      other.labels.join(',') == labels.join(',');

  @override
  int get hashCode =>
      Object.hash(status, branch, tag, workflowId, labels.join(','));
}
