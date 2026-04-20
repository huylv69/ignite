import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';
import '../../core/models/app_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/codemagic_provider.dart';
import '../../core/services/workflow_cache.dart';
import '../../core/theme/app_theme.dart';

// ── Parsed workflow from codemagic.yaml ───────────────────────────────────────

class YamlWorkflow {
  final String id;
  final String name;
  final String? instanceType;
  final bool fromCache;

  const YamlWorkflow({
    required this.id,
    required this.name,
    this.instanceType,
    this.fromCache = false,
  });

  static List<YamlWorkflow> parseFromYaml(String yamlContent) {
    try {
      final doc = loadYaml(yamlContent);
      if (doc is! YamlMap) return [];
      final workflows = doc['workflows'];
      if (workflows is! YamlMap) return [];
      return workflows.entries.map((e) {
        final wf = e.value as YamlMap?;
        return YamlWorkflow(
          id: e.key.toString(),
          name: wf?['name']?.toString() ?? e.key.toString(),
          instanceType: wf?['instance_type']?.toString(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class YamlTriggerPage extends ConsumerStatefulWidget {
  final CmApplication app;
  final List<CmWorkflow> workflows;

  const YamlTriggerPage({super.key, required this.app, required this.workflows});

  @override
  ConsumerState<YamlTriggerPage> createState() => _YamlTriggerPageState();
}

class _YamlTriggerPageState extends ConsumerState<YamlTriggerPage> {
  bool _loading = true;
  List<YamlWorkflow> _workflows = [];
  YamlWorkflow? _selected;
  String _branch = 'main';
  String? _loadingBranch; // guard against stale responses
  bool _isTriggering = false;

  final _addController = TextEditingController();
  bool _showAddField = false;

  @override
  void initState() {
    super.initState();
    _branch = widget.app.defaultBranch ?? 'main';
    _loadWorkflows();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  String? _yamlError;

  Future<void> _loadWorkflows() async {
    final requestBranch = _branch;
    setState(() { _loading = true; _yamlError = null; _loadingBranch = requestBranch; });

    final api = ref.read(codemagicApiProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    // 1. File-based apps: fetch & parse codemagic.yaml from the selected branch
    if (widget.app.isFileBased && api != null) {
      final resolution = await api.resolveFileWorkflows(
        appId: widget.app.id,
        branch: _branch,
        owner: widget.app.repoOwner,
        repo: widget.app.repoName,
      );

      if (!mounted || _loadingBranch != requestBranch) return;

      if (resolution.yaml != null) {
        final parsed = YamlWorkflow.parseFromYaml(resolution.yaml!);
        setState(() {
          _loading = false;
          _workflows = parsed;
          _selected = parsed.isNotEmpty ? parsed.first : null;
        });
        return;
      }

      if (resolution.workflowIds != null) {
        final wfs = resolution.workflowIds!
            .map((id) => YamlWorkflow(id: id, name: id))
            .toList();
        setState(() {
          _loading = false;
          _workflows = wfs;
          _selected = wfs.isNotEmpty ? wfs.first : null;
        });
        return;
      }

      _yamlError = 'Could not fetch codemagic.yaml — private or non-GitHub repo. Showing workflows from build history.';
    }

    // 2. Non-file-based apps: use API workflows
    if (!widget.app.isFileBased) {
      final wfs = widget.workflows
          .map((wf) => YamlWorkflow(id: wf.id, name: wf.name))
          .toList();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _workflows = wfs;
        _selected = wfs.isNotEmpty ? wfs.first : null;
      });
      return;
    }

    // 3. Fallback: build history (use fileWorkflowId for file-based apps)
    final cached = await WorkflowCache.load(prefs, widget.app.id);
    final all = <String, YamlWorkflow>{};
    for (final id in cached) {
      all[id] = YamlWorkflow(id: id, name: id, fromCache: true);
    }

    if (api != null) {
      try {
        final builds = await api.getBuilds(appId: widget.app.id, limit: 100);
        final seen = <String>{};
        for (final b in builds) {
          // For file-based apps, fileWorkflowId is the YAML key (e.g. "ios-workflow")
          final id = (widget.app.isFileBased ? b.fileWorkflowId : null)
              ?? (b.workflowId.length < 30 ? b.workflowId : null); // skip UUIDs
          if (id != null && id.isNotEmpty && seen.add(id)) {
            all.putIfAbsent(id, () => YamlWorkflow(
              id: id,
              name: b.workflowName != b.workflowId ? b.workflowName : id,
            ));
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _workflows = all.values.toList();
      _selected = _workflows.isNotEmpty ? _workflows.first : null;
    });
  }

  Future<void> _addWorkflow(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await WorkflowCache.add(prefs, widget.app.id, trimmed);
    final wf = YamlWorkflow(id: trimmed, name: trimmed, fromCache: true);
    setState(() {
      _workflows = [wf, ..._workflows.where((w) => w.id != trimmed)];
      _selected = wf;
      _showAddField = false;
      _addController.clear();
    });
  }

  Future<void> _removeWorkflow(YamlWorkflow wf) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await WorkflowCache.remove(prefs, widget.app.id, wf.id);
    setState(() {
      _workflows = _workflows.where((w) => w.id != wf.id).toList();
      if (_selected?.id == wf.id) _selected = _workflows.isNotEmpty ? _workflows.first : null;
    });
  }

  Future<void> _trigger() async {
    if (_selected == null) return;
    setState(() => _isTriggering = true);

    // Save to cache so next time it's remembered
    final prefs = ref.read(sharedPreferencesProvider);
    await WorkflowCache.add(prefs, widget.app.id, _selected!.id);

    try {
      final api = ref.read(codemagicApiProvider);
      if (api == null) return;
      await api.triggerBuild(
        appId: widget.app.id,
        workflowId: _selected!.id,
        branch: _branch,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Build triggered: ${_selected!.id} @ $_branch'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isTriggering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trigger Build — ${widget.app.appName}'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branch selector
          Container(
            color: AppTheme.bgCard,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.call_split, size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                const Text('Branch:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.app.branches.contains(_branch) ? _branch : null,
                      hint: Text(_branch, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                      isDense: true,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      dropdownColor: AppTheme.bgElevated,
                      items: widget.app.branches
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (b) {
                        if (b != null) {
                          setState(() => _branch = b);
                          _loadWorkflows();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (widget.app.isFileBased)
            Container(
              width: double.infinity,
              color: _yamlError != null ? AppTheme.error.withValues(alpha: 0.12) : AppTheme.bgElevated,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _yamlError != null ? Icons.warning_amber_rounded : Icons.description_outlined,
                    size: 13,
                    color: _yamlError != null ? AppTheme.error : AppTheme.accent,
                  ),
                  const SizedBox(width: 6),
                  if (_yamlError == null) ...[
                    const Text('codemagic.yaml', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                    const Text(' — workflows loaded from YAML', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ] else
                    Expanded(child: Text(_yamlError!, style: const TextStyle(color: AppTheme.error, fontSize: 12))),
                  if (_yamlError != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: _loadWorkflows,
                      child: const Text('Retry', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'SELECT WORKFLOW',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 1),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() => _showAddField = !_showAddField),
                            icon: Icon(_showAddField ? Icons.close : Icons.add, size: 16, color: AppTheme.primary),
                            label: Text(
                              _showAddField ? 'Cancel' : 'Add Workflow',
                              style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),

                      if (_showAddField) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _addController,
                                autofocus: true,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'e.g.  android-workflow',
                                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontFamily: 'monospace'),
                                  prefixIcon: const Icon(Icons.code, size: 18, color: AppTheme.textMuted),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.border),
                                  ),
                                ),
                                onSubmitted: _addWorkflow,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _addWorkflow(_addController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Add', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_workflows.isEmpty)
                        _EmptyWorkflows(onAdd: () => setState(() => _showAddField = true))
                      else
                        ..._workflows.map((wf) => _WorkflowTile(
                              workflow: wf,
                              isSelected: _selected?.id == wf.id,
                              onTap: () => setState(() => _selected = wf),
                              onDelete: wf.fromCache ? () => _removeWorkflow(wf) : null,
                            )),
                    ],
                  ),
          ),

          // Trigger button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_selected == null || _isTriggering) ? null : _trigger,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor: AppTheme.bgCard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isTriggering
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.local_fire_department_rounded, color: Colors.white),
                label: Text(
                  _isTriggering
                      ? 'Triggering…'
                      : _selected == null
                          ? 'Select a workflow first'
                          : 'Run  ${_selected!.id}  @  $_branch',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _WorkflowTile extends StatelessWidget {
  final YamlWorkflow workflow;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _WorkflowTile({
    required this.workflow,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustomName = workflow.name != workflow.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasCustomName)
                        Text(
                          workflow.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          ),
                        ),
                      Text(
                        workflow.id,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: hasCustomName ? 11 : 14,
                          fontWeight: hasCustomName ? FontWeight.normal : FontWeight.w600,
                          color: hasCustomName ? AppTheme.textMuted : (isSelected ? AppTheme.textPrimary : AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                if (workflow.instanceType != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      workflow.instanceType!,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ),
                if (onDelete != null)
                  GestureDetector(
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyWorkflows extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyWorkflows({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.description_outlined, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text(
            'No workflows yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add the workflow ID from your codemagic.yaml\n(e.g.  android-workflow)',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Workflow ID', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
