import '../../../core/media/media_models.dart';

class RecentPlaybackEntry {
  const RecentPlaybackEntry({
    required this.pluginId,
    required this.musicItem,
    required this.playedAt,
  });

  final String pluginId;
  final MusicItem musicItem;
  final DateTime playedAt;

  factory RecentPlaybackEntry.fromJson(Map<String, dynamic> json) {
    return RecentPlaybackEntry(
      pluginId: json['pluginId']?.toString() ?? '',
      musicItem: MusicItem.fromJson(
        (json['musicItem'] as Map? ?? const <String, dynamic>{}).map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      ),
      playedAt:
          DateTime.tryParse(json['playedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pluginId': pluginId,
      'musicItem': musicItem.toJson(),
      'playedAt': playedAt.toIso8601String(),
    };
  }
}
