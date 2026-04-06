import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../../core/filesystem/app_paths.dart';

class PluginFileRepository {
  const PluginFileRepository(this.appPaths);

  final AppPaths appPaths;

  Future<List<File>> listPluginFiles() async {
    if (!await appPaths.pluginsDirectory.exists()) {
      return <File>[];
    }

    final entities = await appPaths.pluginsDirectory.list().toList();
    final files =
        entities
            .whereType<File>()
            .where((file) => path.extension(file.path).toLowerCase() == '.js')
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<String> readScript(String filePath) {
    return File(filePath).readAsString();
  }

  String calculateHash(String script) {
    return sha256.convert(utf8.encode(script)).toString();
  }

  Future<String> importLocalFile(String sourcePath) async {
    final sourceFile = File(sourcePath);
    final script = await sourceFile.readAsString();
    return writeScript(
      script,
      preferredBaseName: path.basenameWithoutExtension(sourceFile.path),
    );
  }

  Future<String> writeScript(String script, {String? preferredBaseName}) async {
    final baseName = _sanitizeBaseName(preferredBaseName);
    final targetFile = File(
      path.join(
        appPaths.pluginsDirectory.path,
        '${baseName}_${DateTime.now().millisecondsSinceEpoch}.js',
      ),
    );
    await targetFile.writeAsString(script);
    return targetFile.path;
  }

  Future<void> deletePlugin(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _sanitizeBaseName(String? raw) {
    final value = (raw == null || raw.trim().isEmpty) ? 'plugin' : raw.trim();
    final normalized = value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    return normalized.isEmpty ? 'plugin' : normalized;
  }
}
