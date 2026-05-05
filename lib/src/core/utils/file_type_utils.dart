String? extensionFromContentType(String? contentType) {
  if (contentType == null || contentType.trim().isEmpty) {
    return null;
  }
  final normalized = contentType.split(';').first.trim().toLowerCase();
  return _mimeTypeToExtension[normalized];
}

String? mimeTypeForPath(String path) {
  final extension = extensionFromPath(path);
  if (extension == null) {
    return null;
  }
  return _extensionToMimeType[extension];
}

String? utiForPath(String path) {
  final extension = extensionFromPath(path);
  if (extension == null) {
    return null;
  }
  return _extensionToUti[extension];
}

/// Returns the lowercase file extension from [path], ignoring overly long
/// suffixes by limiting results to [maxLength] characters.
String? extensionFromPath(String path, {int maxLength = 8}) {
  final sanitized = path.trim();
  if (sanitized.isEmpty) {
    return null;
  }
  final dot = sanitized.lastIndexOf('.');
  if (dot == -1 || dot == sanitized.length - 1) {
    return null;
  }
  final extension = sanitized.substring(dot + 1).toLowerCase();
  if (extension.isEmpty || extension.length > maxLength) {
    return null;
  }
  return extension;
}

const Map<String, String> _extensionToMimeType = <String, String>{
  'mp4': 'video/mp4',
  'm4v': 'video/x-m4v',
  'mov': 'video/quicktime',
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'pdf': 'application/pdf',
};

const Map<String, String> _mimeTypeToExtension = <String, String>{
  'video/mp4': 'mp4',
  'video/x-m4v': 'm4v',
  'video/quicktime': 'mov',
  'audio/mpeg': 'mp3',
  'audio/mp4': 'm4a',
  'audio/x-m4a': 'm4a',
  'audio/aac': 'aac',
  'application/pdf': 'pdf',
};

const Map<String, String> _extensionToUti = <String, String>{
  'mp4': 'public.mpeg-4',
  'm4v': 'public.mpeg-4',
  'mov': 'com.apple.quicktime-movie',
  'mp3': 'public.mp3',
  'm4a': 'public.mpeg-4-audio',
  'aac': 'public.aac-audio',
  'pdf': 'com.adobe.pdf',
};
