// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// Sends the browser to the Next.js student dashboard at `/student/`.
///
/// The Flutter web app (`/app/`) and the Next.js dashboard (`/student/`) are the
/// same origin and share the same Firebase project, so the signed-in session
/// carries over — the student lands on the Next.js dashboard without logging in
/// again. `replace` (not `assign`) so the browser Back button does not bounce
/// them back to the Flutter app.
void redirectToStudentWebApp() {
  html.window.location.replace('/student/');
}

