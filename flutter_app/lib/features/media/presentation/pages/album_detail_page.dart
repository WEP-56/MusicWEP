import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/ui/app_shell.dart';
import '../../../../shared/ui/section_card.dart';
import '../../domain/media_route_state.dart';
import '../../media_providers.dart';

class AlbumDetailPage extends ConsumerWidget {
  const AlbumDetailPage({super.key, required this.state});

  final AlbumRouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(albumDetailProvider(state));

    return AppShell(
      title: 'Album Detail',
      subtitle: 'Album metadata and track list.',
      child: detail.when(
        data: (data) {
          final album = data?.albumItem ?? state.albumItem;
          final tracks = data?.musicList ?? album.musicList;
          return ListView(
            children: <Widget>[
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      album.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (album.artist?.isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(album.artist!),
                    ],
                    if (album.description?.isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(album.description!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Tracks',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (tracks.isEmpty)
                      const Text('No tracks returned.')
                    else
                      ...tracks.map(
                        (track) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(track.title),
                          subtitle: Text(track.displaySubtitle),
                          onTap: () => context.push(
                            '/music',
                            extra: MusicRouteState(
                              pluginId: state.pluginId,
                              musicItem: track,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        error: (error, _) => SectionCard(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
