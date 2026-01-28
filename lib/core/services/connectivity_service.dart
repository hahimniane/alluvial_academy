import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import connectivity helper based on platform
import 'connectivity_service_io.dart'
    if (dart.library.html) 'connectivity_service_web.dart' as platform;
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Service to check and monitor internet connectivity
class ConnectivityService {
  static bool _hasShownNoInternetDialog = false;

  /// Check if the app has internet connection
  static Future<bool> hasInternetConnection() async {
    return await platform.checkInternetConnection();
  }

  /// Show no internet dialog
  static Future<void> showNoInternetDialog(BuildContext context) async {
    if (_hasShownNoInternetDialog) return;
    _hasShownNoInternetDialog = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xffEF4444),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.noInternet,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.thisAppRequiresAnActiveInternet,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xff6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xffFECACA),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.pleaseCheck,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xffB91C1C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCheckItem('WiFi is turned on'),
                      _buildCheckItem('Mobile data is enabled'),
                      _buildCheckItem('Airplane mode is off'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  // Check connection again
                  final hasInternet = await hasInternetConnection();
                  if (hasInternet) {
                    _hasShownNoInternetDialog = false;
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  } else {
                    // Show snackbar if still no internet
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.stillNoInternetConnectionPleaseTry,
                            style: GoogleFonts.inter(),
                          ),
                          backgroundColor: const Color(0xffEF4444),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0386FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.commonRetry,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: Color(0xffB91C1C),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xff991B1B),
            ),
          ),
        ],
      ),
    );
  }

  /// Monitor connectivity and show dialog if lost
  static void startMonitoring(BuildContext context) {
    // Skip monitoring on web - browsers handle connectivity
    if (kIsWeb) return;

    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!context.mounted) {
        timer.cancel();
        return;
      }

      final hasInternet = await hasInternetConnection();
      if (!hasInternet && context.mounted) {
        showNoInternetDialog(context);
      }
    });
  }
}

