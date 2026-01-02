Future<bool> isPictureInPictureSupported() async => false;

Future<bool> isPictureInPictureActive() async => false;

Future<void> enterPictureInPictureByElementId(String elementId) async {
  throw UnsupportedError('Picture-in-picture is only available on web.');
}

Future<void> exitPictureInPicture() async {}
