import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_app/core/media/media_models.dart';
import 'package:flutter_app/core/storage/json_file_store.dart';
import 'package:flutter_app/features/player/application/player_session_repository.dart';
import 'package:flutter_app/features/player/domain/player_models.dart';
import 'package:flutter_app/features/player/domain/player_session.dart';

void main() {
  test(
    'player session repository saves and restores playback session',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'musicwep_player_session_',
      );
      try {
        final repository = PlayerSessionRepository(
          JsonFileStore(path.join(tempRoot.path, 'player_session.json')),
        );

        const track1 = MusicItem(
          platform: 'plugin-a',
          id: '1',
          title: 'Track 1',
          artist: 'Artist 1',
        );
        const track2 = MusicItem(
          platform: 'plugin-a',
          id: '2',
          title: 'Track 2',
          artist: 'Artist 2',
        );

        const session = PlayerSession(
          queue: <MusicItem>[track1, track2],
          currentTrack: track2,
          currentIndex: 1,
          position: Duration(minutes: 1, seconds: 12),
          repeatMode: RepeatMode.shuffle,
          volume: 0.8,
          rate: 1.25,
          currentQuality: 'high',
          qualityOverrides: <String, String>{'plugin-a@2': 'high'},
        );

        await repository.save(session);
        final restored = await repository.load();

        expect(restored, isNotNull);
        expect(restored!.queue, hasLength(2));
        expect(restored.currentTrack?.id, '2');
        expect(restored.currentIndex, 1);
        expect(restored.position, const Duration(minutes: 1, seconds: 12));
        expect(restored.repeatMode, RepeatMode.shuffle);
        expect(restored.volume, 0.8);
        expect(restored.rate, 1.25);
        expect(restored.currentQuality, 'high');
        expect(restored.qualityOverrides['plugin-a@2'], 'high');
      } finally {
        await tempRoot.delete(recursive: true);
      }
    },
  );
}
