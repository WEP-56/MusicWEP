import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/media_models.dart';
import '../../application/local_music_sheet_repository.dart';
import '../../music_sheet_library_providers.dart';

Future<void> toggleFavoriteTrack(
  BuildContext context,
  WidgetRef ref,
  MusicItem track,
) async {
  final nextFavorite = await ref
      .read(localMusicSheetControllerProvider.notifier)
      .toggleFavoriteMusic(track);
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(nextFavorite ? '已添加到“我喜欢”' : '已从“我喜欢”移除'),
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<void> showAddToMusicSheetDialog(
  BuildContext context,
  WidgetRef ref, {
  required List<MusicItem> tracks,
}) async {
  if (tracks.isEmpty) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, ref, _) {
          final sheetsAsync = ref.watch(localMusicSheetControllerProvider);
          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '添加到歌单${tracks.length > 1 ? '（共 ${tracks.length} 首）' : ''}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: sheetsAsync.when(
                data: (sheets) {
                  return ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      _MusicSheetOptionTile(
                        icon: Icons.add_rounded,
                        title: '新建歌单',
                        onTap: () async {
                          final title = await _showNewSheetDialog(
                            dialogContext,
                          );
                          if (title == null || title.isEmpty) {
                            return;
                          }
                          await ref
                              .read(localMusicSheetControllerProvider.notifier)
                              .createSheet(
                                title,
                                musicList: tracks,
                                artwork: tracks.first.artwork,
                              );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已添加到新歌单“$title”'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      for (final sheet in sheets)
                        _MusicSheetOptionTile(
                          icon: sheet.id == defaultLocalMusicSheetId
                              ? Icons.favorite_border_rounded
                              : Icons.queue_music_rounded,
                          title: sheet.id == defaultLocalMusicSheetId
                              ? '我喜欢'
                              : sheet.title,
                          artwork: sheet.artwork,
                          onTap: () async {
                            await ref
                                .read(
                                  localMusicSheetControllerProvider.notifier,
                                )
                                .addMusicToSheet(sheet.id, tracks);
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '已添加到“${sheet.id == defaultLocalMusicSheetId ? '我喜欢' : sheet.title}”',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
                error: (error, _) => Center(child: Text(error.toString())),
                loading: () => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> showTrackContextMenu(
  BuildContext context, {
  required Offset position,
  required MusicItem track,
  required Future<void> Function() onAddToSheet,
  Future<void> Function()? onDownload,
  Future<void> Function()? onRemoveFromCurrentSheet,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 1, 1),
      Offset.zero & overlay.size,
    ),
    items: <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        enabled: false,
        value: 'id',
        child: Text('ID: ${track.id}'),
      ),
      PopupMenuItem<String>(
        enabled: false,
        value: 'artist',
        child: Text('作者: ${track.artist}'),
      ),
      if (track.album?.trim().isNotEmpty == true)
        PopupMenuItem<String>(
          enabled: false,
          value: 'album',
          child: Text('专辑: ${track.album}'),
        ),
      const PopupMenuDivider(),
      if (onDownload != null)
        const PopupMenuItem<String>(value: 'download', child: Text('下载')),
      const PopupMenuItem<String>(value: 'add_to_sheet', child: Text('添加到歌单')),
      if (onRemoveFromCurrentSheet != null)
        const PopupMenuItem<String>(
          value: 'remove_from_sheet',
          child: Text('从歌单内删除'),
        ),
    ],
  );

  if (selected == 'download' && onDownload != null) {
    await onDownload();
  } else if (selected == 'add_to_sheet') {
    await onAddToSheet();
  } else if (selected == 'remove_from_sheet' &&
      onRemoveFromCurrentSheet != null) {
    await onRemoveFromCurrentSheet();
  }
}

Future<String?> _showNewSheetDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: '请输入歌单名称'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      );
    },
  );
}

class _MusicSheetOptionTile extends StatelessWidget {
  const _MusicSheetOptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.artwork,
  });

  final IconData icon;
  final String title;
  final String? artwork;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: artwork != null && artwork!.isNotEmpty
                  ? Image.network(
                      artwork!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _SheetFallbackIcon(icon: icon),
                    )
                  : _SheetFallbackIcon(icon: icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, color: Color(0xFF202020)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetFallbackIcon extends StatelessWidget {
  const _SheetFallbackIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: const Color(0xFF666666)),
    );
  }
}
