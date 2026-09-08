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
