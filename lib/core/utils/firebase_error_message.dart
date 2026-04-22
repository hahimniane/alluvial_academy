import 'package:firebase_core/firebase_core.dart';

String _formatFirebaseException(FirebaseException e) {
  final m = e.message;
  if (m != null && m.trim().isNotEmpty) return m.trim();
  if (e.code.isNotEmpty) return e.code;
  return 'Firebase error';
}

/// Walks a few levels of `error` / `exception` chains (Flutter web often wraps
/// [FirebaseException] in a JS interop object; use the `.error` property).
List<Object> _unwrapChain(Object error) {
  final out = <Object>[error];
  Object? current = error;
  for (var i = 0; i < 6; i++) {
    try {
      final d = current as dynamic;
      final next = d.error ?? d.exception;
      if (next == null) break;
      if (identical(next, current)) break;
      current = next as Object;
      out.add(current);
    } catch (_) {
      break;
    }
  }
  return out;
}

String? _messageFromErrorText(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('permission-denied') ||
      lower.contains('permission_denied') ||
      lower.contains('insufficient permissions') ||
      lower.contains('missing or insufficient permissions')) {
    return 'Permission denied. Ask an admin to check Firestore security rules, or sign out and sign in again.';
  }
  if (lower.contains('unauthenticated') || lower.contains('auth/')) {
    return 'Authentication issue. Sign out and sign in again.';
  }
  if (lower.contains('not-found') || lower.contains('not found')) {
    return 'The item no longer exists or was removed.';
  }
  if (lower.contains('failed-precondition') ||
      lower.contains('failed precondition')) {
    return 'This action is not allowed in the current state.';
  }
  if (lower.contains('unavailable') && lower.contains('network')) {
    return 'Network error. Check your connection and try again.';
  }
  return null;
}

/// Returns a short, user-visible message for errors from Firebase / Firestore.
/// On web, the thrown value is often a wrapper; we unwrap `.error` and parse text.
String messageFromFirebaseError(Object error) {
  for (final o in _unwrapChain(error)) {
    if (o is FirebaseException) {
      return _formatFirebaseException(o);
    }
  }
  for (final o in _unwrapChain(error)) {
    final fromText = _messageFromErrorText(o.toString());
    if (fromText != null) return fromText;
  }
  final combined =
      _unwrapChain(error).map((o) => o.toString()).join('\n');
  final fromCombined = _messageFromErrorText(combined);
  if (fromCombined != null) return fromCombined;

  final s = error.toString();
  final fromS = _messageFromErrorText(s);
  if (fromS != null) return fromS;

  if (s.contains('Dart exception thrown from converted Future')) {
    return 'Could not complete this action (often a Firestore permission or network issue on web). '
        'Try refreshing the page, signing out and back in, or ask an admin to verify teacher rules for the job board.';
  }
  return s.length > 400 ? '${s.substring(0, 397)}...' : s;
}
