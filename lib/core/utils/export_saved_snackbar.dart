import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// SnackBar after saving an export on a native platform (path + copy action).
void showNativeExportSavedSnackBar(BuildContext context, String fullPath) {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  showNativeExportSavedWithMessenger(messenger, l10n, fullPath);
}

/// Same as [showNativeExportSavedSnackBar] when the dialog was already closed
/// (capture [messenger] and [l10n] before `Navigator.pop`).
void showNativeExportSavedWithMessenger(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  String fullPath,
) {
  final display =
      fullPath.length > 80 ? '${fullPath.substring(0, 77)}…' : fullPath;
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.exportSavedNativeBody(display)),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: l10n.copyToClipboard,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: fullPath));
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.chatCopied)),
          );
        },
      ),
    ),
  );
}
