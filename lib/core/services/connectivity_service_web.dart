/// Web platform implementation for internet connectivity check
/// Web browsers have their own connectivity indicators, so we assume connection is available
Future<bool> checkInternetConnection() async {
  // On web, always return true
  // The browser will handle actual connectivity and show its own offline indicators
  return true;
}

