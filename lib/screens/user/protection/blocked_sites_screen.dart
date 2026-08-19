import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:sawata/models/app_suggestion.dart';
import 'package:sawata/models/blocked_item.dart';
import 'package:sawata/services/user_data_service.dart';
import 'package:sawata/widgets/empty_state.dart';
import 'package:sawata/widgets/snackbar_helper.dart';
import 'widgets/add_blocked_item_sheet.dart';

class BlockedSitesScreen extends StatefulWidget {
  const BlockedSitesScreen({super.key});

  @override
  State<BlockedSitesScreen> createState() => _BlockedSitesScreenState();
}

class _BlockedSitesScreenState extends State<BlockedSitesScreen> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final uid = _uid;
    if (uid == null) return;
    final draft = await showAddBlockedItemSheet(context, uid: uid);
    if (draft == null) return;
    try {
      await UserDataService.addBlockedItem(
        uid,
        name: draft.name,
        category: draft.category,
        packageName: draft.packageName,
      );
      if (!mounted) return;
      showAppSnackBar(context, '${draft.name} added to your blocked list');
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          "Couldn't add ${draft.name}. Please try again.",
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _deleteItem(BlockedItem item) async {
    final uid = _uid;
    if (uid == null) return;
    final isApp = item.category == 'App';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Blocked List?'),
        content: Text(
          '${item.name} will no longer be ${isApp ? 'blocked on this device' : 'blocked'}.',
        ),
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
    try {
      await UserDataService.removeBlockedItem(uid, item.id);
      if (!mounted) return;
      showAppSnackBar(context, '${item.name} removed', isSuccess: false);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          "Couldn't remove ${item.name}. Please try again.",
          isSuccess: false,
        );
      }
    }
  }

  /// Confirms a gambling-app suggestion — adds it to the blocked list
  /// exactly like a manual add, then resolves the suggestion so the native
  /// side stops tracking it.
  Future<void> _acceptSuggestion(AppSuggestion suggestion) async {
    final uid = _uid;
    if (uid == null) return;
    await UserDataService.addBlockedItem(
      uid,
      name: suggestion.name,
      category: 'App',
      packageName: suggestion.packageName,
    );
    await UserDataService.acceptSuggestion(uid, suggestion.packageName);
    if (!mounted) return;
    showAppSnackBar(context, '${suggestion.name} added to your blocked list');
  }

  Future<void> _dismissSuggestion(AppSuggestion suggestion) async {
    final uid = _uid;
    if (uid == null) return;
    await UserDataService.dismissSuggestion(uid, suggestion.packageName);
    if (!mounted) return;
    showAppSnackBar(context, '${suggestion.name} dismissed', isSuccess: false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Sites & Apps'),
        actions: [
          TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Sawatâ automatically protects you from known gambling sites '
                'and apps. Add anything else below to block it too.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: _SearchField(
                controller: _searchController,
                hint: 'Search blocked sites & apps',
                onClear: () => _searchController.clear(),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<AppSuggestion>>(
                stream: uid == null ? null : UserDataService.watchSuggestions(uid),
                builder: (context, suggestionSnapshot) {
                  final suggestions =
                      suggestionSnapshot.data ?? const <AppSuggestion>[];
                  return StreamBuilder<List<BlockedItem>>(
                    stream: uid == null ? null : UserDataService.watchBlockedItems(uid),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? const <BlockedItem>[];
                      if (items.isEmpty && suggestions.isEmpty) {
                        return const EmptyState(
                          icon: Icons.block_outlined,
                          message: 'Nothing blocked yet.\nAdd a website or app to get started.',
                        );
                      }

                      final filteredItems = _query.isEmpty
                          ? items
                          : items
                                .where((i) => i.name.toLowerCase().contains(_query))
                                .toList();

                      if (filteredItems.isEmpty && suggestions.isEmpty && _query.isNotEmpty) {
                        return EmptyState(
                          icon: Icons.search_off,
                          message: 'No matches for "${_searchController.text.trim()}".',
                        );
                      }

                      final apps = filteredItems.where((i) => i.category == 'App').toList();
                      final websites = filteredItems.where((i) => i.category != 'App').toList();

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          if (suggestions.isNotEmpty) ...[
                            Text(
                              'Suggested for You',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Matched a gambling keyword when you opened it — '
                              'review before blocking.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            for (final suggestion in suggestions)
                              Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.flag_outlined,
                                        color: colorScheme.error,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          suggestion.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            _dismissSuggestion(suggestion),
                                        child: const Text('Not gambling'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            _acceptSuggestion(suggestion),
                                        child: const Text('Block'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                          ],
                          if (apps.isNotEmpty) ...[
                            _SectionHeader(label: 'Apps'),
                            _BlockedItemList(items: apps, onRemove: _deleteItem),
                            const SizedBox(height: 20),
                          ],
                          if (websites.isNotEmpty) ...[
                            _SectionHeader(label: 'Websites'),
                            _BlockedItemList(items: websites, onRemove: _deleteItem),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact rounded search box, styled to match [_BlockedItemList]'s
/// container (surface fill, outlineVariant border, 16-radius corners).
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: hint,
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClear,
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Simple list with thin dividers — deliberately not card-heavy, per the
/// Blocked Sites & Apps redesign.
class _BlockedItemList extends StatelessWidget {
  const _BlockedItemList({required this.items, required this.onRemove});

  final List<BlockedItem> items;
  final ValueChanged<BlockedItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: Icon(items[i].icon, color: colorScheme.primary),
              title: Text(items[i].name),
              subtitle: const Text('Blocked'),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (_) => onRemove(items[i]),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove from Blocked List'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
