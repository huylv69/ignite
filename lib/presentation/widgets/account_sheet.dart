import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/account_model.dart';
import '../../core/providers/accounts_provider.dart';
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
