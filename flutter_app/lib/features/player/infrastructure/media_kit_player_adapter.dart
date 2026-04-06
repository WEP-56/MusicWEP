import 'package:media_kit/media_kit.dart';

import '../application/audio_player_adapter.dart';
import 'playback_http_headers.dart';

class MediaKitPlayerAdapter implements AudioPlayerAdapter {
  MediaKitPlayerAdapter() : _player = Player();

  final Player _player;

  @override
  Stream<bool> get completedStream => _player.stream.completed;

  @override
  Stream<String> get errorStream => _player.stream.error;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration?> get durationStream => _player.stream.duration.map(
    (duration) => duration == Duration.zero ? null : duration,
  );

  @override
  Stream<double> get volumeStream =>
      _player.stream.volume.map((value) => (value / 100).clamp(0, 1));

  @override
  Stream<double> get rateStream => _player.stream.rate;

  @override
  bool get isPlaying => _player.state.playing;

  @override
  Duration get position => _player.state.position;

  @override
  Duration? get duration {
    final current = _player.state.duration;
    return current == Duration.zero ? null : current;
  }

  @override
  double get volume => (_player.state.volume / 100).clamp(0, 1);

  @override
  double get rate => _player.state.rate;

  @override
  Future<void> setSource({
    required String url,
    Map<String, String> headers = const <String, String>{},
  }) {
    final normalizedHeaders = normalizePlaybackHttpHeaders(url, headers);
    return _player.open(
      Media(
        url,
        httpHeaders: normalizedHeaders.isEmpty ? null : normalizedHeaders,
      ),
      play: false,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) {
    return _player.setVolume(volume.clamp(0, 1) * 100);
  }

  @override
  Future<void> setRate(double rate) => _player.setRate(rate.clamp(0.25, 2));

  @override
  Future<void> dispose() => _player.dispose();
}
