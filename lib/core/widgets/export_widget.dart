import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/core/constants/app_constants.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ExportWidget extends StatelessWidget {
  const ExportWidget({
    super.key,
    required this.onExport,
  });

  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onExport, // Handle export button press
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const BorderSide(color: Colors.blue),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(AppLocalizations.of(context)!.commonExport,
          style: openSansHebrewTextStyle.copyWith(
            color: Colors.blue,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}
