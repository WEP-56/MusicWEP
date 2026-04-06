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

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
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
    await file.writeAsString(encoder.convert(value));
  }
}
