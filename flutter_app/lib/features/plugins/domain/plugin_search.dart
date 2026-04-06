import '../../../core/media/media_models.dart';
import 'plugin.dart';

enum PluginSearchType {
  music('music', 'Tracks', MediaType.music),
  album('album', 'Albums', MediaType.album),
  artist('artist', 'Artists', MediaType.artist),
  sheet('sheet', 'Playlists', MediaType.sheet);

  const PluginSearchType(this.value, this.label, this.mediaType);

  final String value;
  final String label;
  final MediaType mediaType;
}

class PluginSearchResultItem {
  const PluginSearchResultItem({required this.media});

  final MediaItem media;

  String get title => media.displayTitle;
  String get subtitle => media.displaySubtitle;

  Map<String, dynamic> toJson() => media.toJson();
}

class PluginSearchResult {
  const PluginSearchResult({
    required this.plugin,
    required this.items,
    required this.logs,
    required this.requiredPackages,
    required this.missingPackages,
    this.isEnd = true,
    this.errorMessage,
  });

  final PluginRecord plugin;
  final List<PluginSearchResultItem> items;
  final List<String> logs;
  final List<String> requiredPackages;
  final List<String> missingPackages;
  final bool isEnd;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

class PluginSearchSession {
  const PluginSearchSession({
    required this.query,
    required this.page,
    required this.type,
    required this.results,
  });

  final String query;
  final int page;
  final PluginSearchType type;
  final List<PluginSearchResult> results;

  factory PluginSearchSession.empty() {
    return const PluginSearchSession(
      query: '',
      page: 1,
      type: PluginSearchType.music,
      results: <PluginSearchResult>[],
    );
  }
}
