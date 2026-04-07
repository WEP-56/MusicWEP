import '../../../core/media/media_models.dart';
import 'player_models.dart';

class PlayerSession {
  const PlayerSession({
    required this.queue,
    required this.position,
    required this.repeatMode,
    required this.volume,
    required this.rate,
    required this.currentQuality,
    required this.qualityOverrides,
    this.currentTrack,
    this.currentIndex,
  });

  final List<MusicItem> queue;
  final MusicItem? currentTrack;
  final int? currentIndex;
  final Duration position;
  final RepeatMode repeatMode;
  final double volume;
  final double rate;
  final String currentQuality;
  final Map<String, String> qualityOverrides;

  factory PlayerSession.fromJson(Map<String, dynamic> json) {
    return PlayerSession(
      queue: (json['queue'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => MusicItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false),
      currentTrack: switch (json['currentTrack']) {
        final Map<String, dynamic> value => MusicItem.fromJson(value),
        final Map value => MusicItem.fromJson(
          value.map((key, value) => MapEntry(key.toString(), value)),
        ),
        _ => null,
      },
      currentIndex: switch (json['currentIndex']) {
        final int value => value,
        final num value => value.toInt(),
        final String value => int.tryParse(value),
        _ => null,
      },
      position: Duration(
        milliseconds: switch (json['positionMs']) {
          final int value => value,
          final num value => value.toInt(),
          final String value => int.tryParse(value) ?? 0,
          _ => 0,
        },
      ),
      repeatMode: switch (json['repeatMode']?.toString()) {
        'singleLoop' => RepeatMode.singleLoop,
        'shuffle' => RepeatMode.shuffle,
        _ => RepeatMode.listLoop,
      },
      volume: switch (json['volume']) {
        final num value => value.toDouble(),
        final String value => double.tryParse(value) ?? 1,
        _ => 1,
      },
      rate: switch (json['rate']) {
        final num value => value.toDouble(),
        final String value => double.tryParse(value) ?? 1,
        _ => 1,
      },
      currentQuality: json['currentQuality']?.toString() ?? 'standard',
      qualityOverrides: switch (json['qualityOverrides']) {
        final Map<String, dynamic> value => value.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
        final Map value => value.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
        _ => const <String, String>{},
      },
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'queue': queue.map((item) => item.toJson()).toList(growable: false),
      if (currentTrack != null) 'currentTrack': currentTrack!.toJson(),
      if (currentIndex != null) 'currentIndex': currentIndex,
      'positionMs': position.inMilliseconds,
      'repeatMode': repeatMode.name,
      'volume': volume,
      'rate': rate,
      'currentQuality': currentQuality,
      if (qualityOverrides.isNotEmpty) 'qualityOverrides': qualityOverrides,
    };
  }
}
