import 'dart:async';
import 'dart:io';

/// Per-instance rolling log writer. Each plugin gets a log file under
/// `pluginLogsDirectory/<storageKey>.log`. When the file exceeds
/// [maxBytes] it is rotated to `<storageKey>.log.1` (older rotations are
/// discarded).
///
/// Writing is queued so concurrent callers cannot interleave lines.
class PluginRuntimeLogger {
  PluginRuntimeLogger({
    required this.directoryPath,
    required this.storageKey,
    this.maxBytes = 1024 * 1024,
  });

  final String directoryPath;
  final String storageKey;
  final int maxBytes;

  Future<void> _tail = Future<void>.value();

  String get logFilePath => '$directoryPath/${_sanitize(storageKey)}.log';
  String get rotatedFilePath =>
      '$directoryPath/${_sanitize(storageKey)}.log.1';

  /// Enqueues an ASCII-safe log line. The future completes when the line
  /// has been flushed to disk (or silently dropped on I/O error).
  Future<void> append({
    required String level,
    required String message,
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final sanitized = _ensureAscii(message);
    final line = '$timestamp [$level] $sanitized\n';
    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        final dir = Directory(directoryPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final file = File(logFilePath);
        if (await file.exists()) {
          final length = await file.length();
          if (length + line.length > maxBytes) {
            try {
              final rotated = File(rotatedFilePath);
              if (await rotated.exists()) await rotated.delete();
              await file.rename(rotatedFilePath);
            } on FileSystemException {
              // If rotation fails (file locked, cross-device), truncate
              // instead of losing the next write.
              try {
                await file.writeAsString('');
              } on FileSystemException {
                // Give up rotating and let the append below handle it.
              }
            }
          }
        }
        await file.writeAsString(line, mode: FileMode.append, flush: false);
      } on FileSystemException catch (error) {
        // We deliberately do not throw — logging must never break invocation.
        // Surface the failure to stderr so tests / dev builds can spot it.
        // ignore: avoid_print
        stderr.writeln(
          'PluginRuntimeLogger ($storageKey) failed: $error',
        );
      }
      completer.complete();
    });
    return completer.future;
  }

  String _sanitize(String key) {
    return key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _ensureAscii(String value) {
    if (value.isEmpty) return value;
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x20 && rune < 0x7F) {
        buffer.writeCharCode(rune);
      } else if (rune == 0x0A || rune == 0x09) {
        // Preserve LF / TAB but escape everything else so log lines stay
        // single-line.
        buffer.write('\\x${rune.toRadixString(16).padLeft(2, '0')}');
      } else {
        final code = rune.toRadixString(16).toUpperCase().padLeft(2, '0');
        buffer.write(rune <= 0xFFFF ? '\\u$code' : '\\U$code');
      }
    }
    return buffer.toString();
  }
}
