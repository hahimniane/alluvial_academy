import 'package:flutter/foundation.dart' show kIsWeb;

class BuildInfo {
  static const String webBuildVersion =
      String.fromEnvironment('WEB_BUILD_VERSION', defaultValue: '');

  static bool get hasWebBuildVersion => kIsWeb && webBuildVersion.isNotEmpty;
}

