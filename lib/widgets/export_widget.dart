import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

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
        side: const BorderSide(color: Colors.blue),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text('Export',
          style: openSansHebrewTextStyle.copyWith(color: Colors.blue)),
    );
  }
}
