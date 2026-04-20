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
  bool _isTriggering = false;

  // Add-workflow input
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

  Future<void> _loadWorkflows() async {
    setState(() => _loading = true);

    final prefs = ref.read(sharedPreferencesProvider);
    final api = ref.read(codemagicApiProvider);

    // 1. Load cached workflow IDs for this app
    final cached = await WorkflowCache.load(prefs, widget.app.id);

    // 2. Extract unique IDs from build history (runs in background)
    List<String> fromBuilds = [];
    if (api != null) {
      try {
        final builds = await api.getBuilds(appId: widget.app.id, limit: 50);
        final seen = <String>{};
        for (final b in builds) {
          if (b.workflowId.isNotEmpty && seen.add(b.workflowId)) {
            fromBuilds.add(b.workflowId);
          }
        }
      } catch (_) {}
    }

    // 3. Merge: cached first, then build history (deduplicated)
    final all = <String, YamlWorkflow>{};
    for (final id in cached) {
      all[id] = YamlWorkflow(id: id, name: id, fromCache: true);
    }
    for (final id in fromBuilds) {
      all.putIfAbsent(id, () => YamlWorkflow(id: id, name: id));
    }

    // 4. For UI-mode apps, also add API workflows
    if (!widget.app.isFileBased) {
      for (final wf in widget.workflows) {
        all.putIfAbsent(wf.id, () => YamlWorkflow(id: wf.id, name: wf.name));
      }
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
                      onChanged: (b) { if (b != null) setState(() => _branch = b); },
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (widget.app.isFileBased)
            Container(
              width: double.infinity,
              color: AppTheme.bgElevated,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 13, color: AppTheme.accent),
                  const SizedBox(width: 6),
                  const Text(
                    'codemagic.yaml',
                    style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    ' — workflow IDs from your YAML file',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
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
                  child: Text(
                    workflow.id,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
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
