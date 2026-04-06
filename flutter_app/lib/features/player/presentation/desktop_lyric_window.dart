import 'dart:async';
import 'dart:convert';

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
    this.currentLyricIndex,
    this.currentLyric,
    this.translation,
    this.playing = false,
  });

  final String? title;
  final String? artist;
  final String? plugin;
  final int? currentLyricIndex;
  final String? currentLyric;
  final String? translation;
  final bool playing;

  factory DesktopLyricWindowData.fromJson(Map<String, dynamic> json) {
    return DesktopLyricWindowData(
      title: json['title']?.toString(),
      artist: json['artist']?.toString(),
      plugin: json['plugin']?.toString(),
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
      'currentLyricIndex': currentLyricIndex,
      'currentLyric': currentLyric,
      'translation': translation,
      'playing': playing,
    };
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
