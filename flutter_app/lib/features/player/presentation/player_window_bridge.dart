import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_state.dart';
import '../player_providers.dart';

// Desktop-only imports.
import 'player_window_bridge_desktop.dart'
    if (dart.library.html) 'player_window_bridge_stub.dart';

class PlayerWindowBridge extends ConsumerStatefulWidget {
  const PlayerWindowBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlayerWindowBridge> createState() => _PlayerWindowBridgeState();
}

class _PlayerWindowBridgeState extends ConsumerState<PlayerWindowBridge> {
  DesktopWindowBridgeController? _desktopController;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _desktopController = DesktopWindowBridgeController(ref);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _desktopController?.init(ref);
      });
    }
  }

  @override
  void dispose() {
    _desktopController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

