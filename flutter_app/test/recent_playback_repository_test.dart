import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_app/core/media/media_models.dart';
import 'package:flutter_app/core/storage/json_file_store.dart';
import 'package:flutter_app/features/player/application/recent_playback_repository.dart';

void main() {
  test('recent playback repository keeps newest unique track first', () async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'musicfree_recent_playback_',
    );
    try {
      final repository = RecentPlaybackRepository(
        JsonFileStore(path.join(tempRoot.path, 'recent.json')),
      );

      await repository.record(
        pluginId: 'plugin-a',
        musicItem: const MusicItem(
          platform: 'remote',
          id: '1',
          title: 'Track 1',
          artist: 'Artist',
        ),
      );
      await repository.record(
        pluginId: 'plugin-a',
        musicItem: const MusicItem(
          platform: 'remote',
          id: '2',
          title: 'Track 2',
          artist: 'Artist',
        ),
      );
      final records = await repository.record(
        pluginId: 'plugin-a',
        musicItem: const MusicItem(
          platform: 'remote',
          id: '1',
          title: 'Track 1',
          artist: 'Artist',
        ),
      );

      expect(records, hasLength(2));
      expect(records.first.musicItem.id, '1');
      expect(records.last.musicItem.id, '2');
    } finally {
      await tempRoot.delete(recursive: true);
    }
  });
}
