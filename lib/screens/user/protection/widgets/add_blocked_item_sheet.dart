import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sawata/models/installed_app.dart';
import 'package:sawata/services/installed_apps_service.dart';
import 'package:sawata/services/user_data_service.dart';
import 'package:sawata/utils/domain_utils.dart';
import 'package:sawata/widgets/app_primary_button.dart';

class BlockedItemDraft {
  const BlockedItemDraft({
    required this.name,
    required this.category,
    this.packageName,
  });

  final String name;
  final String category;
  final String? packageName;
}

/// Shows the "what do you want to block?" flow: a choice between Website
/// and App, then either a single normalized-domain field or a picker over
/// the device's installed apps — never a raw Android package-name field.
/// See lib/screens/user/protection/blocked_sites_screen.dart for how the
/// result is written to Firestore.
Future<BlockedItemDraft?> showAddBlockedItemSheet(
  BuildContext context, {
  required String uid,
}) {
  return showModalBottomSheet<BlockedItemDraft>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AddBlockedItemSheetContent(uid: uid),
  );
}

enum _Step { choose, website, appPicker }

class _AddBlockedItemSheetContent extends StatefulWidget {
  const _AddBlockedItemSheetContent({required this.uid});

  final String uid;

  @override
  State<_AddBlockedItemSheetContent> createState() =>
      _AddBlockedItemSheetContentState();
}

class _AddBlockedItemSheetContentState
    extends State<_AddBlockedItemSheetContent> {
  _Step _step = _Step.choose;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: switch (_step) {
          _Step.choose => _ChooseTypeStep(
            onPickWebsite: () => setState(() => _step = _Step.website),
            onPickApp: () => setState(() => _step = _Step.appPicker),
            onCancel: () => Navigator.of(context).pop(),
          ),
          _Step.website => _AddWebsiteStep(uid: widget.uid),
          _Step.appPicker => _AppPickerStep(uid: widget.uid),
        },
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.scrollable = false,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// True lets [child] (e.g. a long app list) expand and scroll within the
  /// sheet's bounded height instead of the whole sheet trying to grow past
  /// the screen — see the ConstrainedBox in [_AddBlockedItemSheetContentState].
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (scrollable) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, Flexible(child: child)],
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, child],
        ),
      ),
    );
  }
}

class _ChooseTypeStep extends StatelessWidget {
  const _ChooseTypeStep({
    required this.onPickWebsite,
    required this.onPickApp,
    required this.onCancel,
  });

  final VoidCallback onPickWebsite;
  final VoidCallback onPickApp;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Add to Blocked List',
      subtitle: 'What do you want to block?',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChoiceTile(
              icon: Icons.public,
              label: 'Website',
              description: 'Block a website',
              onTap: onPickWebsite,
            ),
            const SizedBox(height: 10),
            _ChoiceTile(
              icon: Icons.apps,
              label: 'App',
              description: 'Block an installed app',
              onTap: onPickApp,
            ),
            const SizedBox(height: 14),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddWebsiteStep extends StatefulWidget {
  const _AddWebsiteStep({required this.uid});

  final String uid;

  @override
  State<_AddWebsiteStep> createState() => _AddWebsiteStepState();
}

class _AddWebsiteStepState extends State<_AddWebsiteStep> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isSaving = false;
  String? _serverError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Please enter a website address';
    if (normalizeDomain(input) == null) {
      return "That doesn't look like a valid website address";
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _serverError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final domain = normalizeDomain(_controller.text);
    if (domain == null) return; // already caught by _validate

    setState(() => _isSaving = true);
    try {
      final alreadyBlocked = await UserDataService.hasBlockedDomain(
        widget.uid,
        domain,
      );
      if (alreadyBlocked) {
        if (!mounted) return;
        setState(
          () => _serverError = 'This website is already in your blocked list.',
        );
        return;
      }
      final globallyBlocked = await UserDataService.isGloballyBlockedDomain(
        domain,
      );
      if (globallyBlocked) {
        if (!mounted) return;
        setState(
          () => _serverError = 'This website is already protected by Sawatâ.',
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(BlockedItemDraft(name: domain, category: 'Website'));
    } catch (_) {
      if (mounted) {
        setState(
          () => _serverError = "Couldn't save right now. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Add Website',
      subtitle: 'Enter the website you want Sawatâ to block.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                validator: _validate,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Website address',
                  hintText: 'e.g. examplebet.com',
                  prefixIcon: const Icon(Icons.public),
                  errorText: _serverError,
                ),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: 'Add to Blocked List',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppPickerStep extends StatefulWidget {
  const _AppPickerStep({required this.uid});

  final String uid;

  @override
  State<_AppPickerStep> createState() => _AppPickerStepState();
}

class _AppPickerStepState extends State<_AppPickerStep> {
  late final Future<List<InstalledApp>> _appsFuture = InstalledAppsService.list();
  final _searchController = TextEditingController();
  String _query = '';
  bool _isChecking = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectApp(InstalledApp app) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      final alreadyBlocked = await UserDataService.hasBlockedPackage(
        widget.uid,
        app.packageName,
      );
      if (!mounted) return;
      if (alreadyBlocked) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Already blocked'),
            content: Text('${app.name} is already on your blocked list.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      final globallyBlocked = await UserDataService.isGloballyBlockedPackage(
        app.packageName,
      );
      if (!mounted) return;
      if (globallyBlocked) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Already protected'),
            content: Text('${app.name} is already protected by Sawatâ.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      Navigator.of(context).pop(
        BlockedItemDraft(
          name: app.name,
          category: 'App',
          packageName: app.packageName,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save right now. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Choose an App',
      subtitle: 'Select an app installed on this device to block.',
      scrollable: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                labelText: 'Search apps',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<List<InstalledApp>>(
                future: _appsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    final message = snapshot.error is InstalledAppsException
                        ? (snapshot.error as InstalledAppsException).message
                        : "Couldn't load installed apps.";
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    );
                  }

                  final apps = snapshot.data ?? const <InstalledApp>[];
                  if (apps.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('No apps found on this device.')),
                    );
                  }

                  final query = _query.toLowerCase();
                  final filtered = query.isEmpty
                      ? apps
                      : apps
                            .where((app) => app.name.toLowerCase().contains(query))
                            .toList();

                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('No matching apps.')),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final app = filtered[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        enabled: !_isChecking,
                        leading: _AppIcon(icon: app.icon),
                        title: Text(app.name),
                        onTap: () => _selectApp(app),
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

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.icon});

  final Uint8List? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.apps,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(icon!, width: 36, height: 36, fit: BoxFit.cover),
    );
  }
}
