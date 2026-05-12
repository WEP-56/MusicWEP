import 'package:flutter/material.dart';

// Stubs for non-desktop platforms.

// ignore: non_constant_identifier_names
final _WindowManagerStub windowManager = _WindowManagerStub();

class _WindowManagerStub {
  void addListener(dynamic _) {}
  void removeListener(dynamic _) {}
  Future<void> minimize() async {}
  Future<void> maximize() async {}
  Future<void> unmaximize() async {}
  Future<void> close() async {}
  Future<bool> isMaximized() async => false;
  Future<bool> isMinimized() async => false;
  Future<bool> isFullScreen() async => false;
  Future<bool> isFocused() async => true;
  Future<bool> isVisible() async => true;
  Future<void> show() async {}
  Future<void> hide() async {}
  Future<void> focus() async {}
  Future<void> restore() async {}
  Future<void> setSkipTaskbar(bool _) async {}
  Future<void> startDragging() async {}
  Future<void> setAlwaysOnTop(bool _) async {}
  Future<void> setAsFrameless() async {}
  Future<void> setHasShadow(bool _) async {}
  Future<void> setBackgroundColor(Color _) async {}
  Future<void> setPreventClose(bool _) async {}
  Future<Size> getSize() async => Size.zero;
  Future<void> waitUntilReadyToShow(dynamic _, dynamic __) async {}
  Future<void> ensureInitialized() async {}
}

mixin WindowListener {}

class WindowOptions {
  const WindowOptions({
    this.backgroundColor,
    this.titleBarStyle,
    this.windowButtonVisibility,
    this.minimumSize,
    this.size,
    this.alwaysOnTop,
  });
  final Color? backgroundColor;
  final dynamic titleBarStyle;
  final bool? windowButtonVisibility;
  final Size? minimumSize;
  final Size? size;
  final bool? alwaysOnTop;
}

class TitleBarStyle {
  static const hidden = TitleBarStyle._();
  const TitleBarStyle._();
}

class DragToResizeArea extends StatelessWidget {
  const DragToResizeArea({
    super.key,
    required this.child,
    this.resizeEdgeSize,
    this.resizeEdgeMargin,
  });
  final Widget child;
  final double? resizeEdgeSize;
  final EdgeInsets? resizeEdgeMargin;

  @override
  Widget build(BuildContext context) => child;
}

class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
