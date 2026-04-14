import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tappable date field using GestureDetector + AbsorbPointer pattern.
///
/// ```dart
/// FormDatePicker(
///   label: 'Appointment Date',
///   value: _date,
///   onPicked: (d) => setState(() => _date = d),
/// )
/// ```
class FormDatePicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? value;
  final void Function(DateTime) onPicked;
  final String? Function(String?)? validator;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? helpText;
  final bool required;

  const FormDatePicker({
    super.key,
    required this.label,
    this.icon = Icons.calendar_today_outlined,
    required this.value,
    required this.onPicked,
    this.validator,
    this.firstDate,
    this.lastDate,
    this.helpText,
    this.required = false,
  });

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dec = isDark
        ? AppTheme.getDarkInputDecoration(labelText: label, prefixIcon: icon)
        : AppTheme.getInputDecoration(labelText: label, prefixIcon: icon);

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime(2100),
          helpText: helpText,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppTheme.primaryBlue),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      child: AbsorbPointer(
        child: TextFormField(
          style: isDark ? AppTheme.darkBodyLarge : AppTheme.bodyLarge,
          readOnly: true,
          controller: TextEditingController(text: value != null ? _fmt(value!) : ''),
          decoration: dec.copyWith(
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppTheme.gray400, size: 20),
          ),
          validator: validator ??
              (required ? (_) => value == null ? '$label is required' : null : null),
        ),
      ),
    );
  }
}

/// Two [FormDatePicker]s side-by-side for a date range.
class FormDateRangePicker extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(DateTime) onStartPicked;
  final void Function(DateTime) onEndPicked;
  final String startLabel;
  final String endLabel;
  final bool endRequired;

  const FormDateRangePicker({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onStartPicked,
    required this.onEndPicked,
    this.startLabel = 'Start Date',
    this.endLabel = 'End Date',
    this.endRequired = false,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: FormDatePicker(
      label: startLabel, value: startDate, onPicked: onStartPicked,
    )),
    const SizedBox(width: AppTheme.spaceM),
    Expanded(child: FormDatePicker(
      label: endLabel, value: endDate, onPicked: onEndPicked,
      required: endRequired,
      validator: endRequired ? (_) => endDate == null ? 'Required' : null : null,
    )),
  ]);
}
