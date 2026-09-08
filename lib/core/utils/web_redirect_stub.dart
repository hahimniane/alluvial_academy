/// Fallback for non-web builds (iOS/Android): there is no browser to redirect,
/// so these do nothing. The real implementations live in web_redirect_web.dart
/// and are chosen by a conditional import on `dart.library.html`.
void redirectToWebApp(String path) {}

void redirectToStudentWebApp() {}

void redirectToTeacherWebApp() {}
