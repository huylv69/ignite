import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_model.dart';
import '../../core/providers/codemagic_provider.dart';
import '../../core/theme/app_theme.dart';

/// Manages an app's environment variables, grouped the way Codemagic groups
/// them.
///
/// Secure values arrive from the API already masked as `********`, so there is
/// no plaintext to reveal — editing one replaces it rather than showing it.
class VariablesPage extends ConsumerStatefulWidget {
  final CmApplication app;

  const VariablesPage({super.key, required this.app});

  @override
  ConsumerState<VariablesPage> createState() => _VariablesPageState();
}

class _VariablesPageState extends ConsumerState<VariablesPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(variablesProvider(widget.app.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(done), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit({CmVariable? existing}) async {
    final result = await showDialog<CmVariable>(
      context: context,
      builder: (_) => _VariableDialog(existing: existing),
    );
    if (result == null) return;

    final api = ref.read(codemagicApiProvider);
    if (api == null) return;
    if (existing == null) {
      await _run(
        () => api.addVariable(widget.app.id, result),
        'Variable added.',
      );
    } else {
      await _run(
        () => api.updateVariable(widget.app.id, result),
        'Variable updated.',
      );
    }
  }

  Future<void> _delete(CmVariable v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: const Text('Delete variable?'),
            content: Text(
              '"${v.key}" will be removed from ${widget.app.appName}. '
              'Builds relying on it will start failing.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok != true) return;

    final api = ref.read(codemagicApiProvider);
    if (api == null) return;
    await _run(
      () => api.deleteVariable(widget.app.id, v.id),
      'Variable deleted.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final varsAsync = ref.watch(variablesProvider(widget.app.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Environment variables', style: TextStyle(fontSize: 17)),
            Text(
              widget.app.appName,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _edit(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(variablesProvider(widget.app.id)),
        child: varsAsync.when(
          data: (vars) {
            if (vars.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(
                    Icons.data_object_rounded,
                    size: 44,
                    color: AppTheme.textMuted,
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No environment variables yet.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              );
            }

            final groups = <String, List<CmVariable>>{};
            for (final v in vars) {
              groups
                  .putIfAbsent(
                    v.group.isEmpty ? 'Ungrouped' : v.group,
                    () => [],
                  )
                  .add(v);
            }
            final names = groups.keys.toList()..sort();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                for (final g in names) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.folder_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          g,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${groups[g]!.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...groups[g]!.map(
                    (v) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _VariableCard(
                        variable: v,
                        busy: _busy,
                        onEdit: () => _edit(existing: v),
                        onDelete: () => _delete(v),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.error,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            () => ref.invalidate(
                              variablesProvider(widget.app.id),
                            ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

class _VariableCard extends StatelessWidget {
  final CmVariable variable;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VariableCard({
    required this.variable,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: busy ? null : onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                variable.secure ? Icons.lock_outline : Icons.key_outlined,
                size: 18,
                color: variable.secure ? AppTheme.warning : AppTheme.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variable.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      variable.secure ? '••••••••' : variable.value,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppTheme.error,
                onPressed: busy ? null : onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariableDialog extends StatefulWidget {
  final CmVariable? existing;
  const _VariableDialog({this.existing});

  @override
  State<_VariableDialog> createState() => _VariableDialogState();
}

class _VariableDialogState extends State<_VariableDialog> {
  late final TextEditingController _key;
  late final TextEditingController _value;
  late final TextEditingController _group;
  late bool _secure;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _key = TextEditingController(text: e?.key ?? '');
    // A secure value comes back masked; editing means replacing it.
    _value = TextEditingController(
      text: e?.secure == true ? '' : e?.value ?? '',
    );
    _group = TextEditingController(text: e?.group ?? '');
    _secure = e?.secure ?? false;
  }

  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    _group.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      title: Text(isEdit ? 'Edit variable' : 'New variable'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _key,
              autofocus: !isEdit,
              decoration: const InputDecoration(
                labelText: 'Key',
                hintText: 'API_BASE_URL',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _value,
              decoration: InputDecoration(
                labelText: 'Value',
                hintText:
                    isEdit && widget.existing!.secure
                        ? 'Enter a new value to replace the stored one'
                        : null,
              ),
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _group,
              decoration: const InputDecoration(
                labelText: 'Group',
                hintText: 'env_vars',
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _secure,
              activeThumbColor: AppTheme.primary,
              title: const Text('Secure', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'Hidden in build logs and in the API',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              onChanged: (v) => setState(() => _secure = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final key = _key.text.trim();
            if (key.isEmpty) return;
            Navigator.pop(
              context,
              CmVariable(
                id: widget.existing?.id ?? '',
                key: key,
                value: _value.text,
                group: _group.text.trim(),
                secure: _secure,
              ),
            );
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
