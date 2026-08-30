import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/models/app_model.dart';
import '../../core/providers/codemagic_provider.dart';
import '../../core/providers/accounts_provider.dart';
import '../../core/providers/app_info_provider.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/account_sheet.dart';
import '../widgets/skeletons.dart';

class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(appsProvider);
    final filtered = ref.watch(filteredAppsProvider);
    final query = ref.watch(appSearchQueryProvider);
    final activeAccount = ref.watch(accountsProvider).active;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(appsProvider);
          ref.invalidate(latestBuildsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.bg,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryLight, AppTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Ignite',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.06),
                        AppTheme.bg,
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                _AccountButton(
                  name: activeAccount?.name,
                  onTap: () => AccountSheet.show(context),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  tooltip: 'About',
                  onPressed: () => _showInfoSheet(context, ref),
                ),
                const SizedBox(width: 4),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged:
                        (v) =>
                            ref.read(appSearchQueryProvider.notifier).state = v,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search apps or repositories',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                      suffixIcon:
                          query.isEmpty
                              ? null
                              : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                color: AppTheme.textMuted,
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(appSearchQueryProvider.notifier)
                                      .state = '';
                                },
                              ),
                    ),
                  ),
                ),
              ),
            ),
            appsAsync.when(
              data: (allApps) {
                if (allApps.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No applications found.')),
                  );
                }
                final apps = filtered.valueOrNull ?? allApps;
                if (apps.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No apps match "$query"',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final app = apps[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AppCard(app: app)
                            .animate()
                            .fadeIn(delay: (50 * index).ms)
                            .slideX(begin: 0.06, end: 0),
                      );
                    }, childCount: apps.length),
                  ),
                );
              },
              loading:
                  () => const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverToBoxAdapter(child: AppListSkeleton()),
                  ),
              error:
                  (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.error,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load: $e',
                            style: const TextStyle(color: AppTheme.error),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(appsProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The active account, and the way into switching it.
class _AccountButton extends StatelessWidget {
  final String? name;
  final VoidCallback onTap;
  const _AccountButton({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name == null ? 'Accounts' : 'Account: $name',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
          ),
          child: Text(
            (name == null || name!.trim().isEmpty)
                ? '?'
                : name!.trim()[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppCard extends ConsumerWidget {
  final CmApplication app;
  const _AppCard({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Builds age out of the list endpoint, so a missing entry means "nothing
    // recent", not "failed to load". Render nothing rather than an error.
    final latest = ref.watch(latestBuildsProvider).valueOrNull?[app.id];

    return Card(
      child: InkWell(
        onTap: () => context.push('/app/${app.id}', extra: app),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.25),
                      AppTheme.primaryDark.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.appName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      app.repositoryUrl ?? 'No repository',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (latest != null) ...[
                      const SizedBox(height: 8),
                      BuildStatusChip(cmBuild: latest),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A coloured pill showing a build's outcome and how long ago it ran.
class BuildStatusChip extends StatelessWidget {
  final CmBuild cmBuild;
  const BuildStatusChip({super.key, required this.cmBuild});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = _style(cmBuild);
    final when = cmBuild.startedAt ?? cmBuild.finishedAt;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        if (when != null) ...[
          const SizedBox(width: 8),
          Text(
            timeago.format(when),
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ],
    );
  }

  static (Color, String, IconData) _style(CmBuild b) {
    if (b.isSuccess) return (AppTheme.success, 'PASSED', Icons.check_rounded);
    if (b.isFailed) return (AppTheme.error, 'FAILED', Icons.close_rounded);
    if (b.isRunning) {
      return (AppTheme.warning, 'BUILDING', Icons.sync_rounded);
    }
    if (b.isCanceled) {
      return (AppTheme.textMuted, 'CANCELED', Icons.block_rounded);
    }
    return (AppTheme.textSecondary, b.status.toUpperCase(), Icons.help_outline);
  }
}

void _showInfoSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _InfoSheet(ref: ref),
  );
}

class _InfoSheet extends ConsumerWidget {
  final WidgetRef ref;
  const _InfoSheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appInfoAsync = ref.watch(appInfoProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // App icon + name
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [AppTheme.primaryLight, AppTheme.primaryDark],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Ignite',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Codemagic CI/CD Admin',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          appInfoAsync.when(
            data:
                (info) => Text(
                  'v${info.version}+${info.buildNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 12),
          // Author row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Author',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  SizedBox(height: 2),
                  Text(
                    kAppAuthorEmail,
                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Buy me a coffee button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCoffeeQRDialog(context),
              icon: const Text('☕', style: TextStyle(fontSize: 18)),
              label: const Text(
                'Buy me a coffee',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFDD00),
                foregroundColor: const Color(0xFF1A1A1A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showCoffeeQRDialog(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (ctx) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '☕ Buy me a coffee',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Scan to support the author',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 20),
                QrImageView(
                  data: kBankQRData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}
