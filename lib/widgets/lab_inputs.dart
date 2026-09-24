import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

class LabLabel extends StatelessWidget {
  const LabLabel(this.text, {super.key, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(TextSpan(
          text: text,
          style: AppText.bodySm
              .copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w500),
          children: [
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
          ],
        )),
      );
}

/// Label above a filled field, per the Stitch forms. Quantities use the mono face.
class LabTextField extends StatelessWidget {
  const LabTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.suffix,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.mono = false,
    this.required = false,
    this.onChanged,
    this.inputFormatters,
    this.textInputAction,
    this.autofocus = false,
    this.obscure = false,
    this.enabled = true,
    this.helper,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool mono;
  final bool required;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool obscure;
  final bool enabled;
  final String? helper;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabLabel(label, required: required),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            maxLines: maxLines,
            onChanged: onChanged,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            autofocus: autofocus,
            obscureText: obscure,
            enabled: enabled,
            onFieldSubmitted: onSubmitted,
            style: mono ? AppText.monoLg : AppText.bodyMd.copyWith(fontSize: 14),
            decoration: InputDecoration(hintText: hint, suffixText: suffix, helperText: helper),
          ),
        ],
      );
}

class LabDropdown<T> extends StatelessWidget {
  const LabDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.hint,
    this.helper,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool required;
  final String? hint;
  final String? helper;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabLabel(label, required: required),
          InputDecorator(
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              helperText: helper,
              enabled: onChanged != null,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                hint: hint == null ? null : Text(hint!, style: AppText.bodyMd),
                items: items,
                onChanged: onChanged,
                style: AppText.bodyMd.copyWith(fontSize: 14),
                borderRadius: BorderRadius.circular(8),
                dropdownColor: AppColors.surfaceLowest,
              ),
            ),
          ),
        ],
      );
}

class LabDateField extends StatelessWidget {
  const LabDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabLabel(label, required: required),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value.isAfter(now) ? now : value,
                firstDate: DateTime(2000),
                lastDate: now,
              );
              if (picked == null) return;
              // keep a real clock time so same-day entries stay ordered
              onChanged(Fmt.isToday(picked)
                  ? now
                  : DateTime(picked.year, picked.month, picked.day, 12));
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(Fmt.date(value), style: AppText.monoLg),
            ),
          ),
        ],
      );
}

/// Digits, one decimal separator. Accepts "," as well as ".".
final decimalInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
];

double? parseDecimal(String? s) => double.tryParse((s ?? '').trim().replaceAll(',', '.'));
