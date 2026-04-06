import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_app/core/storage/json_file_store.dart';
import 'package:flutter_app/features/plugins/application/local_music_repository.dart';

void main() {
  test(
    'local music repository imports folder and filters unsupported files',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'musicfree_local_music_',
      );
      try {
        await File(path.join(tempRoot.path, 'track-a.mp3')).writeAsString('a');
        await File(path.join(tempRoot.path, 'track-b.flac')).writeAsString('b');
        await File(path.join(tempRoot.path, 'ignore.txt')).writeAsString('c');

        final repository = LocalMusicRepository(
          JsonFileStore(path.join(tempRoot.path, 'local_music.json')),
        );

        final tracks = await repository.importFolder(tempRoot.path);

        expect(tracks, hasLength(2));
        expect(
          tracks.map((track) => path.basename(track.localPath ?? '')).toSet(),
          <String>{'track-a.mp3', 'track-b.flac'},
        );
      } finally {
        await tempRoot.delete(recursive: true);
      }
    },
  );

  test(
    'local music repository keeps unique items when importing again',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'musicfree_local_music_unique_',
      );
      try {
        final musicPath = path.join(tempRoot.path, 'track-a.mp3');
        await File(musicPath).writeAsString('a');

        final repository = LocalMusicRepository(
          JsonFileStore(path.join(tempRoot.path, 'local_music.json')),
        );

        await repository.importFiles(<String>[musicPath]);
        final tracks = await repository.importFiles(<String>[musicPath]);

        expect(tracks, hasLength(1));
        expect(tracks.single.localPath, musicPath);
      } finally {
        await tempRoot.delete(recursive: true);
      }
    },
  );
}
