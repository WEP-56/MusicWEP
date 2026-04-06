import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_models.dart';
import '../plugins/domain/internal_plugins.dart';
import '../plugins/domain/plugin.dart';
import '../plugins/domain/plugin_method_models.dart';
import '../plugins/domain/plugin_search.dart';
import '../plugins/plugin_providers.dart';
import 'domain/media_route_state.dart';

final pluginByIdProvider = Provider.family<PluginRecord?, String>((
  ref,
  pluginId,
) {
  final snapshot = ref.watch(pluginControllerProvider);
  return snapshot.maybeWhen(
    data: (data) {
      for (final plugin in data.plugins) {
        if (plugin.storageKey == pluginId) {
          return plugin;
        }
      }
      final localPlugin = buildLocalPluginRecord();
      if (localPlugin.storageKey == pluginId || localPlugin.hash == pluginId) {
        return localPlugin;
      }
      return null;
    },
    orElse: () => null,
  );
});

class MusicDetailData {
  const MusicDetailData({
    required this.plugin,
    required this.musicItem,
    this.mediaSource,
    this.lyric,
    this.comments = const PluginMusicCommentsResult(isEnd: true),
  });

  final PluginRecord plugin;
  final MusicItem musicItem;
  final PluginMediaSourceResult? mediaSource;
  final PluginLyricResult? lyric;
  final PluginMusicCommentsResult comments;
}

class ArtistDetailData {
  const ArtistDetailData({
    required this.plugin,
    required this.artistItem,
    required this.musicWorks,
    required this.albumWorks,
  });

  final PluginRecord plugin;
  final ArtistItem artistItem;
  final PluginArtistWorksResult musicWorks;
  final PluginArtistWorksResult albumWorks;
}

final musicDetailProvider =
    FutureProvider.family<MusicDetailData, MusicRouteState>((ref, state) async {
      final service = await ref.watch(pluginMethodServiceProvider.future);
      final plugin = ref.watch(pluginByIdProvider(state.pluginId));
      if (plugin == null) {
        throw StateError('Plugin not found: ${state.pluginId}');
      }
      final patch = await service.getMusicInfo(
        plugin: plugin,
        mediaItem: state.musicItem,
      );
      final mergedMusic = patch == null
          ? state.musicItem
          : state.musicItem.mergePatch(patch);
      final lyric = await service.getLyric(
        plugin: plugin,
        musicItem: mergedMusic,
      );
      final mediaSource = await service.getMediaSource(
        plugin: plugin,
        musicItem: mergedMusic,
      );
      final comments = await service.getMusicComments(
        plugin: plugin,
        musicItem: mergedMusic,
      );
      return MusicDetailData(
        plugin: plugin,
        musicItem: mergedMusic,
        mediaSource: mediaSource,
        lyric: lyric,
        comments: comments,
      );
    });

final albumDetailProvider =
    FutureProvider.family<PluginAlbumInfoResult?, AlbumRouteState>((
      ref,
      state,
    ) async {
      final service = await ref.watch(pluginMethodServiceProvider.future);
      final plugin = ref.watch(pluginByIdProvider(state.pluginId));
      if (plugin == null) {
        throw StateError('Plugin not found: ${state.pluginId}');
      }
      return service.getAlbumInfo(plugin: plugin, albumItem: state.albumItem);
    });

final sheetDetailProvider =
    FutureProvider.family<PluginMusicSheetInfoResult?, SheetRouteState>((
      ref,
      state,
    ) async {
      final service = await ref.watch(pluginMethodServiceProvider.future);
      final plugin = ref.watch(pluginByIdProvider(state.pluginId));
      if (plugin == null) {
        throw StateError('Plugin not found: ${state.pluginId}');
      }
      return service.getMusicSheetInfo(
        plugin: plugin,
        sheetItem: state.sheetItem,
      );
    });

final artistDetailProvider =
    FutureProvider.family<ArtistDetailData, ArtistRouteState>((
      ref,
      state,
    ) async {
      final service = await ref.watch(pluginMethodServiceProvider.future);
      final plugin = ref.watch(pluginByIdProvider(state.pluginId));
      if (plugin == null) {
        throw StateError('Plugin not found: ${state.pluginId}');
      }
      final musicWorks = await service.getArtistWorks(
        plugin: plugin,
        artistItem: state.artistItem,
        type: PluginSearchType.music,
      );
      final albumWorks = await service.getArtistWorks(
        plugin: plugin,
        artistItem: state.artistItem,
        type: PluginSearchType.album,
      );
      return ArtistDetailData(
        plugin: plugin,
        artistItem: state.artistItem,
        musicWorks: musicWorks,
        albumWorks: albumWorks,
      );
    });

final topListsProvider = FutureProvider.family<List<MusicSheetGroup>, String>((
  ref,
  pluginId,
) async {
  final service = await ref.watch(pluginMethodServiceProvider.future);
  final plugin = ref.watch(pluginByIdProvider(pluginId));
  if (plugin == null) {
    throw StateError('Plugin not found: $pluginId');
  }
  return service.getTopLists(plugin: plugin);
});

final topListDetailProvider =
    FutureProvider.family<PluginTopListDetailResult, TopListRouteState>((
      ref,
      state,
    ) async {
      final service = await ref.watch(pluginMethodServiceProvider.future);
      final plugin = ref.watch(pluginByIdProvider(state.pluginId));
      if (plugin == null) {
        throw StateError('Plugin not found: ${state.pluginId}');
      }
      return service.getTopListDetailSafe(
        plugin: plugin,
        topListItem: state.topListItem,
      );
    });

final recommendTagsProvider =
    FutureProvider.family<PluginRecommendSheetTagsResult, String>((
      ref,
      pluginId,
    ) async {
      final service = await ref.watch(pluginMethodServiceProvider.future);
      final plugin = ref.watch(pluginByIdProvider(pluginId));
      if (plugin == null) {
        throw StateError('Plugin not found: $pluginId');
      }
      return service.getRecommendSheetTags(plugin: plugin);
    });

final recommendSheetsProvider =
    FutureProvider.family<
      PluginRecommendSheetsResult,
      RecommendSheetsRouteState
    >((ref, state) async {
      final service = await ref.watch(pluginMethodServiceProvider.future);
      final plugin = ref.watch(pluginByIdProvider(state.pluginId));
      if (plugin == null) {
        throw StateError('Plugin not found: ${state.pluginId}');
      }
      return service.getRecommendSheetsByTag(plugin: plugin, tag: state.tag);
    });
