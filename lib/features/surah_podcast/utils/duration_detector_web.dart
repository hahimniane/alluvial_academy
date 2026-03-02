import 'dart:async';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

/// Uses the browser's native media element to read duration from file bytes.
Future<int> detectMediaDurationFromBytes(Uint8List bytes, String mimeType) async {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final completer = Completer<int>();

    final html.MediaElement media = mimeType.startsWith('video/')
        ? html.VideoElement()
        : html.AudioElement();

    media.preload = 'metadata';
    media.src = url;

    media.onLoadedMetadata.first.then((_) {
      final dur = media.duration;
      if (dur.isFinite && !dur.isNaN) {
        completer.complete(dur.round());
      } else {
        completer.complete(0);
      }
      html.Url.revokeObjectUrl(url);
      media.remove();
    });

    media.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(0);
      html.Url.revokeObjectUrl(url);
      media.remove();
    });

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => 0,
    );
  } catch (_) {
    return 0;
  }
}
