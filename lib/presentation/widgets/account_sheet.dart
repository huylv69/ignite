import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/account_model.dart';
import '../../core/models/app_model.dart';
import '../../core/providers/accounts_provider.dart';
import '../../core/providers/codemagic_provider.dart';
import '../../core/theme/app_theme.dart';

/// Lets the signed-in accounts be switched, renamed, removed, or added to.
///
/// The notifier has supported all of this since accounts were introduced; this
/// is the surface that reaches it.
class AccountSheet extends ConsumerWidget {
  const AccountSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AccountSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountsProvider);
    final notifier = ref.read(accountsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Accounts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const _QuotaCard(),
            ...state.accounts.map(
              (a) => _AccountTile(
                account: a,
                isActive: a.id == state.activeId,
                onTap: () async {
                  await notifier.switchAccount(a.id);
                  if (context.mounted) Navigator.pop(context);
                },
                onRename: () => _rename(context, ref, a),
                onRemove: () => _remove(context, ref, a),
              ),
            ),
            const Divider(color: AppTheme.border, height: 24),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              title: const Text(
                'Add account',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Connect another Codemagic token',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/login?add=true');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    AccountModel account,
  ) async {
    final controller = TextEditingController(text: account.name);
    final name = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: const Text('Rename account'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(accountsProvider.notifier).renameAccount(account.id, name);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    AccountModel account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: const Text('Remove account?'),
            content: Text(
              '"${account.name}" will be signed out on this device. '
              'The token itself is not revoked.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    await ref.read(accountsProvider.notifier).removeAccount(account.id);
    if (!context.mounted) return;
    Navigator.pop(context);
    // Removing the last account leaves nothing to show; the router guard sends
    // us to login on its own, but popping the sheet first avoids a stale route.
    if (ref.read(accountsProvider).accounts.isEmpty) context.go('/login');
  }
}

class _AccountTile extends StatelessWidget {
  final AccountModel account;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  const _AccountTile({
    required this.account,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: isActive ? null : onTap,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withValues(alpha: isActive ? 0.35 : 0.15),
              AppTheme.primaryDark.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: isActive ? 0.6 : 0.2),
          ),
        ),
        child: Text(
          _initial(account.name),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
      title: Text(
        account.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        isActive ? 'Active' : 'Tap to switch',
        style: TextStyle(
          fontSize: 12,
          color: isActive ? AppTheme.success : AppTheme.textMuted,
        ),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textMuted),
        color: AppTheme.bgElevated,
        onSelected: (v) => v == 'rename' ? onRename() : onRemove(),
        itemBuilder:
            (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
      ),
    );
  }

  static String _initial(String name) =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

/// Build minutes used against the account's monthly free allowance.
///
/// Codemagic has no quota endpoint — the numbers ride along on `GET /user`
/// under `buildTimes` and `billing.usage`. It reports no period end date, so
/// this deliberately promises no reset countdown.
class _QuotaCard extends ConsumerWidget {
  const _QuotaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quota = ref.watch(quotaProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: quota.when(
          data: (q) => _QuotaBody(quota: q),
          loading:
              () => const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Reading build minutes…',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
          // `/user` carries the quota but sends no CORS headers, unlike /apps
          // and /builds, so a browser can never read it. Say that instead of
          // offering a Retry that cannot succeed.
          error:
              (e, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    kIsWeb ? Icons.public_off_rounded : Icons.error_outline,
                    size: 15,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kIsWeb
                          ? 'Build minutes are not readable on the web — '
                              "Codemagic's account endpoint blocks browsers."
                          : 'Build minutes unavailable',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => ref.invalidate(quotaProvider),
                      child: const Text(
                        'Retry',
                        style: TextStyle(fontSize: 12, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ],
              ),
        ),
      ),
    );
  }
}

/// Codemagic sells this allowance as "500 build minutes a month", so the
/// card counts in minutes too. Rendering 30000s as "8h 20m" was accurate and
/// useless — it made the reader convert back to the unit they were given.
String quotaMinutes(int seconds) => '${seconds ~/ 60}';

/// `mac_mini_m2_free` is a billing key, not a label. Split the machine from
/// the bucket and say the machine in words.
String quotaMachineLabel(String key) {
  var k = key;
  var bucket = '';
  for (final b in ['_free', '_paid', '_personal']) {
    if (k.endsWith(b)) {
      bucket = b.substring(1);
      k = k.substring(0, k.length - b.length);
      break;
    }
  }
  const names = {
    'mac_mini_m1': 'Mac mini M1',
    'mac_mini_m2': 'Mac mini M2',
    'mac_mini_m4': 'Mac mini M4',
    'linux_x2': 'Linux x2',
    'windows_x2': 'Windows x2',
  };
  final name = names[k] ?? k.replaceAll('_', ' ');
  // The free bucket is the whole context of this card; only a paid or
  // personal one is worth calling out.
  return bucket.isEmpty || bucket == 'free' ? name : '$name ($bucket)';
}

class _QuotaBody extends StatelessWidget {
  final CmQuota quota;
  const _QuotaBody({required this.quota});

  @override
  Widget build(BuildContext context) {
    if (!quota.hasLimit) {
      return Text(
        'This account has no free-tier build limit.',
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      );
    }

    // Green until it matters, amber past three quarters, red at the edge.
    final f = quota.fraction;
    final tone =
        f >= 0.9
            ? AppTheme.error
            : f >= 0.75
            ? AppTheme.warning
            : AppTheme.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.timer_outlined,
              size: 15,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            const Text(
              'Build minutes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Text(
              '${quota.remainingMinutes} min left',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: f,
            minHeight: 6,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(tone),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${quota.usedMinutes} of ${quota.limitMinutes} min used'
          '${quota.concurrency > 0 ? '  ·  ${quota.concurrency} concurrent build${quota.concurrency == 1 ? '' : 's'}' : ''}',
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        // With a single machine type the chips just restate the line above.
        if (quota.byInstanceType.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                quota.byInstanceType.entries
                    .map(
                      (e) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${quotaMachineLabel(e.key)} · ${quotaMinutes(e.value)}m',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ],
    );
  }
}
