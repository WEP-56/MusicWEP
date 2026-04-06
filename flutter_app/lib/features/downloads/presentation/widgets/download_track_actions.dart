import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/media_models.dart';
import '../../../plugins/plugin_providers.dart';
import '../../application/download_debug_logger.dart';
import '../../domain/download_models.dart';
import '../../download_providers.dart';

Future<DownloadEnqueueResult> queueTrackDownload(
  BuildContext context,
  WidgetRef ref,
  MusicItem track,
) async {
  final appPaths = await ref.read(appPathsProvider.future);
  unawaited(
    appendDownloadDebugLog(
      pathForDownloadDebugLog(appPaths.logsDirectory.path),
      'ui',
      'tap download track=${track.platform}@${track.id} title=${track.title}',
    ),
  );
  final result = await ref
      .read(downloadControllerProvider.notifier)
      .enqueueTrack(track);
  if (!context.mounted) {
    return result;
  }

  final message = switch (result) {
    DownloadEnqueueResult.queued => '已加入下载队列',
    DownloadEnqueueResult.alreadyQueued => '这首歌已在下载队列中',
    DownloadEnqueueResult.alreadyDownloaded => '这首歌已经下载完成',
    DownloadEnqueueResult.localTrack => '本地歌曲无需下载',
    DownloadEnqueueResult.missingPlugin => '未找到对应插件，无法下载',
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
  return result;
}
