/// A short "you got it right" chime, synthesised at runtime.
///
/// Generating the tone in code keeps a binary sound file out of the repo and
/// out of the app bundle, and it plays identically on every platform.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

class BayanahChime {
  static final AudioPlayer _player = AudioPlayer();
  static Uint8List? _cached;

  /// Two rising notes — the sound of getting something right.
  static Uint8List _buildWav() {
    const sampleRate = 44100;
    const notes = [
      (freq: 784.0, ms: 110), // G5
      (freq: 1046.5, ms: 220), // C6
    ];
    final samples = <int>[];
    for (final note in notes) {
      final count = (sampleRate * note.ms / 1000).round();
      for (var i = 0; i < count; i++) {
        final t = i / sampleRate;
        // Fade each note out so it ends softly instead of clicking.
        final envelope = math.pow(1 - (i / count), 1.6).toDouble();
        final value = math.sin(2 * math.pi * note.freq * t) * envelope * 0.35;
        samples.add((value * 32767).round().clamp(-32768, 32767));
      }
    }

    final dataBytes = samples.length * 2;
    final bytes = BytesBuilder();
    void str(String s) => bytes.add(s.codeUnits);
    void u32(int v) => bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
    void u16(int v) => bytes.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

    str('RIFF');
    u32(36 + dataBytes);
    str('WAVE');
    str('fmt ');
    u32(16); // PCM header size
    u16(1); // PCM
    u16(1); // mono
    u32(sampleRate);
    u32(sampleRate * 2); // byte rate
    u16(2); // block align
    u16(16); // bits per sample
    str('data');
    u32(dataBytes);
    final pcm = Uint8List(dataBytes);
    final view = pcm.buffer.asByteData();
    for (var i = 0; i < samples.length; i++) {
      view.setInt16(i * 2, samples[i], Endian.little);
    }
    bytes.add(pcm);
    return bytes.toBytes();
  }

  static Future<void> playCorrect() async {
    try {
      _cached ??= _buildWav();
      await _player.stop();
      await _player.play(BytesSource(_cached!));
    } catch (_) {
      /* sound is a nicety — never let it break the game */
    }
  }
}
