import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/models/app_model.dart';
import '../../core/providers/codemagic_provider.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/build_detail_sheet.dart';
import 'yaml_trigger_page.dart';

class AppDetailPage extends ConsumerStatefulWidget {
  final CmApplication app;
  const AppDetailPage({super.key, required this.app});

  @override
  ConsumerState<AppDetailPage> createState() => _AppDetailPageState();
}

class _AppDetailPageState extends ConsumerState<AppDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isTriggering = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _triggerBuild(String workflowId) async {
    setState(() => _isTriggering = true);
    try {
      final api = ref.read(codemagicApiProvider);
      if (api != null) {
        await api.triggerBuild(appId: widget.app.id, workflowId: workflowId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Build triggered successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
          ref.invalidate(buildsProvider(widget.app.id));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to trigger build: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isTriggering = false);
    }
  }

  void _showQuickTriggerDialog(List<CmWorkflow> workflows) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Trigger',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select a workflow to start on the default branch',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (workflows.isEmpty)
                const Text('No workflows available.', style: TextStyle(color: AppTheme.error))
              else
                ...workflows.map((wf) => ListTile(
                      leading: const Icon(Icons.play_circle_fill, color: AppTheme.primary),
                      title: Text(wf.name),
                      subtitle: Text(wf.id, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () {
                        Navigator.pop(context);
                        _triggerBuild(wf.id);
                      },
                    )),
            ],
          ),
        ),
      ),
    );
  }

  void _openYamlTrigger(List<CmWorkflow> workflows) async {
    final triggered = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => YamlTriggerPage(app: widget.app, workflows: workflows),
      ),
    );
    if (triggered == true) {
      ref.invalidate(buildsProvider(widget.app.id));
    }
  }

  void _showTriggerMenu(List<CmWorkflow> workflows) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trigger New Build',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: AppTheme.primary),
                ),
                title: const Text('Quick Trigger', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'Pick a workflow, start immediately',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  _showQuickTriggerDialog(workflows);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.code, color: AppTheme.accent),
                ),
                title: const Text('YAML Config Trigger', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'Define workflow, branch & env vars in YAML',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  _openYamlTrigger(workflows);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRawDebug() async {
    final api = ref.read(codemagicApiProvider);
    if (api == null) return;
    try {
      final appJson = await api.getRawJson('/apps/${widget.app.id}');
      final buildsJson = await api.getRawJson('/builds?appId=${widget.app.id}&limit=1');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.bgElevated,
          title: const Text('Raw API Response', style: TextStyle(fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(tabs: [Tab(text: 'App'), Tab(text: 'Build')]),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _JsonView(json: appJson),
                        _JsonView(json: buildsJson),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '$appJson\n\n$buildsJson'));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              child: const Text('Copy'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Debug error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workflowsAsync = ref.watch(workflowsProvider(widget.app.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.app.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.data_object, size: 20),
            tooltip: 'Raw API debug',
            onPressed: () => _showRawDebug(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.build_outlined), text: 'Builds'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
          ],
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              color: AppTheme.primary.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.source, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.app.repositoryUrl ?? 'No repository URL',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn().slideY(begin: -0.1, end: 0),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _BuildsTab(app: widget.app),
                _StatsTab(app: widget.app),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: workflowsAsync.when(
        data: (workflows) => FloatingActionButton.extended(
          onPressed: _isTriggering ? null : () => _showTriggerMenu(workflows),
          backgroundColor: AppTheme.primary,
          icon: _isTriggering
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.local_fire_department_rounded, color: Colors.white),
          label: const Text(
            'Start Build',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ).animate().scale(),
        loading: () => const SizedBox.shrink(),
        error: (e, _) => const SizedBox.shrink(),
      ),
    );
  }
}

// ── Builds Tab ────────────────────────────────────────────────────────────────

class _BuildsTab extends ConsumerWidget {
  final CmApplication app;
  const _BuildsTab({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildsAsync = ref.watch(buildsProvider(app.id));
    final workflowsAsync = ref.watch(workflowsProvider(app.id));
    final wfNames = workflowsAsync.valueOrNull
        ?.fold<Map<String, String>>({}, (map, wf) => map..[wf.id] = wf.name) ?? {};

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(buildsProvider(app.id));
        ref.invalidate(workflowsProvider(app.id));
      },
      child: buildsAsync.when(
        data: (builds) {
          if (builds.isEmpty) {
            return const Center(child: Text('No builds found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: builds.length,
            itemBuilder: (context, index) {
              final b = builds[index];
              final displayName = b.fileWorkflowId?.isNotEmpty == true
                  ? b.fileWorkflowId!
                  : wfNames[b.workflowId] ?? b.workflowName;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BuildItem(
                  item: b,
                  displayName: displayName,
                  onTap: () => BuildDetailSheet.show(
                    context,
                    b,
                    workflowDisplayName: displayName,
                    onCanceled: () => ref.invalidate(buildsProvider(app.id)),
                  ),
                ).animate().fadeIn(delay: (40 * index).ms).slideX(begin: 0.05, end: 0),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e', style: const TextStyle(color: AppTheme.error)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(buildsProvider(app.id)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildItem extends StatelessWidget {
  final CmBuild item;
  final String displayName;
  final VoidCallback? onTap;
  const _BuildItem({required this.item, required this.displayName, this.onTap});

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppTheme.textSecondary;
    IconData statusIcon = Icons.help_outline;

    if (item.isSuccess) {
      statusColor = AppTheme.success;
      statusIcon = Icons.check_circle;
    } else if (item.isFailed) {
      statusColor = AppTheme.error;
      statusIcon = Icons.error;
    } else if (item.isRunning) {
      statusColor = AppTheme.warning;
      statusIcon = Icons.sync;
    } else if (item.isCanceled) {
      statusColor = AppTheme.textMuted;
      statusIcon = Icons.cancel;
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.isRunning)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: statusColor, strokeWidth: 2),
                )
              else
                Icon(statusIcon, color: statusColor, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            displayName.isNotEmpty ? displayName : item.workflowId,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '#${item.buildNumber ?? '?'}',
                          style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.commitMessage ?? 'No commit message',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.call_split, size: 13, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          item.branch ?? 'unknown',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const Spacer(),
                        if (item.startedAt != null) ...[
                          const Icon(Icons.access_time, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            timeago.format(item.startedAt!),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────

class _StatsTab extends ConsumerWidget {
  final CmApplication app;
  const _StatsTab({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(buildStatsProvider(app.id));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(buildStatsProvider(app.id)),
      child: statsAsync.when(
        data: (stats) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _StatCard(stats: stats).animate().fadeIn(),
            const SizedBox(height: 16),
            _StatsGrid(stats: stats).animate().fadeIn(delay: 100.ms),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e', style: const TextStyle(color: AppTheme.error)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(buildStatsProvider(app.id)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final BuildStats stats;
  const _StatCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.total == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No build data available.')),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    if (stats.succeeded > 0) {
      sections.add(PieChartSectionData(
        value: stats.succeeded.toDouble(),
        color: AppTheme.success,
        title: '${stats.succeeded}',
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 60,
      ));
    }
    if (stats.failed > 0) {
      sections.add(PieChartSectionData(
        value: stats.failed.toDouble(),
        color: AppTheme.error,
        title: '${stats.failed}',
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 60,
      ));
    }
    if (stats.running > 0) {
      sections.add(PieChartSectionData(
        value: stats.running.toDouble(),
        color: AppTheme.warning,
        title: '${stats.running}',
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 60,
      ));
    }
    if (stats.canceled > 0) {
      sections.add(PieChartSectionData(
        value: stats.canceled.toDouble(),
        color: AppTheme.textMuted,
        title: '${stats.canceled}',
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 60,
      ));
    }

    final successPct = (stats.successRate * 100).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Build Distribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Last ${stats.total} builds',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Legend(color: AppTheme.success, label: 'Success', count: stats.succeeded),
                      _Legend(color: AppTheme.error, label: 'Failed', count: stats.failed),
                      _Legend(color: AppTheme.warning, label: 'Running', count: stats.running),
                      _Legend(color: AppTheme.textMuted, label: 'Canceled', count: stats.canceled),
                      const Divider(height: 20),
                      Text(
                        '$successPct% success rate',
                        style: TextStyle(
                          color: stats.successRate >= 0.8 ? AppTheme.success : AppTheme.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _Legend({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final BuildStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatTile(label: 'Total Builds', value: '${stats.total}', icon: Icons.build, color: AppTheme.primary),
        _StatTile(
          label: 'Success Rate',
          value: '${(stats.successRate * 100).toStringAsFixed(0)}%',
          icon: Icons.trending_up,
          color: stats.successRate >= 0.8 ? AppTheme.success : AppTheme.warning,
        ),
        _StatTile(label: 'Succeeded', value: '${stats.succeeded}', icon: Icons.check_circle, color: AppTheme.success),
        _StatTile(label: 'Failed', value: '${stats.failed}', icon: Icons.error, color: AppTheme.error),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _JsonView extends StatelessWidget {
  final String json;
  const _JsonView({required this.json});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: SelectableText(
        json,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.5),
      ),
    );
  }
}
