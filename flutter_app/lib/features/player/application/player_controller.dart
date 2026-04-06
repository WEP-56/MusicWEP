import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_models.dart';
import '../../plugins/application/plugin_method_service.dart';
import '../../plugins/domain/internal_plugins.dart';
import '../../plugins/domain/plugin.dart';
import '../../plugins/plugin_providers.dart';
import '../../settings/application/app_settings_controller.dart';
import '../../settings/domain/app_settings.dart';
import '../player_dependencies.dart';
import '../domain/player_models.dart';
import '../domain/player_state.dart';
import '../recent_playback_providers.dart';
import 'audio_player_adapter.dart';

class PlayerController extends Notifier<PlayerState> {
  late final AudioPlayerAdapter _adapter;

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<double>? _volumeSubscription;
  StreamSubscription<double>? _rateSubscription;
  StreamSubscription<String>? _errorSubscription;

  @override
  PlayerState build() {
    _adapter = ref.read(audioPlayerAdapterProvider);
    _bindAdapter();
    ref.listen<AsyncValue<AppSettings>>(appSettingsControllerProvider, (
      _,
      next,
    ) {
      final settings = next.valueOrNull;
      if (settings == null) {
        return;
      }
      state = state.copyWith(
        defaultQuality: settings.playMusic.defaultQuality,
        desktopLyricVisible: settings.lyric.enableDesktopLyric,
      );
    });
    ref.onDispose(() async {
      await _playingSubscription?.cancel();
      await _completedSubscription?.cancel();
      await _positionSubscription?.cancel();
      await _durationSubscription?.cancel();
      await _volumeSubscription?.cancel();
      await _rateSubscription?.cancel();
      await _errorSubscription?.cancel();
      await _adapter.dispose();
    });
    final initialSettings = ref.read(appSettingsControllerProvider).valueOrNull;
    return PlayerState(
      isPlaying: _adapter.isPlaying,
      position: _adapter.position,
      duration: _adapter.duration,
      volume: _adapter.volume,
      defaultQuality: initialSettings?.playMusic.defaultQuality ?? 'standard',
      desktopLyricVisible: initialSettings?.lyric.enableDesktopLyric ?? false,
    );
  }

  void _bindAdapter() {
    _playingSubscription ??= _adapter.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });
    _completedSubscription ??= _adapter.completedStream.listen((completed) {
      if (completed) {
        unawaited(_handlePlaybackCompleted());
      }
    });
    _positionSubscription ??= _adapter.positionStream.listen((position) {
      final currentLyricIndex = state.lyric.resolveCurrentIndex(position);
      state = state.copyWith(
        position: position,
        currentLyricIndex: currentLyricIndex,
      );
    });
    _durationSubscription ??= _adapter.durationStream.listen((duration) {
      state = state.copyWith(duration: duration);
    });
    _volumeSubscription ??= _adapter.volumeStream.listen((volume) {
      state = state.copyWith(volume: volume);
    });
    _rateSubscription ??= _adapter.rateStream.listen((rate) {
      state = state.copyWith(rate: rate);
    });
    _errorSubscription ??= _adapter.errorStream.listen((message) {
      final normalized = message.trim();
      if (normalized.isEmpty) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        errorMessage: normalized,
      );
    });
  }

  Future<void> playQueue({
    required PluginRecord plugin,
    required List<MusicItem> queue,
    required int startIndex,
  }) async {
    if (queue.isEmpty || startIndex < 0 || startIndex >= queue.length) {
      return;
    }

    state = state.copyWith(
      plugin: plugin,
      queue: queue,
      currentIndex: startIndex,
      currentTrack: queue[startIndex],
      isLoading: true,
      isPlaying: false,
      position: Duration.zero,
      lyric: const ParsedLyric(),
      currentLyricIndex: -1,
      clearError: true,
      clearDuration: true,
      clearSource: true,
    );

    await _loadCurrentTrack(playWhenReady: true);
  }

  Future<void> togglePlayback() async {
    if (!state.hasTrack) {
      return;
    }
    if (state.isPlaying) {
      await _adapter.pause();
      return;
    }
    await _adapter.play();
  }

  Future<void> playPrevious() async {
    if (state.queue.isEmpty) {
      return;
    }
    final previousIndex = _resolvePreviousIndex();
    if (previousIndex == null) {
      return;
    }
    state = state.copyWith(
      currentIndex: previousIndex,
      currentTrack: state.queue[previousIndex],
      position: Duration.zero,
      isLoading: true,
      lyric: const ParsedLyric(),
      currentLyricIndex: -1,
      clearError: true,
      clearDuration: true,
      clearSource: true,
    );
    await _loadCurrentTrack(playWhenReady: true);
  }

  Future<void> playNext() async {
    if (state.queue.isEmpty) {
      return;
    }
    final nextIndex = _resolveNextIndex();
    if (nextIndex == null) {
      return;
    }
    state = state.copyWith(
      currentIndex: nextIndex,
      currentTrack: state.queue[nextIndex],
      position: Duration.zero,
      isLoading: true,
      lyric: const ParsedLyric(),
      currentLyricIndex: -1,
      clearError: true,
      clearDuration: true,
      clearSource: true,
    );
    await _loadCurrentTrack(playWhenReady: true);
  }

  Future<void> seek(Duration position) async {
    if (!state.hasTrack) {
      return;
    }
    await _adapter.seek(position);
    state = state.copyWith(position: position);
  }

  Future<void> setVolume(double volume) async {
    await _adapter.setVolume(volume.clamp(0, 1));
    state = state.copyWith(volume: volume.clamp(0, 1));
  }

  Future<void> setRate(double rate) async {
    final next = rate.clamp(0.25, 2.0);
    await _adapter.setRate(next);
    state = state.copyWith(rate: next);
  }

  Future<void> setQuality(
    String quality, {
    bool applyToCurrentTrackOnly = false,
  }) async {
    final currentTrack = state.currentTrack;
    final nextOverrides = Map<String, String>.from(state.qualityOverrides);
    if (currentTrack != null && applyToCurrentTrackOnly) {
      nextOverrides[queueTrackKey(currentTrack)] = quality;
    }

    state = state.copyWith(
      defaultQuality: applyToCurrentTrackOnly ? state.defaultQuality : quality,
      qualityOverrides: nextOverrides,
      currentQuality: quality,
    );

    if (currentTrack != null) {
      final resumeAt = state.position;
      final wasPlaying = state.isPlaying;
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        clearSource: true,
      );
      await _loadCurrentTrack(
        playWhenReady: wasPlaying,
        resumeAt: resumeAt,
        qualityOverride: quality,
      );
    }
  }

  void toggleRepeatMode() {
    state = state.copyWith(
      repeatMode: switch (state.repeatMode) {
        RepeatMode.listLoop => RepeatMode.singleLoop,
        RepeatMode.singleLoop => RepeatMode.shuffle,
        RepeatMode.shuffle => RepeatMode.listLoop,
      },
    );
  }

  void setRepeatMode(RepeatMode repeatMode) {
    if (state.repeatMode == repeatMode) {
      return;
    }
    state = state.copyWith(repeatMode: repeatMode);
  }

  void toggleDesktopLyric() {
    state = state.copyWith(desktopLyricVisible: !state.desktopLyricVisible);
  }

  void toggleMiniMode() {
    state = state.copyWith(miniModeVisible: !state.miniModeVisible);
  }

  void setMiniModeVisible(bool visible) {
    state = state.copyWith(miniModeVisible: visible);
  }

  void togglePlaylistPanel() {
    state = state.copyWith(playlistPanelVisible: !state.playlistPanelVisible);
  }

  void closePlaylistPanel() {
    state = state.copyWith(playlistPanelVisible: false);
  }

  void updateDesktopLyricOffset(Offset offset) {
    state = state.copyWith(desktopLyricOffset: offset);
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= state.queue.length) {
      return;
    }
    state = state.copyWith(
      currentIndex: index,
      currentTrack: state.queue[index],
      isLoading: true,
      position: Duration.zero,
      lyric: const ParsedLyric(),
      currentLyricIndex: -1,
      clearError: true,
      clearDuration: true,
      clearSource: true,
    );
    await _loadCurrentTrack(playWhenReady: true);
  }

  Future<void> removeFromQueueAt(int index) async {
    if (index < 0 || index >= state.queue.length) {
      return;
    }
    final nextQueue = state.queue.toList(growable: true)..removeAt(index);
    final currentIndex = state.currentIndex;
    if (nextQueue.isEmpty) {
      state = const PlayerState();
      await _adapter.pause();
      return;
    }

    if (currentIndex == null) {
      state = state.copyWith(queue: nextQueue);
      return;
    }

    if (index == currentIndex) {
      final nextIndex = currentIndex >= nextQueue.length
          ? nextQueue.length - 1
          : currentIndex;
      state = state.copyWith(
        queue: nextQueue,
        currentIndex: nextIndex,
        currentTrack: nextQueue[nextIndex],
        isLoading: true,
        position: Duration.zero,
        lyric: const ParsedLyric(),
        currentLyricIndex: -1,
        clearError: true,
        clearDuration: true,
        clearSource: true,
      );
      await _loadCurrentTrack(playWhenReady: true);
      return;
    }

    state = state.copyWith(
      queue: nextQueue,
      currentIndex: index < currentIndex ? currentIndex - 1 : currentIndex,
    );
  }

  Future<void> clearQueue() async {
    await _adapter.pause();
    state = const PlayerState();
  }

  Future<void> _loadCurrentTrack({
    required bool playWhenReady,
    Duration? resumeAt,
    String? qualityOverride,
  }) async {
    final track = state.currentTrack;
    if (track == null) {
      return;
    }

    try {
      final plugin = _resolvePluginForTrack(track, fallback: state.plugin);
      if (plugin == null) {
        throw StateError(
          'Plugin not found for track platform: ${track.platform}',
        );
      }

      final PluginMethodService methodService = await ref.read(
        pluginMethodServiceProvider.future,
      );
      final patch = await methodService.getMusicInfo(
        plugin: plugin,
        mediaItem: track,
      );
      final resolvedTrack = patch == null ? track : track.mergePatch(patch);
      final source = await methodService.getMediaSource(
        plugin: plugin,
        musicItem: resolvedTrack,
        quality: qualityOverride ?? _qualityForTrack(resolvedTrack),
        throwOnFailure: true,
      );
      if (source == null || source.url.isEmpty) {
        throw StateError('No playable source returned.');
      }

      await _adapter.setSource(url: source.url, headers: source.headers);
      if (resumeAt != null && resumeAt > Duration.zero) {
        await _adapter.seek(resumeAt);
      }

      if (playWhenReady) {
        await _adapter.play();
      }

      final lyricResult = await methodService.getLyric(
        plugin: plugin,
        musicItem: resolvedTrack,
      );
      final lyric = ParsedLyric.fromRaw(
        raw: lyricResult?.rawLyric,
        translation: lyricResult?.translation,
      );
      final currentPosition = resumeAt ?? Duration.zero;

      state = state.copyWith(
        plugin: plugin,
        currentTrack: resolvedTrack,
        currentSourceUrl: source.url,
        currentSourceHeaders: source.headers,
        currentQuality: qualityOverride ?? _qualityForTrack(resolvedTrack),
        isLoading: false,
        isPlaying: playWhenReady || _adapter.isPlaying,
        position: currentPosition,
        lyric: lyric,
        currentLyricIndex: lyric.resolveCurrentIndex(currentPosition),
        clearError: true,
      );
      await ref
          .read(recentPlaybackControllerProvider.notifier)
          .record(pluginId: plugin.storageKey, musicItem: resolvedTrack);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        errorMessage: error.toString(),
      );
    }
  }

  String _qualityForTrack(MusicItem track) {
    return state.qualityOverrides[queueTrackKey(track)] ?? state.defaultQuality;
  }

  int? _resolveNextIndex() {
    if (state.queue.isEmpty) {
      return null;
    }
    final currentIndex = state.currentIndex ?? 0;
    return switch (state.repeatMode) {
      RepeatMode.singleLoop => currentIndex,
      RepeatMode.shuffle => _randomQueueIndex(excluding: currentIndex),
      RepeatMode.listLoop => (currentIndex + 1) % state.queue.length,
    };
  }

  int? _resolvePreviousIndex() {
    if (state.queue.isEmpty) {
      return null;
    }
    final currentIndex = state.currentIndex ?? 0;
    return switch (state.repeatMode) {
      RepeatMode.singleLoop => currentIndex,
      RepeatMode.shuffle => _randomQueueIndex(excluding: currentIndex),
      RepeatMode.listLoop =>
        currentIndex == 0 ? state.queue.length - 1 : currentIndex - 1,
    };
  }

  int _randomQueueIndex({required int excluding}) {
    if (state.queue.length <= 1) {
      return 0;
    }
    final random = math.Random();
    var next = excluding;
    while (next == excluding) {
      next = random.nextInt(state.queue.length);
    }
    return next;
  }

  Future<void> _handlePlaybackCompleted() async {
    if (!state.hasTrack || state.queue.isEmpty) {
      return;
    }
    final nextIndex = _resolveNextIndex();
    if (nextIndex == null) {
      return;
    }
    state = state.copyWith(
      currentIndex: nextIndex,
      currentTrack: state.queue[nextIndex],
      position: Duration.zero,
      isLoading: true,
      lyric: const ParsedLyric(),
      currentLyricIndex: -1,
      clearError: true,
      clearDuration: true,
      clearSource: true,
    );
    await _loadCurrentTrack(playWhenReady: true);
  }

  PluginRecord? _resolvePluginForTrack(
    MusicItem track, {
    PluginRecord? fallback,
  }) {
    if (_matchesTrackPlatform(fallback, track.platform)) {
      return fallback;
    }

    if (track.platform == buildLocalPluginRecord().storageKey ||
        track.platform == buildLocalPluginRecord().manifest?.platform) {
      return buildLocalPluginRecord();
    }

    final snapshot = ref.read(pluginControllerProvider).valueOrNull;
    if (snapshot == null) {
      return fallback;
    }

    for (final plugin in snapshot.plugins) {
      if (_matchesTrackPlatform(plugin, track.platform)) {
        return plugin;
      }
    }
    return fallback;
  }

  bool _matchesTrackPlatform(PluginRecord? plugin, String platform) {
    if (plugin == null) {
      return false;
    }
    return plugin.storageKey == platform ||
        plugin.hash == platform ||
        plugin.manifest?.platform == platform;
  }
}
