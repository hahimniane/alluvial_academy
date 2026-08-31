/**
 * Where signing in happens.
 *
 * During the migration the public site is Next and everything behind a login is
 * still the Flutter app on the main domain. Login therefore hands off to Flutter
 * rather than happening here: the user signs in on alluwaleducationhub.org and
 * stays there, so there is no cross-origin session to transfer.
 *
 * Override with NEXT_PUBLIC_FLUTTER_APP_URL when the Flutter app moves — for
 * example once the main domain is retired and it is served from a subpath.
 */
const DEFAULT_FLUTTER_APP_URL = "https://alluwaleducationhub.org/app";

export const flutterAppUrl = (
  process.env.NEXT_PUBLIC_FLUTTER_APP_URL || DEFAULT_FLUTTER_APP_URL
).replace(/\/+$/, "");

/** Flutter routes are hash-based, so the login screen is /#/login. */
export const flutterLoginUrl = `${flutterAppUrl}/#/login`;
