import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import '../services/language_service.dart';
import '../services/version_service.dart';
import 'force_update_dialog.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

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
  VersionGateDecision? _decision;
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

      final decision = await VersionService.getUpdateDecision();
      if (mounted) {
        setState(() {
          _decision = decision;
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
      return _buildShell(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Checking for updates...'),
              ],
            ),
          ),
        ),
      );
    }

    // Show force update screen if update is required
    if (_decision?.updateRequired == true) {
      return _buildShell(
        home: ForceUpdateScreen(decision: _decision!),
      );
    }

    // No update required, show the normal app
    return widget.child;
  }

  Widget _buildShell({required Widget home}) {
    return MaterialApp(
      locale: WidgetsBinding.instance.platformDispatcher.locale,
      supportedLocales: LanguageService.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
      debugShowCheckedModeBanner: false,
    );
  }
}
