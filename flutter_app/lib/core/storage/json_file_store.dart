import 'dart:convert';
import 'dart:io';

class JsonFileStore {
  const JsonFileStore(this.filePath);

  final String filePath;

  Future<Map<String, dynamic>> readObject() async {
    final file = File(filePath);
    if (!await file.exists()) {
      return <String, dynamic>{};
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException catch (error) {
      // The file is corrupted (e.g. from a partial write). Log and return
      // empty so the app can recover rather than crashing on every launch.
      // ignore: avoid_print
      print('JsonFileStore: corrupted JSON at $filePath — $error. Resetting.');
      // Attempt to delete the corrupted file so the next write starts fresh.
      try {
        await file.delete();
      } on FileSystemException {
        // If we can't delete it, the next writeJson will overwrite it.
      }
    }
    return <String, dynamic>{};
  }

  Future<List<dynamic>> readList() async {
    final file = File(filePath);
    if (!await file.exists()) {
      return <dynamic>[];
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <dynamic>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    return <dynamic>[];
  }

  Future<void> writeJson(Object value) async {
    final file = File(filePath);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    const encoder = JsonEncoder.withIndent('  ');
    final encoded = encoder.convert(value);
    // Write atomically: write to a temp file then rename so a crash or
    // concurrent read never sees a partial write.
    final tempFile = File('${filePath}.tmp');
    await tempFile.writeAsString(encoded, flush: true);
    await tempFile.rename(filePath);
  }
}
