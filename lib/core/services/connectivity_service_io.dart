import 'dart:async';
import 'dart:io';

/// IO platform implementation for internet connectivity check
Future<bool> checkInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('google.com')
        .timeout(const Duration(seconds: 5));
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  } on TimeoutException catch (_) {
    return false;
  } catch (e) {
    print('Error checking internet: $e');
    return false;
  }
}

