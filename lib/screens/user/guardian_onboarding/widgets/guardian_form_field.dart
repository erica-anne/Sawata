import 'package:flutter/material.dart';

/// Card-style form field with a leading icon badge, an always-floated
/// label (with an optional red "required" marker), and optional helper
/// text below — matches the auth screens' visual language.
class GuardianFormField extends StatelessWidget {
  const GuardianFormField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.controller,
    this.initialValue,
    this.required = false,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController? controller;

  /// Used instead of [controller] for a display-only field (e.g. a
  /// tap-to-pick value). Pass a new [Key] on the parent widget when this
  /// changes so it actually refreshes.
  final String? initialValue;
  final bool required;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? trailing;

  static const _deepTeal = Color(0xFF16332B);
  static const _accent = Color(0xFF2E7D6B);
  static const _muted = Color(0xFF5B7269);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
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
                child: Icon(icon, size: 17, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  initialValue: controller == null ? initialValue : null,
                  keyboardType: keyboardType,
                  validator: validator,
                  readOnly: readOnly,
                  onTap: onTap,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintText: hint,
                    hintStyle: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF8EA198),
                    ),
                    label: Text.rich(
                      TextSpan(
                        text: label,
                        children: required
                            ? const [
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                    color: Color(0xFFC0392B),
                                  ),
                                ),
                              ]
                            : null,
                      ),
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: _deepTeal,
                    ),
                    suffixIcon: trailing,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(fontSize: 11, color: Color(0xFFC0392B)),
            ),
          ),
        ] else if (helperText != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText!,
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ),
        ],
      ],
    );
  }
}
