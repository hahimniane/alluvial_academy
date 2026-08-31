import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sends the browser to the public site at the domain root. Web only.
///
/// On the web the Flutter app is mounted under `/app/` and the public site is
/// the Next.js app at the root. Flutter's own landing page is a leftover
/// duplicate of that homepage, so anything that would land there should leave
/// the app instead.
///
/// The destination is resolved from the current page rather than hardcoded, so
/// this behaves correctly on the production domain, on the live subdomain and
/// in local builds without any configuration.
///
/// Returns false on mobile, or if the browser refused the navigation, so
/// callers can fall back to in-app routing.
Future<bool> leaveToPublicSite() async {
  if (!kIsWeb) return false;
  try {
    return await launchUrl(Uri.base.resolve('/'), webOnlyWindowName: '_self');
  } catch (_) {
    return false;
  }
}

/// Where to send someone after they sign out.
///
/// On mobile there is no surrounding website, so the in-app landing route
/// remains the right destination.
Future<void> leaveToPublicSiteAfterSignOut(BuildContext context) async {
  if (await leaveToPublicSite()) return;

  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}
