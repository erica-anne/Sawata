import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sawata/widgets/app_primary_button.dart';
import 'package:sawata/widgets/snackbar_helper.dart';

/// Bridges to `SawataVpnService` (android/app/.../vpn/SawataVpnService.kt).
/// Starts/stops the VPN session, which — only while Protection Lock is on
/// (`users/{uid}.protectionActive`, the master switch checked natively in
/// `DomainBlocklist.kt`) — blocks DNS lookups for any domain in Sawatâ's
/// global default blocklist (`blocked_domains`) or the signed-in user's own
/// `blocked_items`, while passing everything else through untouched.
/// DNS-only — apps/browsers using DNS-over-HTTPS or a hardcoded IP can
/// still bypass it. This screen is a manual detail/recovery control now;
/// the normal path is Turn On/Off Protection on the main Protection screen,
/// which starts/stops this same VPN automatically.
const _vpnChannel = MethodChannel('sawata/vpn');

class WebsiteProtectionScreen extends StatefulWidget {
  const WebsiteProtectionScreen({super.key});

  @override
  State<WebsiteProtectionScreen> createState() =>
      _WebsiteProtectionScreenState();
}

class _WebsiteProtectionScreenState extends State<WebsiteProtectionScreen> {
  static const _accent = Color(0xFF2E7D6B);
  static const _accentDeep = Color(0xFF16332B);
  static const _mint = Color(0xFFDDEEE7);

  bool _running = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    bool running;
    try {
      running = await _vpnChannel.invokeMethod<bool>('isRunning') ?? false;
    } catch (_) {
      running = false;
    }
    if (mounted) setState(() => _running = running);
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      if (_running) {
        await _vpnChannel.invokeMethod('stopVPN');
        if (!mounted) return;
        setState(() => _running = false);
        showAppSnackBar(context, 'Website protection turned off', isSuccess: false);
      } else {
        final granted =
            await _vpnChannel.invokeMethod<bool>('prepareVPN') ?? false;
        if (!mounted) return;
        setState(() => _running = granted);
        showAppSnackBar(
          context,
          granted
              ? 'Website protection is now active'
              : 'VPN permission was not granted.',
          isSuccess: granted,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not update website protection.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _running ? _accent : colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Website Protection')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Icon(Icons.public, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  _running ? 'Active' : 'Off',
                  style: TextStyle(fontWeight: FontWeight.w800, color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Blocks gambling websites from your blocked list at the DNS '
                'level, device-wide. Apps that use encrypted DNS may still '
                'get through for now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _accentDeep,
                ),
              ),
            ),
            const SizedBox(height: 22),
            AppPrimaryButton(
              label: _running
                  ? 'Disable Website Protection'
                  : 'Enable Website Protection',
              icon: _running ? Icons.public_off : Icons.public,
              isLoading: _busy,
              onPressed: _toggle,
            ),
          ],
        ),
      ),
    );
  }
}
