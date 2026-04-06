import '../../../core/media/media_constants.dart';
import 'plugin.dart';

PluginRecord buildLocalPluginRecord() {
  return PluginRecord(
    filePath: '[internal]/local-plugin',
    fileName: 'local-plugin',
    hash: localPluginHash,
    manifest: const PluginManifest(
      platform: localPluginName,
      supportedMethods: <String>[
        'getMediaSource',
        'getLyric',
        'importMusicItem',
        'importMusicSheet',
      ],
    ),
    meta: PluginMetaRecord(enabled: true, order: -1),
  );
}
