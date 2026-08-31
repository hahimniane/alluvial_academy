/// Fallback for non-web builds (iOS/Android): there is no browser to redirect,
/// so this does nothing. The real implementation lives in web_redirect_web.dart
/// and is chosen by a conditional import on `dart.library.html`.
void redirectToStudentWebApp() {}
