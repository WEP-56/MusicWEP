import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub for non-desktop platforms.
class DesktopWindowBridgeController {
  DesktopWindowBridgeController(WidgetRef ref);
  Future<void> init(WidgetRef ref) async {}
  void dispose() {}
}
