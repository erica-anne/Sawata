import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';
import 'package:sawata/widgets/app_primary_button.dart';
import 'package:sawata/widgets/confirm_dialog.dart';
import 'package:sawata/widgets/snackbar_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final store = AppStore.instance;

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: store.profile.name);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Profile',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'Save',
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                store.profile.name = nameController.text.trim();
                Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      setState(() {});
      if (!mounted) return;
      showAppSnackBar(context, 'Profile updated');
    }
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('About Sawata'),
        content: Text(
          'Sawata v0.1.0 (prototype build)\n\n'
          'A UI prototype demonstrating a gambling-recovery accountability '
          'experience. All data shown is simulated for demonstration purposes.',
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'Are you sure you want to log out of Sawata?',
      confirmLabel: 'Log out',
    );
    if (!confirmed || !mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = store.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        profile.initials,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            profile.email,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    value: store.notificationsEnabled,
                    onChanged: (value) {
                      setState(() => store.notificationsEnabled = value);
                      showAppSnackBar(
                        context,
                        value
                            ? 'Notifications enabled'
                            : 'Notifications disabled',
                      );
                    },
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.brightness_6_outlined),
                        const SizedBox(width: 16),
                        const Expanded(child: Text('Theme')),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Light')),
                            ButtonSegment(value: true, label: Text('Dark')),
                          ],
                          selected: {store.darkThemePlaceholder},
                          onSelectionChanged: (selection) {
                            setState(
                              () =>
                                  store.darkThemePlaceholder = selection.first,
                            );
                            showAppSnackBar(
                              context,
                              'Theme preference saved (Light mode only in this build)',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Edit Profile'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _editProfile,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About & Privacy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showAbout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Logout',
              icon: Icons.logout,
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
