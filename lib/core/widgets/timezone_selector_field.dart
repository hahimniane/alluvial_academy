import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/timezone_utils.dart';
import 'timezone_selector_dialog.dart';

class TimezoneSelectorField extends StatelessWidget {
  final String? selectedTimezone;
  final ValueChanged<String> onTimezoneSelected;

  final String dialogTitle;
  final String placeholder;

  final BorderRadius borderRadius;
  final Color borderColor;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;

  final bool enabled;

  const TimezoneSelectorField({
    super.key,
    required this.selectedTimezone,
    required this.onTimezoneSelected,
    this.dialogTitle = 'Select Timezone',
    this.placeholder = 'Select timezone…',
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.borderColor = const Color(0xFFE2E8F0),
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.textStyle,
    this.placeholderStyle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = selectedTimezone == null
        ? null
        : TimezoneUtils.formatTimezoneForDisplay(selectedTimezone!);

    final effectiveTextStyle = textStyle ??
        GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xff111827),
        );
    final effectivePlaceholderStyle = placeholderStyle ??
        GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xff6B7280),
        );

    return InkWell(
      onTap: enabled ? () => _openDialog(context) : null,
      borderRadius: borderRadius,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: borderRadius,
          color: backgroundColor,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText ?? placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: displayText == null
                    ? effectivePlaceholderStyle
                    : effectiveTextStyle,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_drop_down,
              color:
                  enabled ? const Color(0xff6B7280) : const Color(0xff9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => TimezoneSelectorDialog(
        initialTimezone: selectedTimezone,
        title: dialogTitle,
      ),
    );

    if (selected == null) return;
    onTimezoneSelected(selected);
  }
}
