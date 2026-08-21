const String _filePathPrefix =
    'https://commons.wikimedia.org/wiki/Special:FilePath/';
const String _uploadPrefix = 'https://upload.wikimedia.org/wikipedia/commons/';
const String _filePagePrefix = 'https://commons.wikimedia.org/wiki/File:';

/// Builds the direct-download URL for a Commons file, capped to a
/// reasonable width for a court photo. `fileTitle` is the file name
/// without the `File:` prefix (e.g. `Basketball court.jpg`).
String commonsFilePathUrl(String fileTitle, {int width = 800}) =>
    '$_filePathPrefix${Uri.encodeComponent(fileTitle)}?width=$width';

/// Recovers the Commons file title from a URL built by
/// [commonsFilePathUrl], or from a raw `upload.wikimedia.org` URL. Returns
/// null for anything else — this app only ever stores Commons-sourced
/// image URLs on a Court (see the mappers), so a null here means the data
/// didn't come from where expected and attribution can't be resolved,
/// which is exactly when the photo must not be shown.
String? commonsFileTitleFromUrl(String url) {
  if (url.startsWith(_filePathPrefix)) {
    final withoutQuery = url.split('?').first;
    final encoded = withoutQuery.substring(_filePathPrefix.length);
    return Uri.decodeComponent(encoded);
  }
  if (url.startsWith(_uploadPrefix)) {
    final segment = url.split('/').last.split('?').first;
    return Uri.decodeComponent(segment);
  }
  if (url.startsWith(_filePagePrefix)) {
    final withoutQuery = url.split('?').first;
    final encoded = withoutQuery.substring(_filePagePrefix.length);
    return Uri.decodeComponent(encoded);
  }
  return null;
}
