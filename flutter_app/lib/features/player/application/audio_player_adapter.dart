abstract class AudioPlayerAdapter {
  Stream<bool> get completedStream;
  Stream<String> get errorStream;
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<double> get volumeStream;
  Stream<double> get rateStream;

  bool get isPlaying;
  Duration get position;
  Duration? get duration;
  double get volume;
  double get rate;

  Future<void> setSource({
    required String url,
    Map<String, String> headers = const <String, String>{},
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setRate(double rate);
  Future<void> dispose();
}
