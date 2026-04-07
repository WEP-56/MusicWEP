import 'package:flutter/material.dart';

class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.label,
    required this.seedColor,
  });

  final String id;
  final String label;
  final Color seedColor;

  static const AppThemePreset sunset = AppThemePreset(
    id: 'sunset',
    label: '落日橙',
    seedColor: Color(0xFFF47C2C),
  );
  static const AppThemePreset lake = AppThemePreset(
    id: 'lake',
    label: '湖水蓝',
    seedColor: Color(0xFF2A7FFF),
  );
  static const AppThemePreset forest = AppThemePreset(
    id: 'forest',
    label: '松石绿',
    seedColor: Color(0xFF1E9E73),
  );
  static const AppThemePreset rose = AppThemePreset(
    id: 'rose',
    label: '玫瑰红',
    seedColor: Color(0xFFD85B73),
  );
  static const AppThemePreset grape = AppThemePreset(
    id: 'grape',
    label: '葡萄紫',
    seedColor: Color(0xFF6F5EF9),
  );

  static const List<AppThemePreset> values = <AppThemePreset>[
    sunset,
    lake,
    forest,
    rose,
    grape,
  ];

  static AppThemePreset fromId(String? id) {
    return values.firstWhereOrNull((item) => item.id == id) ?? sunset;
  }

  static bool isBuiltInThemeId(String id) {
    return values.any((item) => item.id == id);
  }
}

enum AppThemeBackgroundType {
  image,
  video;

  static AppThemeBackgroundType? fromJson(String? value) {
    return switch (value) {
      'image' => AppThemeBackgroundType.image,
      'video' => AppThemeBackgroundType.video,
      _ => null,
    };
  }

  static AppThemeBackgroundType? fromPath(String path) {
    final normalized = path.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.endsWith('.mp4') ||
        normalized.endsWith('.mov') ||
        normalized.endsWith('.mkv') ||
        normalized.endsWith('.webm')) {
      return AppThemeBackgroundType.video;
    }
    if (normalized.endsWith('.png') ||
        normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.webp') ||
        normalized.endsWith('.bmp') ||
        normalized.endsWith('.gif')) {
      return AppThemeBackgroundType.image;
    }
    return null;
  }

  String toJson() => name;

  String get label => switch (this) {
    AppThemeBackgroundType.image => '图片 / GIF',
    AppThemeBackgroundType.video => '视频',
  };
}

class AppThemeBackgroundData {
  const AppThemeBackgroundData({
    required this.type,
    required this.relativePath,
  });

  final AppThemeBackgroundType type;
  final String relativePath;

  factory AppThemeBackgroundData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw StateError('Background json is null');
    }

    final relativePath = json['relativePath']?.toString().trim() ?? '';
    final type =
        AppThemeBackgroundType.fromJson(json['type']?.toString()) ??
        AppThemeBackgroundType.fromPath(relativePath);
    if (relativePath.isEmpty || type == null) {
      throw StateError('Background json is invalid');
    }

    return AppThemeBackgroundData(type: type, relativePath: relativePath);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.toJson(),
      'relativePath': relativePath,
    };
  }
}

class AppCustomThemeData {
  const AppCustomThemeData({
    required this.id,
    required this.name,
    required this.seedColorValue,
    this.background,
  });

  final String id;
  final String name;
  final int seedColorValue;
  final AppThemeBackgroundData? background;

  Color get seedColor => Color(seedColorValue);

  bool get hasBackground => background != null;

  AppThemePreset get asPreset =>
      AppThemePreset(id: id, label: name, seedColor: seedColor);

  AppCustomThemeData copyWith({
    String? id,
    String? name,
    int? seedColorValue,
    AppThemeBackgroundData? background,
    bool clearBackground = false,
  }) {
    return AppCustomThemeData(
      id: id ?? this.id,
      name: name ?? this.name,
      seedColorValue: seedColorValue ?? this.seedColorValue,
      background: clearBackground ? null : (background ?? this.background),
    );
  }

  factory AppCustomThemeData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw StateError('Custom theme json is null');
    }

    final id = json['id']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final rawSeedColor = json['seedColorValue'];
    final seedColorValue = rawSeedColor is int
        ? rawSeedColor
        : int.tryParse(rawSeedColor?.toString() ?? '') ??
              AppThemePreset.sunset.seedColor.toARGB32();
    final backgroundMap = switch (json['background']) {
      final Map<String, dynamic> value => value,
      final Map value => value.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      _ => null,
    };

    AppThemeBackgroundData? background;
    if (backgroundMap != null) {
      try {
        background = AppThemeBackgroundData.fromJson(backgroundMap);
      } catch (_) {
        background = null;
      }
    }

    if (id.isEmpty || name.isEmpty) {
      throw StateError('Custom theme json is invalid');
    }

    return AppCustomThemeData(
      id: id,
      name: name,
      seedColorValue: seedColorValue,
      background: background,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'seedColorValue': seedColorValue,
      if (background != null) 'background': background!.toJson(),
    };
  }
}

class AppThemeSettings {
  const AppThemeSettings({
    required this.mode,
    required this.activeThemeId,
    required this.customThemes,
  });

  final ThemeMode mode;
  final String activeThemeId;
  final List<AppCustomThemeData> customThemes;

  static const AppThemeSettings defaults = AppThemeSettings(
    mode: ThemeMode.light,
    activeThemeId: 'sunset',
    customThemes: <AppCustomThemeData>[],
  );

  bool get hasCustomThemes => customThemes.isNotEmpty;

  AppCustomThemeData? get activeCustomTheme =>
      customThemes.firstWhereOrNull((theme) => theme.id == activeThemeId);

  bool get usesCustomTheme => activeCustomTheme != null;

  AppThemePreset get activePreset =>
      activeCustomTheme?.asPreset ?? AppThemePreset.fromId(activeThemeId);

  AppThemeSettings copyWith({
    ThemeMode? mode,
    String? activeThemeId,
    List<AppCustomThemeData>? customThemes,
  }) {
    final nextCustomThemes = customThemes ?? this.customThemes;
    final resolvedActiveThemeId = _resolveActiveThemeId(
      activeThemeId ?? this.activeThemeId,
      nextCustomThemes,
    );
    return AppThemeSettings(
      mode: mode ?? this.mode,
      activeThemeId: resolvedActiveThemeId,
      customThemes: List<AppCustomThemeData>.unmodifiable(nextCustomThemes),
    );
  }

  factory AppThemeSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return defaults;
    }

    final customThemes = <AppCustomThemeData>[
      ..._parseCustomThemes(json['customThemes']),
    ];

    final legacyCustomTheme = _parseLegacyCustomTheme(json['customTheme']);
    if (legacyCustomTheme != null &&
        customThemes.every((item) => item.id != legacyCustomTheme.id)) {
      customThemes.add(legacyCustomTheme);
    }

    final rawActiveThemeId =
        json['activeThemeId']?.toString() ??
        json['presetId']?.toString() ??
        defaults.activeThemeId;
    final resolvedActiveThemeId = _resolveActiveThemeId(
      rawActiveThemeId,
      customThemes,
    );

    return AppThemeSettings(
      mode: switch (json['mode']?.toString()) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
      activeThemeId: resolvedActiveThemeId,
      customThemes: List<AppCustomThemeData>.unmodifiable(customThemes),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
      },
      'activeThemeId': activeThemeId,
      'customThemes': customThemes
          .map((theme) => theme.toJson())
          .toList(growable: false),
    };
  }

  static List<AppCustomThemeData> _parseCustomThemes(Object? raw) {
    if (raw is! List) {
      return const <AppCustomThemeData>[];
    }

    return raw
        .map(
          (item) => switch (item) {
            final Map<String, dynamic> value => value,
            final Map value => value.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
            _ => null,
          },
        )
        .whereType<Map<String, dynamic>>()
        .map((item) {
          try {
            return AppCustomThemeData.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<AppCustomThemeData>()
        .toList(growable: false);
  }

  static AppCustomThemeData? _parseLegacyCustomTheme(Object? raw) {
    final map = switch (raw) {
      final Map<String, dynamic> value => value,
      final Map value => value.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      _ => null,
    };
    if (map == null) {
      return null;
    }

    final rawSeedColor = map['seedColorValue'];
    final seedColorValue = rawSeedColor is int
        ? rawSeedColor
        : int.tryParse(rawSeedColor?.toString() ?? '') ??
              AppThemePreset.sunset.seedColor.toARGB32();

    AppThemeBackgroundData? background;
    final legacyPath = map['backgroundRelativePath']?.toString().trim();
    final legacyType = AppThemeBackgroundType.fromPath(legacyPath ?? '');
    if (legacyPath != null && legacyPath.isNotEmpty && legacyType != null) {
      background = AppThemeBackgroundData(
        type: legacyType,
        relativePath: legacyPath,
      );
    }

    return AppCustomThemeData(
      id: 'custom-theme-legacy',
      name: '自定义主题',
      seedColorValue: seedColorValue,
      background: background,
    );
  }

  static String _resolveActiveThemeId(
    String? rawActiveThemeId,
    List<AppCustomThemeData> customThemes,
  ) {
    final candidate = rawActiveThemeId?.trim();
    if (candidate == null || candidate.isEmpty) {
      return defaults.activeThemeId;
    }
    if (AppThemePreset.isBuiltInThemeId(candidate)) {
      return candidate;
    }
    if (candidate == 'custom' && customThemes.isNotEmpty) {
      return customThemes.first.id;
    }
    final customTheme = customThemes.firstWhereOrNull(
      (theme) => theme.id == candidate,
    );
    if (customTheme != null) {
      return customTheme.id;
    }
    return defaults.activeThemeId;
  }
}

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.accent,
    required this.topBarBackground,
    required this.topBarFieldBackground,
    required this.topBarHint,
    required this.windowCloseHover,
    required this.softAccent,
    required this.softAccentText,
  });

  final Color accent;
  final Color topBarBackground;
  final Color topBarFieldBackground;
  final Color topBarHint;
  final Color windowCloseHover;
  final Color softAccent;
  final Color softAccentText;

  @override
  AppThemeColors copyWith({
    Color? accent,
    Color? topBarBackground,
    Color? topBarFieldBackground,
    Color? topBarHint,
    Color? windowCloseHover,
    Color? softAccent,
    Color? softAccentText,
  }) {
    return AppThemeColors(
      accent: accent ?? this.accent,
      topBarBackground: topBarBackground ?? this.topBarBackground,
      topBarFieldBackground:
          topBarFieldBackground ?? this.topBarFieldBackground,
      topBarHint: topBarHint ?? this.topBarHint,
      windowCloseHover: windowCloseHover ?? this.windowCloseHover,
      softAccent: softAccent ?? this.softAccent,
      softAccentText: softAccentText ?? this.softAccentText,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) {
      return this;
    }
    return AppThemeColors(
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      topBarBackground:
          Color.lerp(topBarBackground, other.topBarBackground, t) ??
          topBarBackground,
      topBarFieldBackground:
          Color.lerp(topBarFieldBackground, other.topBarFieldBackground, t) ??
          topBarFieldBackground,
      topBarHint: Color.lerp(topBarHint, other.topBarHint, t) ?? topBarHint,
      windowCloseHover:
          Color.lerp(windowCloseHover, other.windowCloseHover, t) ??
          windowCloseHover,
      softAccent: Color.lerp(softAccent, other.softAccent, t) ?? softAccent,
      softAccentText:
          Color.lerp(softAccentText, other.softAccentText, t) ?? softAccentText,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light(AppThemePreset preset) {
    return _buildTheme(
      brightness: Brightness.light,
      preset: preset,
      surface: const Color(0xFFF5F5F5),
      card: Colors.white,
      border: const Color(0xFFE2E2E2),
      textTheme: Typography.blackCupertino,
    );
  }

  static ThemeData dark(AppThemePreset preset) {
    return _buildTheme(
      brightness: Brightness.dark,
      preset: preset,
      surface: const Color(0xFF17181C),
      card: const Color(0xFF21242A),
      border: const Color(0xFF32363D),
      textTheme: Typography.whiteCupertino,
    );
  }

  static AppThemeColors colorsOf(BuildContext context) {
    return Theme.of(context).extension<AppThemeColors>()!;
  }

  static Color translucentSurface(
    BuildContext context, {
    double lightAlpha = 0.74,
    double darkAlpha = 0.82,
  }) {
    final theme = Theme.of(context);
    return theme.colorScheme.surface.withValues(
      alpha: theme.brightness == Brightness.dark ? darkAlpha : lightAlpha,
    );
  }

  static Color translucentSurfaceVariant(
    BuildContext context, {
    double lightAlpha = 0.86,
    double darkAlpha = 0.9,
  }) {
    final theme = Theme.of(context);
    return theme.colorScheme.surfaceContainerHigh.withValues(
      alpha: theme.brightness == Brightness.dark ? darkAlpha : lightAlpha,
    );
  }

  static Color translucentSelection(
    BuildContext context, {
    double lightAlpha = 0.28,
    double darkAlpha = 0.38,
  }) {
    final theme = Theme.of(context);
    return theme.colorScheme.surfaceContainerHigh.withValues(
      alpha: theme.brightness == Brightness.dark ? darkAlpha : lightAlpha,
    );
  }

  static Color translucentRowStripe(
    BuildContext context, {
    required bool alternate,
    double lightBaseAlpha = 0.14,
    double lightAlternateAlpha = 0.24,
    double darkBaseAlpha = 0.1,
    double darkAlternateAlpha = 0.18,
  }) {
    final theme = Theme.of(context);
    final alpha = switch (theme.brightness) {
      Brightness.light => alternate ? lightAlternateAlpha : lightBaseAlpha,
      Brightness.dark => alternate ? darkAlternateAlpha : darkBaseAlpha,
    };
    return theme.colorScheme.surfaceContainerLow.withValues(alpha: alpha);
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppThemePreset preset,
    required Color surface,
    required Color card,
    required Color border,
    required TextTheme textTheme,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: preset.seedColor,
      brightness: brightness,
      surface: surface,
    );
    final topBarBackground = brightness == Brightness.light
        ? preset.seedColor
        : _mix(preset.seedColor, const Color(0xFF171A1F), 0.22);
    final topBarFieldBackground = brightness == Brightness.light
        ? _mix(preset.seedColor, Colors.black, 0.18)
        : _mix(preset.seedColor, const Color(0xFF11141A), 0.34);
    final topBarHint = brightness == Brightness.light
        ? _mix(preset.seedColor, Colors.white, 0.68)
        : _mix(preset.seedColor, Colors.white, 0.52);
    final softAccent = brightness == Brightness.light
        ? _mix(preset.seedColor, Colors.white, 0.86)
        : _mix(preset.seedColor, const Color(0xFF17181C), 0.62);
    final softAccentText = brightness == Brightness.light
        ? preset.seedColor
        : _mix(preset.seedColor, Colors.white, 0.18);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      splashFactory: NoSplash.splashFactory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: topBarBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF262A31),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: preset.seedColor.withValues(alpha: 0.8),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeColors(
          accent: preset.seedColor,
          topBarBackground: topBarBackground,
          topBarFieldBackground: topBarFieldBackground,
          topBarHint: topBarHint,
          windowCloseHover: const Color(0xFFE2483D),
          softAccent: softAccent,
          softAccentText: softAccentText,
        ),
      ],
    );
  }

  static Color _mix(Color foreground, Color background, double amount) {
    return Color.alphaBlend(foreground.withValues(alpha: amount), background);
  }
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }
}
