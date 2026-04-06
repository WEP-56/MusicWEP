import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/media/media_models.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../../shared/ui/section_card.dart';
import '../../domain/media_route_state.dart';
import '../../media_providers.dart';

class ArtistDetailPage extends ConsumerWidget {
  const ArtistDetailPage({super.key, required this.state});

  final ArtistRouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(artistDetailProvider(state));

    return AppShell(
      title: 'Artist Detail',
      subtitle: 'Artist profile and works.',
      child: detail.when(
        data: (data) {
          return ListView(
            children: <Widget>[
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      data.artistItem.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (data.artistItem.description?.isNotEmpty ==
                        true) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(data.artistItem.description!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _WorksSection(
                title: 'Tracks',
                items: data.musicWorks.items,
                onTap: (item) => context.push(
                  '/music',
                  extra: MusicRouteState(
                    pluginId: state.pluginId,
                    musicItem: item as MusicItem,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _WorksSection(
                title: 'Albums',
                items: data.albumWorks.items,
                onTap: (item) => context.push(
                  '/album',
                  extra: AlbumRouteState(
                    pluginId: state.pluginId,
                    albumItem: item as AlbumItem,
                  ),
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

class _WorksSection extends StatelessWidget {
  const _WorksSection({
    required this.title,
    required this.items,
    required this.onTap,
  });

  final String title;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('No items returned.')
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.displayTitle),
                subtitle: Text(item.displaySubtitle),
                onTap: () => onTap(item),
              ),
            ),
        ],
      ),
    );
  }
}
