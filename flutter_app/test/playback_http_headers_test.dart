import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/player/infrastructure/playback_http_headers.dart';

void main() {
  group('normalizePlaybackHttpHeaders', () {
    test('adds a browser-like user agent for remote playback when missing', () {
      final headers = normalizePlaybackHttpHeaders(
        'https://example.com/audio.mp3',
        const <String, String>{'Referer': 'https://example.com/'},
      );

      expect(headers['Referer'], 'https://example.com/');
      expect(headers['User-Agent'], defaultPlaybackUserAgent);
    });

    test('keeps plugin-provided user agent intact', () {
      final headers = normalizePlaybackHttpHeaders(
        'https://example.com/audio.mp3',
        const <String, String>{'user-agent': 'PluginUA/1.0'},
      );

      expect(headers['user-agent'], 'PluginUA/1.0');
      expect(headers.containsKey('User-Agent'), isFalse);
    });

    test('does not add headers for local playback', () {
      final headers = normalizePlaybackHttpHeaders(
        'file:///D:/music.mp3',
        const <String, String>{},
      );

      expect(headers, isEmpty);
    });
  });
}
