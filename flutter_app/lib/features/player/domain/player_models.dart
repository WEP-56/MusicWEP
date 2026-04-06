import '../../../core/media/media_models.dart';

enum RepeatMode { listLoop, singleLoop, shuffle }

class ParsedLyricLine {
  const ParsedLyricLine({
    required this.time,
    required this.text,
    this.translation,
  });

  final Duration time;
  final String text;
  final String? translation;
}

class ParsedLyric {
  const ParsedLyric({
    this.lines = const <ParsedLyricLine>[],
    this.raw,
    this.translationRaw,
  });

  final List<ParsedLyricLine> lines;
  final String? raw;
  final String? translationRaw;

  bool get hasContent => lines.isNotEmpty || (raw?.trim().isNotEmpty ?? false);

  int resolveCurrentIndex(Duration position) {
    if (lines.isEmpty) {
      return -1;
    }
    for (var index = lines.length - 1; index >= 0; index--) {
      if (position >= lines[index].time) {
        return index;
      }
    }
    return -1;
  }

  ParsedLyricLine? resolveCurrentLine(Duration position) {
    final index = resolveCurrentIndex(position);
    if (index < 0 || index >= lines.length) {
      return null;
    }
    return lines[index];
  }

  static ParsedLyric fromRaw({String? raw, String? translation}) {
    final base = _parseEntries(raw);
    if (base.isEmpty) {
      return ParsedLyric(raw: raw, translationRaw: translation);
    }

    final translationMap = <int, String>{};
    for (final entry in _parseEntries(translation)) {
      translationMap[entry.time.inMilliseconds] = entry.text;
    }

    return ParsedLyric(
      raw: raw,
      translationRaw: translation,
      lines: base
          .map(
            (entry) => ParsedLyricLine(
              time: entry.time,
              text: entry.text,
              translation: translationMap[entry.time.inMilliseconds],
            ),
          )
          .toList(growable: false),
    );
  }

  static List<_LyricEntry> _parseEntries(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <_LyricEntry>[];
    }

    final result = <_LyricEntry>[];
    final pattern = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\]');
    for (final originalLine in raw.split(RegExp(r'\r?\n'))) {
      final matches = pattern.allMatches(originalLine).toList(growable: false);
      if (matches.isEmpty) {
        continue;
      }
      final text = originalLine.replaceAll(pattern, '').trim();
      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final milliRaw = (match.group(3) ?? '').padRight(3, '0');
        final milliseconds =
            int.tryParse(milliRaw.isEmpty ? '0' : milliRaw) ?? 0;
        result.add(
          _LyricEntry(
            time: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: milliseconds,
            ),
            text: text,
          ),
        );
      }
    }
    result.sort((left, right) => left.time.compareTo(right.time));
    return result;
  }
}

class _LyricEntry {
  const _LyricEntry({required this.time, required this.text});

  final Duration time;
  final String text;
}

String queueTrackKey(MusicItem track) => '${track.platform}@${track.id}';
