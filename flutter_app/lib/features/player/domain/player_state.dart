import 'dart:ui';

import '../../../core/media/media_models.dart';
import '../../plugins/domain/plugin.dart';
import 'player_models.dart';

class PlayerState {
  const PlayerState({
    this.plugin,
    this.queue = const <MusicItem>[],
    this.currentIndex,
    this.currentTrack,
    this.currentSourceUrl,
    this.currentSourceHeaders = const <String, String>{},
    this.isLoading = false,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.volume = 1,
    this.rate = 1,
    this.repeatMode = RepeatMode.listLoop,
    this.defaultQuality = 'standard',
    this.qualityOverrides = const <String, String>{},
    this.currentQuality = 'standard',
    this.desktopLyricVisible = false,
    this.playlistPanelVisible = false,
    this.desktopLyricOffset = const Offset(48, 96),
    this.lyric = const ParsedLyric(),
    this.currentLyricIndex = -1,
    this.errorMessage,
  });

  final PluginRecord? plugin;
  final List<MusicItem> queue;
  final int? currentIndex;
  final MusicItem? currentTrack;
  final String? currentSourceUrl;
  final Map<String, String> currentSourceHeaders;
  final bool isLoading;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final double volume;
  final double rate;
  final RepeatMode repeatMode;
  final String defaultQuality;
  final Map<String, String> qualityOverrides;
  final String currentQuality;
  final bool desktopLyricVisible;
  final bool playlistPanelVisible;
  final Offset desktopLyricOffset;
  final ParsedLyric lyric;
  final int currentLyricIndex;
  final String? errorMessage;

  bool get hasTrack => currentTrack != null;
  bool get hasPrevious => queue.length > 1;
  bool get hasNext => queue.length > 1;
  ParsedLyricLine? get currentLyricLine {
    if (currentLyricIndex < 0 || currentLyricIndex >= lyric.lines.length) {
      return null;
    }
    return lyric.lines[currentLyricIndex];
  }

  PlayerState copyWith({
    PluginRecord? plugin,
    List<MusicItem>? queue,
    int? currentIndex,
    MusicItem? currentTrack,
    String? currentSourceUrl,
    Map<String, String>? currentSourceHeaders,
    bool? isLoading,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? volume,
    double? rate,
    RepeatMode? repeatMode,
    String? defaultQuality,
    Map<String, String>? qualityOverrides,
    String? currentQuality,
    bool? desktopLyricVisible,
    bool? playlistPanelVisible,
    Offset? desktopLyricOffset,
    ParsedLyric? lyric,
    int? currentLyricIndex,
    String? errorMessage,
    bool clearError = false,
    bool clearDuration = false,
    bool clearSource = false,
  }) {
    return PlayerState(
      plugin: plugin ?? this.plugin,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      currentTrack: currentTrack ?? this.currentTrack,
      currentSourceUrl: clearSource
          ? null
          : (currentSourceUrl ?? this.currentSourceUrl),
      currentSourceHeaders: clearSource
          ? const <String, String>{}
          : (currentSourceHeaders ?? this.currentSourceHeaders),
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: clearDuration ? null : (duration ?? this.duration),
      volume: volume ?? this.volume,
      rate: rate ?? this.rate,
      repeatMode: repeatMode ?? this.repeatMode,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      qualityOverrides: qualityOverrides ?? this.qualityOverrides,
      currentQuality: currentQuality ?? this.currentQuality,
      desktopLyricVisible: desktopLyricVisible ?? this.desktopLyricVisible,
      playlistPanelVisible: playlistPanelVisible ?? this.playlistPanelVisible,
      desktopLyricOffset: desktopLyricOffset ?? this.desktopLyricOffset,
      lyric: lyric ?? this.lyric,
      currentLyricIndex: currentLyricIndex ?? this.currentLyricIndex,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
