// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// Sends the browser to a path on the Next.js app (same origin as `/app/`).
///
/// The Flutter web app and the Next.js dashboards share an origin and a
/// Firebase project, so the signed-in session carries over and the person lands
/// already authenticated. `replace` (not `assign`) so the Back button does not
/// bounce them straight back into Flutter.
void redirectToWebApp(String path) {
  html.window.location.replace(path);
}

/// The Next.js student dashboard.
void redirectToStudentWebApp() => redirectToWebApp('/student/');

/// The Next.js teacher console.
void redirectToTeacherWebApp() => redirectToWebApp('/teacher/');

/// Sends a moved parent to the web parent area. A class link that was still
/// waiting to be opened goes to the web join page instead of the home page.
void redirectToParentWebApp({String? joinShiftId}) => redirectToWebApp(
      joinShiftId == null || joinShiftId.isEmpty
          ? '/parent/'
          : '/parent/classroom/?shiftId=${Uri.encodeQueryComponent(joinShiftId)}',
    );

/// Google sign-in on the web runs on the Next.js page /login/google/.
///
/// /app/ is cross-origin isolated (COOP same-origin) for the Zoom SDK, which
/// severs the link to Google's sign-in popup — the plugin sees it as closed
/// the moment it opens. That page sits outside /app/, signs in with the same
/// Firebase project and storage, and sends the person on to their dashboard.
/// `assign` so Back returns to this login screen.
void openWebGoogleSignIn() => html.window.location.assign('/login/google/');
