import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:sawata/app/app_config.dart';
import 'package:sawata/app/routes.dart';
import 'package:sawata/data/dummy_data_store.dart';
import 'package:sawata/models/guardian_contact.dart';
import 'package:sawata/services/email_service.dart';
import 'package:sawata/widgets/confirm_dialog.dart';
import 'package:sawata/widgets/snackbar_helper.dart';

import 'widgets/guardian_form_field.dart';
import 'widgets/guardian_illustration.dart';
import 'widgets/guardian_step_icon.dart';
import 'widgets/guardian_step_progress.dart';

/// The User-side "Add a Guardian" wizard: a 4-step flow (Guardian Info,
/// Review, Invite, Done) for connecting someone who will support the
/// user's recovery.
class AddGuardianScreen extends StatefulWidget {
  const AddGuardianScreen({super.key});

  @override
  State<AddGuardianScreen> createState() => _AddGuardianScreenState();
}

class _AddGuardianScreenState extends State<AddGuardianScreen> {
  final store = AppStore.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _relationships = [
    'Parent',
    'Sibling',
    'Spouse / Partner',
    'Friend',
    'Other Relative',
    'Other',
  ];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  int _currentStep = 0;
  String? _relationship;
  bool _showRelationshipError = false;
  DateTime? _sentAt;
  bool _isAccepted = false;
  bool _isSending = false;
  bool _isResending = false;

  /// Firestore doc id of the invite this wizard created — the single
  /// source of truth for status (`pending`/`accepted`), replacing the old
  /// in-memory `store.myGuardianInviteAccepted` flag.
  String? _inviteDocId;

  static const _deepTeal = Color(0xFF16332B);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

  String _formatTime(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $ampm';
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Please enter your guardian's name";
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter an email address';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  Future<void> _pickRelationship() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select relationship',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
            for (final option in _relationships)
              ListTile(
                title: Text(option),
                onTap: () => Navigator.of(context).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null) {
      setState(() {
        _relationship = choice;
        _showRelationshipError = false;
      });
    }
  }

  void _goToStep(int step) => setState(() => _currentStep = step);

  void _handleContinueFromInfo() {
    final formValid = _formKey.currentState?.validate() ?? false;
    final relationshipValid = _relationship != null;
    if (!relationshipValid) setState(() => _showRelationshipError = true);
    if (!formValid || !relationshipValid) return;
    _goToStep(1);
  }

  Future<void> _checkStatus() async {
    final docId = _inviteDocId;
    if (docId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('invites')
          .doc(docId)
          .get();
      final status = doc.data()?['status'] as String?;
      if (!mounted) return;
      if (status == 'accepted') {
        setState(() => _isAccepted = true);
        store.myGuardianInviteAccepted = true;
      } else {
        showAppSnackBar(
          context,
          "Your guardian hasn't accepted the invitation yet.",
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not check status. Try again.');
      }
    }
  }

  Future<void> _sendInvitation() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final relationship = _relationship ?? 'Guardian';
    if (_isSending) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      showAppSnackBar(
        context,
        "You're signed out — please sign in again to send an invitation.",
        isSuccess: false,
      );
      return;
    }
    setState(() => _isSending = true);
    try {
      // Step 1: the invitation is saved to Firestore regardless of what
      // happens next — this is the source of truth for "an invite exists",
      // independent of whether the notification email succeeds.
      final ref = await FirebaseFirestore.instance.collection('invites').add({
        'fromUid': currentUser.uid,
        'fromName': currentUser.displayName ?? 'A Sawata user',
        'fromEmail': currentUser.email ?? '',
        'toEmail': email,
        'toName': name,
        'toPhone': _phoneController.text.trim(),
        'relationship': relationship,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      final docId = ref.id;

      // Step 2: notify the guardian by email. Failure here does NOT roll
      // back the saved invitation above — it just means the guardian
      // hasn't been told about it yet (they can be resent, or the protege
      // can share the link another way).
      final result = await EmailService.sendGuardianInvite(
        toEmail: email,
        guardianName: name,
        userName: currentUser.displayName ?? 'A Sawata user',
        appLink: AppConfig.guardianInvitesLink,
      );
      if (!mounted) return;
      if (!result.success) {
        // Don't advance to "Invitation Sent!" or mark the invite as sent
        // anywhere the rest of the app reads that state from — the
        // guardian was never actually notified.
        _inviteDocId = docId;
        showAppSnackBar(
          context,
          _guardianInviteErrorMessage(result),
          isSuccess: false,
        );
        return;
      }
      setState(() {
        _sentAt = DateTime.now();
        _inviteDocId = docId;
        _currentStep = 2;
        store.myGuardianInvite = PendingGuardianInvite(
          name: name,
          email: email,
          phone: _phoneController.text.trim(),
          relationship: relationship,
          sentAt: _sentAt!,
          fromUid: currentUser.uid,
        );
        store.myGuardianInviteAccepted = false;
        store.pendingGuardianInvites += 1;
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Maps an [EmailResult] failure to a message a user can act on, without
  /// leaking transport internals (HTTP status/provider response body).
  String _guardianInviteErrorMessage(EmailResult result) {
    switch (result.errorCode) {
      case EmailErrorCode.notConfigured:
        return "Couldn't send the invitation email — email sending isn't "
            'configured on this build.';
      case EmailErrorCode.invalidRecipient:
        return "That guardian's email address looks invalid.";
      case EmailErrorCode.rateLimited:
        return "You've sent too many invites to this email recently. "
            'Try again later.';
      case EmailErrorCode.rejected:
        return 'The email provider rejected the invitation. Please try '
            'again later.';
      case EmailErrorCode.transportError:
        return 'Network error while sending the invitation. Check your '
            'connection and try again.';
      case EmailErrorCode.unknown:
      case null:
        return "Couldn't send the invitation email. Please try again.";
    }
  }

  Future<void> _resendInvitation() async {
    if (_isResending) return;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final currentUser = FirebaseAuth.instance.currentUser;
    final docId = _inviteDocId;
    if (docId == null) {
      showAppSnackBar(
        context,
        "Couldn't find this invitation to resend. Please send a new one.",
        isSuccess: false,
      );
      return;
    }
    setState(() => _isResending = true);
    try {
      final result = await EmailService.sendGuardianInvite(
        toEmail: email,
        guardianName: name,
        userName: currentUser?.displayName ?? 'A Sawata user',
        appLink: AppConfig.guardianInvitesLink,
      );
      if (!mounted) return;
      if (!result.success) {
        showAppSnackBar(context, _guardianInviteErrorMessage(result), isSuccess: false);
        return;
      }
      await FirebaseFirestore.instance
          .collection('invites')
          .doc(docId)
          .update({'resentAt': FieldValue.serverTimestamp()});
      if (!mounted) return;
      setState(() => _sentAt = DateTime.now());
      showAppSnackBar(context, 'Invitation resent to $email');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _cancelInvitation() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel invitation?',
      message: 'This will remove the pending invitation you sent to '
          '${_nameController.text.trim()}.',
      confirmLabel: 'Cancel Invitation',
    );
    if (!confirmed || !mounted) return;
    final docId = _inviteDocId;
    if (docId != null) {
      await FirebaseFirestore.instance
          .collection('invites')
          .doc(docId)
          .update({'status': 'cancelled'});
    }
    if (store.myGuardianInvite != null) {
      setState(() {
        store.myGuardianInvite = null;
        store.pendingGuardianInvites -= 1;
      });
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _handleBack() {
    if (_currentStep == 0) {
      Navigator.of(context).pop();
    } else {
      _goToStep(_currentStep - 1);
    }
  }

  (String, String, Widget) _headerFor(int step) => switch (step) {
    0 => (
      'Add a Guardian',
      'Choose someone you trust to support your recovery.',
      const GuardianIllustration(),
    ),
    1 => (
      'Review Details',
      'Please review the information before sending the invitation.',
      const GuardianStepIcon(
        icon: Icons.assignment_outlined,
        badgeIcon: Icons.check,
      ),
    ),
    2 => (
      'Invitation Sent!',
      "We've sent an invitation to your guardian.",
      const GuardianStepIcon(
        icon: Icons.send_outlined,
        badgeIcon: Icons.check,
        sparkles: true,
      ),
    ),
    _ => (
      'Guardian Status',
      _isAccepted
          ? 'Your guardian has accepted your invitation!'
          : "Your guardian hasn't accepted the invitation yet.",
      GuardianStepIcon(
        icon: _isAccepted ? Icons.verified_user : Icons.hourglass_top_outlined,
        sparkles: true,
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, headerIcon) = _headerFor(_currentStep);

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                _BackButton(onTap: _handleBack),
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'images/sawata_guardian_logo.png',
                      height: 40,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () =>
                      showAppSnackBar(context, "You're all caught up!"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _deepTeal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF5B7269),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                headerIcon,
              ],
            ),
            const SizedBox(height: 20),
            GuardianStepProgress(currentStep: _currentStep),
            const SizedBox(height: 22),
            switch (_currentStep) {
              0 => _GuardianInfoStep(
                formKey: _formKey,
                nameController: _nameController,
                emailController: _emailController,
                phoneController: _phoneController,
                relationship: _relationship,
                showRelationshipError: _showRelationshipError,
                onPickRelationship: _pickRelationship,
                validateName: _validateName,
                validateEmail: _validateEmail,
                onContinue: _handleContinueFromInfo,
              ),
              1 => _ReviewStep(
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                phone: _phoneController.text.trim(),
                relationship: _relationship ?? '—',
                onEdit: () => _goToStep(0),
                onSend: _sendInvitation,
              ),
              2 => _InvitationSentStep(
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                onDone: () => _goToStep(3),
                onResend: _resendInvitation,
              ),
              _ => _GuardianStatusStep(
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                relationship: _relationship ?? '—',
                sentDateLabel: _sentAt == null ? '—' : _formatDate(_sentAt!),
                sentTimeLabel: _sentAt == null ? '—' : _formatTime(_sentAt!),
                isAccepted: _isAccepted,
                onCheckStatus: _checkStatus,
                onResend: _resendInvitation,
                onCancel: _cancelInvitation,
                onViewGuardian: () => Navigator.of(
                  context,
                ).pushReplacementNamed(AppRoutes.guardianContact),
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFDDEEE7),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.arrow_back, size: 20, color: Color(0xFF16332B)),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GuardianInfoStep extends StatelessWidget {
  const _GuardianInfoStep({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.relationship,
    required this.showRelationshipError,
    required this.onPickRelationship,
    required this.validateName,
    required this.validateEmail,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final String? relationship;
  final bool showRelationshipError;
  final VoidCallback onPickRelationship;
  final String? Function(String?) validateName;
  final String? Function(String?) validateEmail;
  final VoidCallback onContinue;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Guardian Information',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _deepTeal,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Enter your guardian's details. They will receive an "
                  'invitation to connect.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B7269)),
                ),
                const SizedBox(height: 16),
                GuardianFormField(
                  label: "Guardian's Full Name",
                  hint: "Enter your guardian's full name",
                  icon: Icons.person_outline,
                  controller: nameController,
                  validator: validateName,
                ),
                const SizedBox(height: 14),
                GuardianFormField(
                  label: 'Email Address',
                  hint: 'Enter email address',
                  icon: Icons.mail_outline,
                  required: true,
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                  helperText: 'Required. This is where the invitation will be sent.',
                ),
                const SizedBox(height: 14),
                GuardianFormField(
                  label: 'Phone Number (Optional)',
                  hint: 'Enter phone number',
                  icon: Icons.call_outlined,
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                GuardianFormField(
                  key: ValueKey(relationship),
                  label: 'Relationship',
                  hint: 'Select relationship',
                  icon: Icons.people_outline,
                  required: true,
                  readOnly: true,
                  onTap: onPickRelationship,
                  trailing: const Icon(Icons.keyboard_arrow_down),
                  initialValue: relationship,
                  errorText: showRelationshipError
                      ? "Please select your guardian's relationship to you."
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFDDEEE7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: _accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your privacy is important.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: _deepTeal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Your guardian will only see your recovery progress, '
                      'alerts, and milestones — never your personal entries.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF5B7269)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(label: 'Continue', onPressed: onContinue),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.name,
    required this.email,
    required this.phone,
    required this.relationship,
    required this.onEdit,
    required this.onSend,
  });

  final String name;
  final String email;
  final String phone;
  final String relationship;
  final VoidCallback onEdit;
  final VoidCallback onSend;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);

  static const _permissions = [
    'Receive recovery alerts',
    'View recovery streak',
    'View blocked attempts',
    'Receive uninstall notifications',
    'Send encouragement',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Guardian Information',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _deepTeal,
                ),
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.person_outline,
                label: "Guardian's Full Name",
                value: name.isEmpty ? '—' : name,
              ),
              _InfoRow(
                icon: Icons.mail_outline,
                label: 'Email Address',
                value: email.isEmpty ? '—' : email,
              ),
              _InfoRow(
                icon: Icons.call_outlined,
                label: 'Phone Number',
                value: phone.isEmpty ? 'Not provided' : phone,
              ),
              _InfoRow(
                icon: Icons.people_outline,
                label: 'Relationship',
                value: relationship,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Guardian Permissions',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _deepTeal,
                ),
              ),
              const SizedBox(height: 12),
              for (final permission in _permissions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.check,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        permission,
                        style: const TextStyle(fontSize: 13, color: _deepTeal),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _OutlinedButton(
          label: 'Edit Information',
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        const SizedBox(height: 10),
        _PrimaryButton(label: 'Send Invitation', onPressed: onSend),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  static const _deepTeal = Color(0xFF16332B);
  static const _muted = Color(0xFF5B7269);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x14000000))),
            ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: _muted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _deepTeal,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationSentStep extends StatelessWidget {
  const _InvitationSentStep({
    required this.name,
    required this.email,
    required this.onDone,
    required this.onResend,
  });

  final String name;
  final String email;
  final VoidCallback onDone;
  final VoidCallback onResend;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);
  static const _muted = Color(0xFF5B7269);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Invitation sent to',
                style: TextStyle(fontSize: 12.5, color: _muted),
              ),
              const SizedBox(height: 2),
              Text(
                name.isEmpty ? 'your guardian' : name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: _deepTeal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: const TextStyle(fontSize: 12.5, color: _muted),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDEEE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: _accent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Waiting for your guardian to accept the invitation.',
                        style: TextStyle(fontSize: 12, color: _deepTeal),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(label: 'Done', onPressed: onDone),
        const SizedBox(height: 10),
        _OutlinedButton(
          label: 'Resend Invitation',
          icon: Icons.refresh,
          onPressed: onResend,
        ),
      ],
    );
  }
}

class _GuardianStatusStep extends StatelessWidget {
  const _GuardianStatusStep({
    required this.name,
    required this.email,
    required this.relationship,
    required this.sentDateLabel,
    required this.sentTimeLabel,
    required this.isAccepted,
    required this.onCheckStatus,
    required this.onResend,
    required this.onCancel,
    required this.onViewGuardian,
  });

  final String name;
  final String email;
  final String relationship;
  final String sentDateLabel;
  final String sentTimeLabel;
  final bool isAccepted;
  final VoidCallback onCheckStatus;
  final VoidCallback onResend;
  final VoidCallback onCancel;
  final VoidCallback onViewGuardian;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);
  static const _muted = Color(0xFF5B7269);
  static const _amber = Color(0xFFB07A1E);
  static const _amberBg = Color(0xFFFCEFD2);
  static const _mintBg = Color(0xFFDDEEE7);

  static const _willReceive = [
    'Uninstall alerts',
    'Recovery reports',
    'Blocked attempts',
    'Recovery streak',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDDEEE7),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_outline,
                      size: 24,
                      color: _accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Your guardian' : name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _deepTeal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isAccepted ? _mintBg : _amberBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAccepted ? Icons.check : Icons.hourglass_top,
                                size: 11,
                                color: isAccepted ? _accent : _amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isAccepted ? 'Active' : 'Pending Acceptance',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: isAccepted ? _accent : _amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                        Text(
                          relationship,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0x14000000)),
              const SizedBox(height: 12),
              const Text(
                'Invitation Sent',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: _deepTeal,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: _muted),
                  const SizedBox(width: 8),
                  Text(
                    sentDateLabel,
                    style: const TextStyle(fontSize: 12.5, color: _deepTeal),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: _muted),
                  const SizedBox(width: 8),
                  Text(
                    sentTimeLabel,
                    style: const TextStyle(fontSize: 12.5, color: _deepTeal),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFDDEEE7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: _accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAccepted
                          ? 'Your guardian now has access to:'
                          : 'Once accepted, your guardian will receive:',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: _deepTeal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final item in _willReceive)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '•  $item',
                          style: const TextStyle(fontSize: 11.5, color: _muted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (isAccepted)
          _PrimaryButton(label: 'View Guardian', onPressed: onViewGuardian)
        else ...[
          _OutlinedButton(
            label: 'Check Status',
            icon: Icons.refresh,
            onPressed: onCheckStatus,
          ),
          const SizedBox(height: 10),
          _OutlinedButton(
            label: 'Resend Invitation',
            icon: Icons.mail_outline,
            onPressed: onResend,
          ),
          const SizedBox(height: 10),
          _OutlinedButton(
            label: 'Cancel Invitation',
            icon: Icons.delete_outline,
            onPressed: onCancel,
            color: const Color(0xFFC0392B),
          ),
        ],
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16332B), Color(0xFF2E7D6B)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFF2E7D6B),
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon, size: 17),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
    );
  }
}
