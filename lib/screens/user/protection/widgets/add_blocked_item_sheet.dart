import 'package:flutter/material.dart';

import 'package:sawata/models/blocked_item.dart';
import 'package:sawata/widgets/app_primary_button.dart';

class BlockedItemDraft {
  const BlockedItemDraft({required this.name, required this.category});

  final String name;
  final String category;
}

/// Shows the add/edit form for a custom blocked site or app. Pass
/// [existing] to pre-fill the form and switch it into edit mode.
Future<BlockedItemDraft?> showAddBlockedItemSheet(
  BuildContext context, {
  BlockedItem? existing,
}) {
  return showModalBottomSheet<BlockedItemDraft>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AddBlockedItemSheetContent(existing: existing),
  );
}

class _AddBlockedItemSheetContent extends StatefulWidget {
  const _AddBlockedItemSheetContent({this.existing});

  final BlockedItem? existing;

  @override
  State<_AddBlockedItemSheetContent> createState() =>
      _AddBlockedItemSheetContentState();
}

class _AddBlockedItemSheetContentState
    extends State<_AddBlockedItemSheetContent> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late String _category =
      widget.existing?.category ?? blockedItemCategories.first;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      BlockedItemDraft(name: _nameController.text.trim(), category: _category),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit Site or App' : 'Add Site or App',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _isEditing
                  ? 'Update the name or category for this entry.'
                  : "Add a gambling site or app that isn't in the default list.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please enter a name'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. stake.com or LuckyBet App',
                prefixIcon: Icon(Icons.language_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final category in blockedItemCategories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: _isEditing ? 'Save Changes' : 'Add to Blocked List',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
