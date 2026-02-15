/// Utilities for using Google Drive image links (e.g. from form "Upload a professional Photo") in the app.
///
/// Form responses store links like:
/// - https://drive.google.com/open?id=FILE_ID
/// - https://drive.google.com/file/d/FILE_ID/view?usp=sharing
///
/// For display in [Image.network], use the direct image URL:
/// https://drive.google.com/uc?export=view&id=FILE_ID
/// (File must be shared "Anyone with the link can view".)

/// Extracts the Google Drive file ID from common link formats.
///
/// Supported formats:
/// - `https://drive.google.com/open?id=FILE_ID`
/// - `https://drive.google.com/file/d/FILE_ID/view?...`
/// - `https://drive.google.com/uc?id=FILE_ID`
/// Returns null if the string is not a recognized Drive link or ID is missing.
String? extractDriveFileId(String driveLinkOrUrl) {
  if (driveLinkOrUrl.isEmpty) return null;
  final trimmed = driveLinkOrUrl.trim();

  // open?id=FILE_ID
  final openMatch = RegExp(r'drive\.google\.com/open\?id=([a-zA-Z0-9_-]+)').firstMatch(trimmed);
  if (openMatch != null) return openMatch.group(1);

  // file/d/FILE_ID/...
  final fileMatch = RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)').firstMatch(trimmed);
  if (fileMatch != null) return fileMatch.group(1);

  // uc?id=FILE_ID (already direct)
  final ucMatch = RegExp(r'drive\.google\.com/uc\?[^&]*id=([a-zA-Z0-9_-]+)').firstMatch(trimmed);
  if (ucMatch != null) return ucMatch.group(1);

  // If it looks like a raw file ID (no URL)
  if (RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(trimmed)) return trimmed;

  return null;
}

/// Returns a direct image URL for use in [Image.network] or web img src.
///
/// Input: any of the Drive link formats from the form (e.g. "Upload a professional Photo here").
/// Output: https://drive.google.com/uc?export=view&id=FILE_ID
/// Returns null if [driveLinkOrUrl] is not a valid Drive link.
String? toDirectImageUrl(String? driveLinkOrUrl) {
  if (driveLinkOrUrl == null) return null;
  final id = extractDriveFileId(driveLinkOrUrl);
  if (id == null) return null;
  return 'https://drive.google.com/uc?export=view&id=$id';
}
