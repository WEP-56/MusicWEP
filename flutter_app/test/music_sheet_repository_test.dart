import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:flutter_app/core/media/media_constants.dart';
import 'package:flutter_app/core/media/media_models.dart';
import 'package:flutter_app/core/storage/json_file_store.dart';
import 'package:flutter_app/features/media/application/local_music_sheet_repository.dart';
import 'package:flutter_app/features/media/application/starred_music_sheet_repository.dart';

void main() {
  test('local music sheet repository creates default favorite sheet', () async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'musicfree_sheet_repo_',
    );
    try {
      final repository = LocalMusicSheetRepository(
        JsonFileStore(path.join(tempRoot.path, 'sheets.json')),
      );

      final sheets = await repository.loadAll();

      expect(sheets, hasLength(1));
      expect(sheets.single.id, defaultLocalMusicSheetId);
      expect(sheets.single.platform, localPluginName);
    } finally {
      await tempRoot.delete(recursive: true);
    }
  });

  test('local music sheet repository can create and rename sheet', () async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'musicfree_sheet_repo_rename_',
    );
    try {
      final repository = LocalMusicSheetRepository(
        JsonFileStore(path.join(tempRoot.path, 'sheets.json')),
      );

      final created = await repository.createSheet('测试歌单');
      final customSheet = created.last;
      final renamed = await repository.renameSheet(customSheet.id, '重命名歌单');

      expect(renamed.last.title, '重命名歌单');
    } finally {
      await tempRoot.delete(recursive: true);
    }
  });

  test('starred music sheet repository toggles sheet identity', () async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'musicfree_starred_repo_',
    );
    try {
      final repository = StarredMusicSheetRepository(
        JsonFileStore(path.join(tempRoot.path, 'starred.json')),
      );
      const sheet = MusicSheetItem(
        platform: 'plugin-a',
        id: 'sheet-1',
        title: '远程歌单',
      );

      final starred = await repository.toggle(sheet);
      final unstarred = await repository.toggle(sheet);

      expect(starred, hasLength(1));
      expect(unstarred, isEmpty);
    } finally {
      await tempRoot.delete(recursive: true);
    }
  });
}
