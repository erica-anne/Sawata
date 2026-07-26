import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';
import 'package:sawata/models/blocked_item.dart';
import 'package:sawata/widgets/app_primary_button.dart';
import 'package:sawata/widgets/empty_state.dart';
import 'package:sawata/widgets/section_header.dart';
import 'package:sawata/widgets/snackbar_helper.dart';
import '../dashboard/widgets/dashboard_header.dart';
import 'widgets/add_blocked_item_sheet.dart';
import 'widgets/lock_hero.dart';
import 'widgets/protected_since_card.dart';
import 'widgets/protection_checklist_card.dart';

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key});

  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen> {
  final store = AppStore.instance;

  static const _accent = Color(0xFF2E7D6B);
  static const _accentDeep = Color(0xFF16332B);
  static const _mint = Color(0xFFDDEEE7);

  void _toggleItem(BlockedItem item) {
    setState(() => store.toggleBlockedItem(item.id));
    showAppSnackBar(
      context,
      '${item.name} blocking ${item.isBlocked ? 'enabled' : 'disabled'}',
    );
  }

  Future<void> _addItem() async {
    final draft = await showAddBlockedItemSheet(context);
    if (draft == null) return;
    setState(
      () => store.addBlockedItem(name: draft.name, category: draft.category),
    );
    if (!mounted) return;
    showAppSnackBar(context, '${draft.name} added to your blocked list');
  }

  Future<void> _editItem(BlockedItem item) async {
    final draft = await showAddBlockedItemSheet(context, existing: item);
    if (draft == null) return;
    setState(
      () => store.updateBlockedItem(
        item.id,
        name: draft.name,
        category: draft.category,
      ),
    );
    if (!mounted) return;
    showAppSnackBar(context, '${draft.name} updated');
  }

  Future<void> _deleteItem(BlockedItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from blocked list?'),
        content: Text('"${item.name}" will no longer be blocked by Sawatâ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => store.removeBlockedItem(item.id));
    if (!mounted) return;
    showAppSnackBar(context, '${item.name} removed', isSuccess: false);
  }

  void _toggleStatus() {
    setState(() {
      store.protectionActive = !store.protectionActive;
      if (store.protectionActive) {
        store.protectedSince = DateTime.now();
      }
    });
    showAppSnackBar(
      context,
      store.protectionActive ? 'Protection is now active' : 'Protection paused',
      isSuccess: store.protectionActive,
    );
  }

  Future<void> _simulateAttempt() async {
    final target = store.blockedItems.firstWhere(
      (e) => e.isBlocked,
      orElse: () => store.blockedItems.first,
    );
    setState(() => store.simulateBlockAttempt(target.name));
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.shield_outlined, size: 32),
        title: const Text('Attempt blocked!'),
        content: Text(
          'You tried to open "${target.name}" — Sawata stepped in. Stay strong, you have got this.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = store.protectionActive;
    final statusColor = active ? _accent : colorScheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            DashboardHeader(
              onBellTap: () =>
                  showAppSnackBar(context, "You're all caught up!"),
              onSettingsTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.settings),
            ),
            const SizedBox(height: 18),
            Text(
              'Protection',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              active
                  ? "You're fully protected. We've got your back."
                  : 'One tap protects your device from gambling websites and applications.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: LockHero(active: active, onTap: _toggleStatus),
            ),
            const SizedBox(height: 18),
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  active ? 'PROTECTION ACTIVE' : 'NOT PROTECTED',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    active
                        ? 'All gambling websites, betting apps, mirror sites, and related content are now automatically blocked.'
                        : 'Your device is currently vulnerable to gambling content.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton.icon(
                onPressed: _toggleStatus,
                style: FilledButton.styleFrom(
                  backgroundColor: active ? _mint : _accentDeep,
                  foregroundColor: active ? _accentDeep : Colors.white,
                  elevation: active ? 0 : 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: Icon(active ? Icons.verified_user : Icons.lock_outline),
                label: Text(
                  active ? 'Protection Active' : 'Lock Device',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: active && store.protectedSince != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: ProtectedSinceCard(since: store.protectedSince!),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 22),
            const ProtectionChecklistCard(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Manage Specific Sites & Apps',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
                TextButton(
                  onPressed: _simulateAttempt,
                  child: const Text('Simulate attempt'),
                ),
              ],
            ),
            ...store.blockedItems.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(item.icon, color: colorScheme.primary),
                  title: Text(item.name),
                  subtitle: Text(item.category),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: item.isBlocked,
                        onChanged: (_) => _toggleItem(item),
                      ),
                      if (item.isCustom)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') _editItem(item);
                            if (value == 'delete') _deleteItem(item);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const SectionHeader(title: 'Recent Attempts'),
            if (store.recentAttempts.isEmpty)
              const EmptyState(
                icon: Icons.history,
                message:
                    'No blocked attempts yet. Tap "Simulate attempt" above to try it out.',
              )
            else
              ...store.recentAttempts
                  .take(5)
                  .map(
                    (attempt) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.block_outlined),
                      title: Text(attempt.itemName),
                      subtitle: Text(_formatTime(attempt.time)),
                    ),
                  ),
            const SizedBox(height: 12),
            AppPrimaryButton(
              label: 'Simulate Block Attempt',
              icon: Icons.shield_outlined,
              onPressed: _simulateAttempt,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
