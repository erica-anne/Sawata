import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/services/auth_email_service.dart';
import 'package:sawata/services/user_data_service.dart';
import 'package:sawata/widgets/google_sign_in_button.dart';
import 'package:sawata/widgets/or_divider.dart';
import 'package:sawata/widgets/snackbar_helper.dart';
import 'widgets/auth_backdrop.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_gradient_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  String? _selectedRole;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your email';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please create a password';
    if (value.length < 8) return 'Use at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _createAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreedToTerms) {
      showAppSnackBar(context, 'Please agree to the Terms and Privacy Policy');
      return;
    }
    if (_selectedRole == null) {
      showAppSnackBar(context, 'Please select whether you are a User or Guardian');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      final user = credential.user;
      final name = _nameController.text.trim();
      if (user != null) {
        await user.updateDisplayName(name);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
              {
                'role': _selectedRole == 'Guardian' ? 'guardian' : 'user',
                'name': name,
                'email': user.email ?? '',
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
        if (_selectedRole != 'Guardian') {
          await UserDataService.ensureInitialized(user.uid);
        }
        try {
          await AuthEmailService.sendEmailVerification();
        } catch (_) {
          // Non-fatal — the account still exists; user can verify later.
        }
      }
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Account created. Check your email to verify your address.',
      );
      final destination = _selectedRole == 'Guardian'
          ? AppRoutes.guardianDashboard
          : AppRoutes.home;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(destination, (route) => false);
    } on FirebaseAuthException catch (e) {
      if (mounted) showAppSnackBar(context, _authErrorMessage(e));
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Account creation failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      default:
        return e.message ?? 'Account creation failed. Please try again.';
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'role': _selectedRole == 'Guardian' ? 'guardian' : 'user',
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        if (_selectedRole != 'Guardian') {
          await UserDataService.ensureInitialized(user.uid);
        }
      }
      if (!mounted) return;
      showAppSnackBar(context, 'Account created with Google. Welcome to Sawatâ!');
      final destination = _selectedRole == 'Guardian'
          ? AppRoutes.guardianDashboard
          : AppRoutes.home;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(destination, (route) => false);
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
        showAppSnackBar(context, 'Google sign-in failed. Please try again.');
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _pickRole() async {
    final role = await showModalBottomSheet<String>(
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
                  'Select your role',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: _accent),
              title: const Text('User'),
              subtitle: const Text('I want to build my own recovery streak'),
              onTap: () => Navigator.of(context).pop('User'),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined, color: _accent),
              title: const Text('Guardian'),
              subtitle: const Text("I'm supporting someone else's recovery"),
              onTap: () => Navigator.of(context).pop('Guardian'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (role != null) setState(() => _selectedRole = role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackdrop()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BackButton(
                                onTap: () => Navigator.of(
                                  context,
                                ).pushReplacementNamed(AppRoutes.login),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Create Your Account',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: _deepTeal,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Start your recovery journey with Sawatâ.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF5B7269),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Image.asset(
                              'images/sawata_logo.png',
                              width: 150,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _SectionHeader(
                                  icon: Icons.person_outline,
                                  label: 'Personal Information',
                                ),
                                const SizedBox(height: 14),
                                AuthField(
                                  label: 'Full Name',
                                  hint: 'Enter your full name',
                                  icon: Icons.person_outline,
                                  controller: _nameController,
                                  keyboardType: TextInputType.name,
                                  validator: _validateName,
                                ),
                                const SizedBox(height: 14),
                                AuthField(
                                  label: 'Email Address',
                                  hint: 'Enter your email address',
                                  icon: Icons.mail_outline,
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: 14),
                                AuthField(
                                  label: 'Password',
                                  hint: 'Create a strong password',
                                  icon: Icons.lock_outline,
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  validator: _validatePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                AuthField(
                                  label: 'Confirm Password',
                                  hint: 'Re-enter your password',
                                  icon: Icons.lock_outline,
                                  controller: _confirmController,
                                  obscureText: _obscureConfirm,
                                  validator: _validateConfirm,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const _PasswordRequirements(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const _SectionHeader(
                            icon: Icons.badge_outlined,
                            label: 'Additional Information',
                          ),
                          const SizedBox(height: 14),
                          _RoleField(value: _selectedRole, onTap: _pickRole),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 22,
                                width: 22,
                                child: Checkbox(
                                  value: _agreedToTerms,
                                  activeColor: _accent,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  onChanged: (value) => setState(
                                    () => _agreedToTerms = value ?? false,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'I agree to the ',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: _deepTeal,
                                        height: 1.4,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Terms of Service',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: _accent,
                                          ),
                                        ),
                                        TextSpan(text: ' and '),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: _accent,
                                          ),
                                        ),
                                        TextSpan(text: '.'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          AuthGradientButton(
                            label: 'Create Account',
                            icon: Icons.person_add_alt_1,
                            isLoading: _isLoading,
                            onPressed: _isGoogleLoading ? null : _createAccount,
                          ),
                          const SizedBox(height: 22),
                          const OrDivider(label: 'or continue with'),
                          const SizedBox(height: 18),
                          GoogleSignInButton(
                            label: 'Sign up with Google',
                            isLoading: _isGoogleLoading,
                            onPressed: _isLoading ? null : _continueWithGoogle,
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(
                                context,
                              ).pushReplacementNamed(AppRoutes.login),
                              child: const Text.rich(
                                TextSpan(
                                  text: 'Already have an account?  ',
                                  style: TextStyle(color: _deepTeal),
                                  children: [
                                    TextSpan(
                                      text: 'Log In',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: _accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const AuthFooterArt(),
                ],
              ),
            ),
          ),
        ],
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFFDDEEE7),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: const Color(0xFF2E7D6B)),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            color: Color(0xFF16332B),
          ),
        ),
      ],
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements();

  static const _items = [
    'At least 8 characters',
    'One uppercase letter',
    'One number',
    'One special character',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF6F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF2E7D6B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password must contain:',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: Color(0xFF16332B),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    for (final item in _items)
                      SizedBox(
                        width: 140,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Color(0xFF2E7D6B),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF5B7269),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tap-to-pick role field, styled like [AuthField] but backed by a bottom
/// sheet instead of free text entry.
class _RoleField extends StatelessWidget {
  const _RoleField({required this.value, required this.onTap});

  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFDDEEE7),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.badge_outlined,
                  size: 17,
                  color: Color(0xFF2E7D6B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'I am a...',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: Color(0xFF16332B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ?? 'Select your role',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: value == null
                            ? const Color(0xFF8EA198)
                            : const Color(0xFF16332B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8EA198)),
            ],
          ),
        ),
      ),
    );
  }
}
