const defaultPlaybackUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';

Map<String, String> normalizePlaybackHttpHeaders(
  String url,
  Map<String, String> headers,
) {
  if (headers.isEmpty && !_shouldAttachDefaultUserAgent(url)) {
    return headers;
  }

  final normalized = <String, String>{};
  var hasUserAgent = false;
  headers.forEach((key, value) {
    if (value.isEmpty) {
      return;
    }
    if (key.toLowerCase() == 'user-agent') {
      hasUserAgent = true;
    }
    normalized[key] = value;
  });

  if (!hasUserAgent && _shouldAttachDefaultUserAgent(url)) {
    normalized['User-Agent'] = defaultPlaybackUserAgent;
  }
  return normalized;
}

bool _shouldAttachDefaultUserAgent(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      (uri.scheme.toLowerCase() == 'http' ||
          uri.scheme.toLowerCase() == 'https');
}
