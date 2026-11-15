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
