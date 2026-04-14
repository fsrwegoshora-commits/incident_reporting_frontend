import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Styled TextFormField — uses AppTheme.getInputDecoration automatically.
///
/// ```dart
/// FormTextInput(label: 'Full Name', icon: Icons.person_outline, controller: _nameCtrl)
/// PhoneTextInput(controller: _phoneCtrl)
/// ```
class FormTextInput extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final IconData? icon;
  final Widget? suffixIcon;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final int maxLines;
  final int? minLines;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool enabled;
  final int? maxLength;
  final TextInputAction? textInputAction;

  const FormTextInput({
    super.key,
    this.controller,
    required this.label,
    this.icon,
    this.suffixIcon,
    this.hint,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap = null,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.enabled = true,
    this.maxLength,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decoration = isDark
        ? AppTheme.getDarkInputDecoration(labelText: label, hintText: hint, prefixIcon: icon)
        : AppTheme.getInputDecoration(labelText: label, hintText: hint, prefixIcon: icon);

    return TextFormField(
      controller: controller,
      style: isDark ? AppTheme.darkBodyLarge : AppTheme.bodyLarge,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      focusNode: focusNode,
      textCapitalization: textCapitalization,
      autofocus: autofocus,
      enabled: enabled,
      maxLength: maxLength,
      textInputAction: textInputAction,
      decoration: decoration.copyWith(suffixIcon: suffixIcon),
      validator: validator,
    );
  }
}

/// Phone number input with +255 validation built in.
class PhoneTextInput extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const PhoneTextInput({
    super.key,
    this.controller,
    this.label = 'Phone Number',
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => FormTextInput(
    controller: controller,
    label: label,
    icon: Icons.phone_outlined,
    hint: '+255712345678',
    keyboardType: TextInputType.phone,
    onChanged: onChanged,
    validator: validator ??
        (v) {
          if (v == null || v.trim().isEmpty) return 'Phone number is required';
          if (!RegExp(r'^\+255\d{9}$').hasMatch(v.trim())) {
            return 'Enter a valid number (+255XXXXXXXXX)';
          }
          return null;
        },
  );
}
