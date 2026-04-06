import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class DesktopLyricWindowArgs {
  const DesktopLyricWindowArgs({
    required this.type,
    this.mainWindowId,
    this.initialData,
  });

  final String type;
  final String? mainWindowId;
  final DesktopLyricWindowData? initialData;

  static const String main = 'main';
  static const String lyric = 'lyric';
  static const String miniMode = 'mini_mode';

  static DesktopLyricWindowArgs parse(String raw) {
    if (raw.trim().isEmpty) {
      return const DesktopLyricWindowArgs(type: main);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return DesktopLyricWindowArgs(
          type: decoded['type']?.toString() ?? main,
          mainWindowId: decoded['mainWindowId']?.toString(),
          initialData: decoded['initialData'] is Map
              ? DesktopLyricWindowData.fromJson(
                  (decoded['initialData'] as Map).map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                )
              : null,
        );
      }
    } catch (_) {}
    return const DesktopLyricWindowArgs(type: main);
  }

  String encode() {
    return jsonEncode(<String, dynamic>{
      'type': type,
      'mainWindowId': mainWindowId,
      'initialData': initialData?.toJson(),
    });
  }
}

class DesktopLyricWindowData {
  const DesktopLyricWindowData({
    this.title,
    this.artist,
    this.plugin,
    this.artwork,
    this.currentLyricIndex,
    this.currentLyric,
    this.translation,
    this.playing = false,
  });

  final String? title;
  final String? artist;
  final String? plugin;
  final String? artwork;
  final int? currentLyricIndex;
  final String? currentLyric;
  final String? translation;
  final bool playing;

  factory DesktopLyricWindowData.fromJson(Map<String, dynamic> json) {
    return DesktopLyricWindowData(
      title: json['title']?.toString(),
      artist: json['artist']?.toString(),
      plugin: json['plugin']?.toString(),
      artwork: json['artwork']?.toString(),
      currentLyricIndex: switch (json['currentLyricIndex']) {
        final int value => value,
        final num value => value.toInt(),
        final String value => int.tryParse(value),
        _ => null,
      },
      currentLyric: json['currentLyric']?.toString(),
      translation: json['translation']?.toString(),
      playing: json['playing'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'artist': artist,
      'plugin': plugin,
      'artwork': artwork,
      'currentLyricIndex': currentLyricIndex,
      'currentLyric': currentLyric,
      'translation': translation,
      'playing': playing,
    };
  }
}

class DesktopMiniModeWindowApp extends StatefulWidget {
  const DesktopMiniModeWindowApp({super.key, required this.args});

  final DesktopLyricWindowArgs args;

  @override
  State<DesktopMiniModeWindowApp> createState() =>
      _DesktopMiniModeWindowAppState();
}

class _DesktopMiniModeWindowAppState extends State<DesktopMiniModeWindowApp>
    with WindowListener {
  late DesktopLyricWindowData _data;
  WindowController? _currentWindow;
  WindowController? _mainWindow;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _data = widget.args.initialData ?? const DesktopLyricWindowData();
    _setup();
  }

  Future<void> _setup() async {
    _currentWindow = await WindowController.fromCurrentEngine();
    _mainWindow = widget.args.mainWindowId == null
        ? null
        : WindowController.fromWindowId(widget.args.mainWindowId!);

    await _currentWindow!.setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'sync_lyric_data':
          final arguments = call.arguments;
          if (arguments is Map && mounted) {
            setState(() {
              _data = DesktopLyricWindowData.fromJson(
                arguments.map((key, value) => MapEntry(key.toString(), value)),
              );
            });
          }
          return true;
        case 'window_close':
          await windowManager.close();
          return true;
        default:
          throw MissingPluginException('Unknown method ${call.method}');
      }
    });

    windowManager.addListener(this);
    const options = WindowOptions(
      size: Size(340, 88),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      skipTaskbar: true,
      alwaysOnTop: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.show();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _sendControl(String action) async {
    if (_mainWindow == null) {
      return;
    }
    await _mainWindow!.invokeMethod('player_control', <String, dynamic>{
      'action': action,
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _data.currentLyric?.trim().isNotEmpty == true
        ? _data.currentLyric!
        : (_data.title?.trim().isNotEmpty == true ? _data.title! : '暂无歌曲');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) async => windowManager.startDragging(),
            child: Center(
              child: Container(
                width: 340,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: _MiniModeBackground(artwork: _data.artwork),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 0.8,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                const Color(0xCC18121B),
                                const Color(0xB31E1720),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _data.artwork?.isNotEmpty == true
                                  ? Image.network(
                                      _data.artwork!,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const _MiniArtworkFallback(),
                                    )
                                  : const _MiniArtworkFallback(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                child: _hovering
                                    ? _MiniModeControls(
                                        playing: _data.playing,
                                        onPrevious: () =>
                                            _sendControl('previous'),
                                        onToggle: () => _sendControl('toggle'),
                                        onNext: () => _sendControl('next'),
                                      )
                                    : _MiniModeLyricDisplay(
                                        text: displayText,
                                        translation: _data.translation,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: _hovering ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !_hovering,
                            child: InkWell(
                              onTap: () => _sendControl('close_mini'),
                              borderRadius: BorderRadius.circular(999),
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniModeBackground extends StatelessWidget {
  const _MiniModeBackground({this.artwork});

  final String? artwork;

  @override
  Widget build(BuildContext context) {
    if (artwork?.isNotEmpty != true) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF35213A), Color(0xFF1D1823)],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Image.network(
            artwork!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.06),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniArtworkFallback extends StatelessWidget {
  const _MiniArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0x55FFFFFF),
      child: const Icon(Icons.music_note_rounded, color: Colors.white),
    );
  }
}

class _MiniModeControls extends StatelessWidget {
  const _MiniModeControls({
    required this.playing,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
  });

  final bool playing;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey<String>('controls'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _MiniControlButton(
          icon: Icons.skip_previous_rounded,
          onTap: onPrevious,
        ),
        const SizedBox(width: 18),
        _MiniControlButton(
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: onToggle,
          prominent: true,
        ),
        const SizedBox(width: 18),
        _MiniControlButton(icon: Icons.skip_next_rounded, onTap: onNext),
      ],
    );
  }
}

class _MiniModeLyricDisplay extends StatelessWidget {
  const _MiniModeLyricDisplay({required this.text, this.translation});

  final String text;
  final String? translation;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('lyrics'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (translation?.trim().isNotEmpty == true) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            translation!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniControlButton extends StatelessWidget {
  const _MiniControlButton({
    required this.icon,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Icon(icon, size: prominent ? 40 : 30, color: Colors.white),
    );
  }
}

class DesktopLyricWindowApp extends StatefulWidget {
  const DesktopLyricWindowApp({super.key, required this.args});

  final DesktopLyricWindowArgs args;

  @override
  State<DesktopLyricWindowApp> createState() => _DesktopLyricWindowAppState();
}

class _DesktopLyricWindowAppState extends State<DesktopLyricWindowApp>
    with WindowListener {
  late DesktopLyricWindowData _data;
  WindowController? _currentWindow;
  WindowController? _mainWindow;
  bool _showChrome = false;
  bool _showLockButton = false;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _data = widget.args.initialData ?? const DesktopLyricWindowData();
    _setup();
  }

  Future<void> _setup() async {
    _currentWindow = await WindowController.fromCurrentEngine();
    _mainWindow = widget.args.mainWindowId == null
        ? null
        : WindowController.fromWindowId(widget.args.mainWindowId!);

    await _currentWindow!.setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'sync_lyric_data':
          final arguments = call.arguments;
          if (arguments is Map && mounted) {
            setState(() {
              _data = DesktopLyricWindowData.fromJson(
                arguments.map((key, value) => MapEntry(key.toString(), value)),
              );
            });
          }
          return true;
        case 'window_close':
          await windowManager.close();
          return true;
        default:
          throw MissingPluginException('Unknown method ${call.method}');
      }
    });

    windowManager.addListener(this);
    const options = WindowOptions(
      size: Size(900, 210),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      skipTaskbar: true,
      alwaysOnTop: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.show();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  void _updateHoverState(bool hovering) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (_locked) {
        _showChrome = false;
        _showLockButton = hovering;
        return;
      }
      _showChrome = hovering;
      _showLockButton = false;
    });
  }

  void _toggleLock() {
    setState(() {
      _locked = !_locked;
      if (_locked) {
        _showChrome = false;
        _showLockButton = true;
      } else {
        _showChrome = true;
        _showLockButton = false;
      }
    });
  }

  Future<void> _sendControl(String action) async {
    if (_mainWindow == null) {
      return;
    }
    await _mainWindow!.invokeMethod('player_control', <String, dynamic>{
      'action': action,
    });
  }

  @override
  Widget build(BuildContext context) {
    final lyricText = _data.currentLyric?.trim().isNotEmpty == true
        ? _data.currentLyric!
        : (_data.title ?? '暂无歌词');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: MouseRegion(
          onEnter: (_) => _updateHoverState(true),
          onHover: (_) => _updateHoverState(true),
          onExit: (_) => _updateHoverState(false),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: _locked
                ? null
                : (_) async {
                    _updateHoverState(true);
                    await windowManager.startDragging();
                  },
            onTap: () => _updateHoverState(true),
            child: Center(
              child: Stack(
                alignment: Alignment.topRight,
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 860,
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
                    decoration: BoxDecoration(
                      color: !_locked && _showChrome
                          ? const Color(0x44000000)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: !_locked && _showChrome
                          ? Border.all(color: const Color(0x22FFFFFF))
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: !_locked && _showChrome ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: _locked || !_showChrome,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                _LyricActionButton(
                                  icon: Icons.skip_previous_rounded,
                                  onTap: () => _sendControl('previous'),
                                ),
                                const SizedBox(width: 6),
                                _LyricActionButton(
                                  icon: _data.playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  onTap: () => _sendControl('toggle'),
                                ),
                                const SizedBox(width: 6),
                                _LyricActionButton(
                                  icon: Icons.skip_next_rounded,
                                  onTap: () => _sendControl('next'),
                                ),
                                const SizedBox(width: 6),
                                _LyricActionButton(
                                  icon: Icons.close_rounded,
                                  onTap: () => _sendControl('close_lyric'),
                                ),
                                const SizedBox(width: 6),
                                _LyricActionButton(
                                  icon: Icons.lock_open_rounded,
                                  onTap: _toggleLock,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: !_locked && _showChrome ? 16 : 0),
                        Text(
                          lyricText,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFF1A4),
                            shadows: <Shadow>[
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        if (_data.translation?.trim().isNotEmpty ==
                            true) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            _data.translation!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              color: Colors.white,
                            ),
                          ),
                        ] else if (_data.artist?.trim().isNotEmpty ==
                            true) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            _data.artist!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _locked && _showLockButton ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_locked || !_showLockButton,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, right: 8),
                        child: _LyricActionButton(
                          icon: Icons.lock_rounded,
                          onTap: _toggleLock,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricActionButton extends StatelessWidget {
  const _LyricActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x22000000),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
