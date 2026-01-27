import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/version_service.dart';
import 'force_update_dialog.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Wrapper widget that checks for required updates on mobile platforms
class VersionCheckWrapper extends StatefulWidget {
  final Widget child;

  const VersionCheckWrapper({
    super.key,
    required this.child,
  });

  @override
  State<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends State<VersionCheckWrapper>
    with WidgetsBindingObserver {
  bool _updateRequired = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdate(showLoading: false);
    }
  }

  Future<void> _checkForUpdate({bool showLoading = true}) async {
    // Only check for mobile platforms (skip web)
    if (kIsWeb) {
      setState(() {
        _checking = false;
      });
      return;
    }

    try {
      if (showLoading && mounted) {
        setState(() {
          _checking = true;
        });
      }

      final updateRequired = await VersionService.isUpdateRequired();
      if (mounted) {
        setState(() {
          _updateRequired = updateRequired;
          _checking = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error checking for update: $e');
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking
    if (_checking) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.checkingForUpdates),
              ],
            ),
          ),
        ),
      );
    }

    // Show force update screen if update is required
    if (_updateRequired) {
      return MaterialApp(
        home: ForceUpdateScreen(),
      );
    }

    // No update required, show the normal app
    return widget.child;
  }
}
