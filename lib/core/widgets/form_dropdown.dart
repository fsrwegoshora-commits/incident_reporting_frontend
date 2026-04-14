import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A data item for [FormDropdown].
class DropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  const DropdownItem({required this.value, required this.label, this.icon});
}

/// Styled DropdownButtonFormField using AppTheme decoration.
///
/// ```dart
/// FormDropdown<String>(
///   label: 'Rank',
///   icon: Icons.military_tech_outlined,
///   value: _rank,
///   items: ranks.map((r) => DropdownItem(value: r.id, label: r.name)).toList(),
///   onChanged: (v) => setState(() => _rank = v),
/// )
/// ```
class FormDropdown<T> extends StatelessWidget {
  final String label;
  final IconData? icon;
  final T? value;
  final List<DropdownItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final String? hint;
  final bool isLoading;
  final bool enabled;

  const FormDropdown({
    super.key,
    required this.label,
    this.icon,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.hint,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decoration = isDark
        ? AppTheme.getDarkInputDecoration(labelText: label, hintText: hint, prefixIcon: icon)
        : AppTheme.getInputDecoration(labelText: label, hintText: hint, prefixIcon: icon);

    if (isLoading) {
      return InputDecorator(
        decoration: decoration,
        child: Row(children: [
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: AppTheme.spaceS),
          Text('Loading…', style: AppTheme.bodyMedium),
        ]),
      );
    }

    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      style: isDark ? AppTheme.darkBodyLarge : AppTheme.bodyLarge,
      decoration: decoration,
      items: items.map((item) => DropdownMenuItem<T>(
        value: item.value,
        child: Row(children: [
          if (item.icon != null) ...[
            Icon(item.icon, size: 15, color: AppTheme.gray400),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(item.label, style: AppTheme.bodyLarge, overflow: TextOverflow.ellipsis),
          ),
        ]),
      )).toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }
}
