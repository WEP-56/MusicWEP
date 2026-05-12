import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_state.dart';
import '../player_providers.dart';

/// Bridges the existing [PlayerController] to [audio_service] so Android
/// shows a persistent media notification with playback controls.
class MusicWEPAudioHandler extends BaseAudioHandler {
  MusicWEPAudioHandler(this._container) {
    _subscription = _container.listen(
      playerControllerProvider,
      (_, next) => _syncState(next),
      fireImmediately: true,
    );
  }

  final ProviderContainer _container;
  ProviderSubscription<PlayerState>? _subscription;

  void _syncState(PlayerState state) {
    final track = state.currentTrack;
    if (track != null) {
      mediaItem.add(
        MediaItem(
          id: '${track.platform}@${track.id}',
          title: track.title ?? '未知曲目',
          artist: track.artist,
          album: track.album,
          artUri: track.artwork?.isNotEmpty == true
              ? Uri.tryParse(track.artwork!)
              : null,
          duration: state.duration,
        ),
      );
    } else {
      mediaItem.add(null);
    }

    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          state.isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: state.isLoading
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        playing: state.isPlaying,
        updatePosition: state.position,
        bufferedPosition: state.duration ?? Duration.zero,
        speed: state.rate,
      ),
    );
  }

  @override
  Future<void> play() async {
    final s = _container.read(playerControllerProvider);
    if (!s.isPlaying) {
      await _container.read(playerControllerProvider.notifier).togglePlayback();
    }
  }

  @override
  Future<void> pause() async {
    final s = _container.read(playerControllerProvider);
    if (s.isPlaying) {
      await _container.read(playerControllerProvider.notifier).togglePlayback();
    }
  }

  @override
  Future<void> skipToNext() =>
      _container.read(playerControllerProvider.notifier).playNext();

  @override
  Future<void> skipToPrevious() =>
      _container.read(playerControllerProvider.notifier).playPrevious();

  @override
  Future<void> seek(Duration position) =>
      _container.read(playerControllerProvider.notifier).seek(position);

  @override
  Future<void> stop() async {
    await super.stop();
    _subscription?.close();
  }
}

/// Provider that holds the audio handler singleton (Android only).
final audioHandlerProvider = Provider<MusicWEPAudioHandler?>((ref) => null);
