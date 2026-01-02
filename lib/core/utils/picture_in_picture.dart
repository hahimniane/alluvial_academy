// ignore_for_file: avoid_web_libraries_in_flutter
// This file is only imported on web via conditional imports in livekit_service.dart

import 'dart:html' as html;
import 'dart:js_util' as js_util;

Future<bool> isPictureInPictureSupported() async {
  try {
    final enabled =
        js_util.getProperty(html.document, 'pictureInPictureEnabled');
    return enabled == true;
  } catch (_) {
    return false;
  }
}

Future<bool> isPictureInPictureActive() async {
  try {
    final element =
        js_util.getProperty(html.document, 'pictureInPictureElement');
    return element != null;
  } catch (_) {
    return false;
  }
}

Future<void> enterPictureInPictureByElementId(String elementId) async {
  final element = html.document.getElementById(elementId);
  if (element == null) {
    throw StateError('Video element not found: $elementId');
  }

  final promise = js_util.callMethod(element, 'requestPictureInPicture', []);
  await js_util.promiseToFuture(promise);
}

Future<void> exitPictureInPicture() async {
  final active = await isPictureInPictureActive();
  if (!active) return;

  final promise = js_util.callMethod(html.document, 'exitPictureInPicture', []);
  await js_util.promiseToFuture(promise);
}
