import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/media_constants.dart';
import '../../../../core/media/media_models.dart';
import '../../domain/download_models.dart';
import '../../download_providers.dart';
import 'download_track_actions.dart';

class DownloadTrackButton extends ConsumerWidget {
  const DownloadTrackButton({
    super.key,
    required this.track,
    this.size = 18,
    this.showTooltip = true,
  });

  final MusicItem track;
  final double size;
  final bool showTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(downloadTaskByTrackProvider(track));
    final isLocal = track.platform == localPluginName;
    final theme = Theme.of(context);
    final Widget icon = switch (task?.status) {
      DownloadTaskStatus.completed => Icon(
        Icons.download_done_rounded,
        size: size,
        color: const Color(0xFF0A95C8),
      ),
      DownloadTaskStatus.downloading => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: task?.progress,
          color: const Color(0xFF0A95C8),
        ),
      ),
      DownloadTaskStatus.waiting => Icon(
        Icons.schedule_rounded,
        size: size,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      DownloadTaskStatus.failed => Icon(
        Icons.download_rounded,
        size: size,
        color: theme.colorScheme.error,
      ),
      null => Icon(
        isLocal ? Icons.download_done_rounded : Icons.download_rounded,
        size: size,
        color: isLocal
            ? const Color(0xFF0A95C8)
            : theme.colorScheme.onSurfaceVariant,
      ),
    };

    final tooltip = switch (task?.status) {
      DownloadTaskStatus.completed => '已下载',
      DownloadTaskStatus.downloading => '下载中',
      DownloadTaskStatus.waiting => '等待下载',
      DownloadTaskStatus.failed => '重新下载',
      null when isLocal => '本地歌曲',
      _ => '下载',
    };

    final child = InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isLocal || task?.status == DownloadTaskStatus.completed
          ? null
          : () async {
              await queueTrackDownload(context, ref, track);
            },
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: icon),
      ),
    );
    return showTooltip ? Tooltip(message: tooltip, child: child) : child;
  }
}
