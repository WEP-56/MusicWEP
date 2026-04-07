import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class WindowSizeStorage {
  const WindowSizeStorage._();

  static const Size minimumSize = Size(1100, 720);
  static const Size fallbackSize = Size(1280, 720);

  static Future<Size?> readWindowSize() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) {
        return null;
      }
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) {
        return null;
      }
      final width = (raw['width'] as num?)?.toDouble();
      final height = (raw['height'] as num?)?.toDouble();
      if (width == null || height == null) {
        return null;
      }
      return Size(
        width < minimumSize.width ? minimumSize.width : width,
        height < minimumSize.height ? minimumSize.height : height,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeWindowSize(Size size) async {
    try {
      final file = await _stateFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode(<String, double>{
          'width': size.width,
          'height': size.height,
        }),
        flush: true,
      );
    } catch (_) {
      // Ignore persistence failures.
    }
  }

  static Future<File> _stateFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return File(
      path.join(
        supportDirectory.path,
        'MusicWEP',
        'app_data',
        'window_state.json',
      ),
    );
  }
}
