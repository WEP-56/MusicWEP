import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_state.dart';
import '../player_providers.dart';
import 'desktop_lyric_window.dart';

class PlayerWindowBridge extends ConsumerStatefulWidget {
  const PlayerWindowBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlayerWindowBridge> createState() => _PlayerWindowBridgeState();
}

class _PlayerWindowBridgeState extends ConsumerState<PlayerWindowBridge> {
  WindowController? _mainWindow;
  WindowController? _lyricWindow;
  bool _openingLyricWindow = false;
  PlayerState? _latestState;
  ProviderSubscription<PlayerState>? _playerStateSubscription;
  String? _lastSyncedPayload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setupWindowHandlers();
      _latestState = ref.read(playerControllerProvider);
      _playerStateSubscription = ref.listenManual(playerControllerProvider, (
        _,
        next,
      ) {
        _latestState = next;
        unawaited(_syncLyricWindow(next));
      });
      if (_latestState != null) {
        unawaited(_syncLyricWindow(_latestState!));
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.close();
    super.dispose();
  }

  Future<void> _setupWindowHandlers() async {
    _mainWindow = await WindowController.fromCurrentEngine();
    await _mainWindow!.setWindowMethodHandler((call) async {
      if (call.method != 'player_control') {
        return null;
      }
      final args = call.arguments;
      final action = args is Map ? args['action']?.toString() : null;
      final controller = ref.read(playerControllerProvider.notifier);
      switch (action) {
        case 'previous':
          await controller.playPrevious();
          break;
        case 'next':
          await controller.playNext();
          break;
        case 'toggle':
          await controller.togglePlayback();
          break;
        case 'close_lyric':
          controller.toggleDesktopLyric();
          break;
      }
      return true;
    });
  }

  Future<void> _syncLyricWindow(PlayerState state) async {
    if (state.desktopLyricVisible) {
      await _ensureLyricWindow();
      await _pushLyricState(state);
    } else {
      _lastSyncedPayload = null;
      await _closeLyricWindow();
    }
  }

  Future<void> _ensureLyricWindow() async {
    if (_lyricWindow != null || _openingLyricWindow) {
      return;
    }
    _openingLyricWindow = true;
    try {
      final mainWindow =
          _mainWindow ?? await WindowController.fromCurrentEngine();
      final latestState = _latestState;
      final args = DesktopLyricWindowArgs(
        type: DesktopLyricWindowArgs.lyric,
        mainWindowId: mainWindow.windowId,
        initialData: latestState == null
            ? null
            : DesktopLyricWindowData(
                title: latestState.currentTrack?.title,
                artist: latestState.currentTrack?.artist,
                plugin: latestState.plugin?.displayName,
                currentLyricIndex: latestState.currentLyricIndex,
                currentLyric: latestState.currentLyricLine?.text,
                translation: latestState.currentLyricLine?.translation,
                playing: latestState.isPlaying,
              ),
      );
      final controller = await WindowController.create(
        WindowConfiguration(hiddenAtLaunch: true, arguments: args.encode()),
      );
      _lyricWindow = controller;
      if (latestState != null && latestState.desktopLyricVisible) {
        await _pushLyricState(latestState);
      }
    } finally {
      _openingLyricWindow = false;
    }
  }

  Future<void> _pushLyricState(PlayerState state) async {
    final window = _lyricWindow;
    if (window == null) {
      return;
    }
    final payload = <String, dynamic>{
      'title': state.currentTrack?.title,
      'artist': state.currentTrack?.artist,
      'plugin': state.plugin?.displayName,
      'currentLyricIndex': state.currentLyricIndex,
      'currentLyric': state.currentLyricLine?.text,
      'translation': state.currentLyricLine?.translation,
      'playing': state.isPlaying,
    };
    final signature = jsonEncode(payload);
    if (_lastSyncedPayload == signature) {
      return;
    }
    try {
      await window.invokeMethod('sync_lyric_data', payload);
      _lastSyncedPayload = signature;
    } catch (_) {}
  }

  Future<void> _closeLyricWindow() async {
    final window = _lyricWindow;
    _lyricWindow = null;
    if (window == null) {
      return;
    }
    try {
      await window.invokeMethod('window_close');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
