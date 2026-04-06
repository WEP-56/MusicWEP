import '../../../core/media/media_models.dart';

class PluginMediaSourceResult {
  const PluginMediaSourceResult({
    required this.url,
    this.headers = const <String, String>{},
    this.userAgent,
    this.quality,
  });

  final String url;
  final Map<String, String> headers;
  final String? userAgent;
  final String? quality;
}

class PluginLyricResult {
  const PluginLyricResult({this.lyricUrl, this.rawLyric, this.translation});

  final String? lyricUrl;
  final String? rawLyric;
  final String? translation;

  bool get hasContent =>
      (rawLyric != null && rawLyric!.isNotEmpty) ||
      (translation != null && translation!.isNotEmpty);
}

class PluginAlbumInfoResult {
  const PluginAlbumInfoResult({
    required this.isEnd,
    this.albumItem,
    this.musicList = const <MusicItem>[],
  });

  final bool isEnd;
  final AlbumItem? albumItem;
  final List<MusicItem> musicList;
}

class PluginMusicSheetInfoResult {
  const PluginMusicSheetInfoResult({
    required this.isEnd,
    this.sheetItem,
    this.musicList = const <MusicItem>[],
  });

  final bool isEnd;
  final MusicSheetItem? sheetItem;
  final List<MusicItem> musicList;
}

class PluginArtistWorksResult {
  const PluginArtistWorksResult({
    required this.isEnd,
    required this.items,
    required this.type,
  });

  final bool isEnd;
  final List<MediaItem> items;
  final MediaType type;
}

class PluginTopListDetailResult {
  const PluginTopListDetailResult({
    required this.isEnd,
    required this.topListItem,
    this.musicList = const <MusicItem>[],
  });

  final bool isEnd;
  final MusicSheetItem topListItem;
  final List<MusicItem> musicList;
}

class PluginRecommendSheetTagsResult {
  const PluginRecommendSheetTagsResult({
    this.pinned = const <MusicSheetItem>[],
    this.data = const <MusicSheetGroup>[],
  });

  final List<MusicSheetItem> pinned;
  final List<MusicSheetGroup> data;
}

class PluginRecommendSheetsResult {
  const PluginRecommendSheetsResult({
    required this.isEnd,
    this.data = const <MusicSheetItem>[],
  });

  final bool isEnd;
  final List<MusicSheetItem> data;
}

class PluginMusicCommentsResult {
  const PluginMusicCommentsResult({
    required this.isEnd,
    this.data = const <CommentItem>[],
  });

  final bool isEnd;
  final List<CommentItem> data;
}
