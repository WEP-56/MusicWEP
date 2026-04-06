import '../../../core/media/media_models.dart';

class MusicRouteState {
  const MusicRouteState({required this.pluginId, required this.musicItem});

  final String pluginId;
  final MusicItem musicItem;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicRouteState &&
          runtimeType == other.runtimeType &&
          pluginId == other.pluginId &&
          musicItem.platform == other.musicItem.platform &&
          musicItem.id == other.musicItem.id;

  @override
  int get hashCode => Object.hash(pluginId, musicItem.platform, musicItem.id);
}

class AlbumRouteState {
  const AlbumRouteState({required this.pluginId, required this.albumItem});

  final String pluginId;
  final AlbumItem albumItem;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlbumRouteState &&
          runtimeType == other.runtimeType &&
          pluginId == other.pluginId &&
          albumItem.platform == other.albumItem.platform &&
          albumItem.id == other.albumItem.id;

  @override
  int get hashCode => Object.hash(pluginId, albumItem.platform, albumItem.id);
}

class SheetRouteState {
  const SheetRouteState({required this.pluginId, required this.sheetItem});

  final String pluginId;
  final MusicSheetItem sheetItem;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SheetRouteState &&
          runtimeType == other.runtimeType &&
          pluginId == other.pluginId &&
          sheetItem.platform == other.sheetItem.platform &&
          sheetItem.id == other.sheetItem.id;

  @override
  int get hashCode => Object.hash(pluginId, sheetItem.platform, sheetItem.id);
}

class ArtistRouteState {
  const ArtistRouteState({required this.pluginId, required this.artistItem});

  final String pluginId;
  final ArtistItem artistItem;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtistRouteState &&
          runtimeType == other.runtimeType &&
          pluginId == other.pluginId &&
          artistItem.platform == other.artistItem.platform &&
          artistItem.id == other.artistItem.id;

  @override
  int get hashCode => Object.hash(pluginId, artistItem.platform, artistItem.id);
}

class TopListRouteState {
  const TopListRouteState({required this.pluginId, required this.topListItem});

  final String pluginId;
  final MusicSheetItem topListItem;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopListRouteState &&
          runtimeType == other.runtimeType &&
          pluginId == other.pluginId &&
          topListItem.platform == other.topListItem.platform &&
          topListItem.id == other.topListItem.id;

  @override
  int get hashCode =>
      Object.hash(pluginId, topListItem.platform, topListItem.id);
}

class RecommendSheetsRouteState {
  const RecommendSheetsRouteState({required this.pluginId, required this.tag});

  final String pluginId;
  final MediaTag tag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendSheetsRouteState &&
          runtimeType == other.runtimeType &&
          pluginId == other.pluginId &&
          tag.id == other.tag.id;

  @override
  int get hashCode => Object.hash(pluginId, tag.id);
}
