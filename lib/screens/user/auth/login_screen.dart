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
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = credential.user;
      if (user == null) return;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isGuardian = userDoc.data()?['role'] == 'guardian';
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!isGuardian) {
        await UserDataService.ensureInitialized(user.uid);
      }
      if (!mounted) return;
      final destination = isGuardian
          ? AppRoutes.guardianDashboard
          : AppRoutes.home;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(destination, (route) => false);
    } on FirebaseAuthException catch (e) {
      if (mounted) showAppSnackBar(context, _authErrorMessage(e));
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Login failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Login failed. Please try again.';
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailController.text);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Enter your email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !_emailPattern.hasMatch(email)) {
      return;
    }
    try {
      await AuthEmailService.sendPasswordResetEmail(email);
      if (mounted) {
        showAppSnackBar(context, 'Password reset link sent to $email');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) showAppSnackBar(context, _authErrorMessage(e));
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Failed to send reset link. Try again.');
      }
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
      if (user == null) return;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isGuardian = userDoc.data()?['role'] == 'guardian';
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        if (!userDoc.exists) 'role': 'user',
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!isGuardian) {
        await UserDataService.ensureInitialized(user.uid);
      }
      if (!mounted) return;
      showAppSnackBar(context, 'Signed in with Google');
      final destination = isGuardian
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                          () => _obscurePassword =
                                              !_obscurePassword,
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
                                            visualDensity:
                                                VisualDensity.compact,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(5),
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
                                          onPressed: _forgotPassword,
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
                                      onPressed: _isGoogleLoading
                                          ? null
                                          : _continue,
                                    ),
                                    const SizedBox(height: 22),
                                    const OrDivider(label: 'or continue with'),
                                    const SizedBox(height: 18),
                                    GoogleSignInButton(
                                      label: 'Continue with Google',
                                      isLoading: _isGoogleLoading,
                                      onPressed: _isLoading
                                          ? null
                                          : _continueWithGoogle,
                                    ),
                                    const SizedBox(height: 18),
                                    Center(
                                      child: TextButton(
                                        onPressed: () => Navigator.of(context)
                                            .pushReplacementNamed(
                                              AppRoutes.register,
                                            ),
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
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const AuthFooterArt(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
