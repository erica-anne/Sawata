import 'package:flutter/material.dart';

import 'package:sawata/app/routes.dart';
import 'package:sawata/widgets/apple_sign_in_button.dart';
import 'package:sawata/widgets/google_sign_in_button.dart';
import 'package:sawata/widgets/or_divider.dart';
import 'package:sawata/widgets/snackbar_helper.dart';
import 'widgets/auth_backdrop.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isGuardianMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your email';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    return null;
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final destination = _isGuardianMode
        ? AppRoutes.guardianDashboard
        : AppRoutes.home;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(destination, (route) => false);
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    showAppSnackBar(context, 'Signed in with Google');
    final destination = _isGuardianMode
        ? AppRoutes.guardianDashboard
        : AppRoutes.home;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(destination, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackdrop()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 12),
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
                          Center(
                            child: Image.asset(
                              'images/sawata_logo.png',
                              width: 170,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'A smart gambling blocker that helps you stay protected '
                            'and support your recovery.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF5B7269),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _AuthModeToggle(
                            isGuardian: _isGuardianMode,
                            onChanged: (value) =>
                                setState(() => _isGuardianMode = value),
                          ),
                          const SizedBox(height: 20),
                          AuthField(
                            label: 'Email',
                            hint: 'Enter your email',
                            icon: Icons.mail_outline,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 14),
                          AuthField(
                            label: 'Password',
                            hint: 'Enter your password',
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
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              SizedBox(
                                height: 22,
                                width: 22,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: _accent,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  onChanged: (value) => setState(
                                    () => _rememberMe = value ?? true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Remember me',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _deepTeal,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () {},
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          AuthGradientButton(
                            label: 'Log In',
                            icon: Icons.lock_outline,
                            isLoading: _isLoading,
                            onPressed: _isGoogleLoading ? null : _continue,
                          ),
                          const SizedBox(height: 22),
                          const OrDivider(label: 'or continue with'),
                          const SizedBox(height: 18),
                          GoogleSignInButton(
                            label: 'Continue with Google',
                            isLoading: _isGoogleLoading,
                            onPressed: _isLoading ? null : _continueWithGoogle,
                          ),
                          const SizedBox(height: 12),
                          AppleSignInButton(
                            label: 'Continue with Apple',
                            onPressed: () {},
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(
                                context,
                              ).pushReplacementNamed(AppRoutes.register),
                              child: const Text.rich(
                                TextSpan(
                                  text: "Don't have an account?  ",
                                  style: TextStyle(color: _deepTeal),
                                  children: [
                                    TextSpan(
                                      text: 'Sign Up',
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

/// Pill switcher between the User and Guardian login modes. Purely visual —
/// no submit-time behavior is tied to it yet.
class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.isGuardian, required this.onChanged});

  final bool isGuardian;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              selected: !isGuardian,
              icon: Icons.person,
              label: 'User Login',
              onTap: () => onChanged(false),
            ),
          ),
          Container(width: 1, height: 26, color: Colors.black12),
          Expanded(
            child: _Segment(
              selected: isGuardian,
              icon: Icons.groups_outlined,
              label: 'Guardian Login',
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF16332B), Color(0xFF2E7D6B)],
                  )
                : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : const Color(0xFF2E7D6B),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: selected ? Colors.white : const Color(0xFF2E7D6B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
