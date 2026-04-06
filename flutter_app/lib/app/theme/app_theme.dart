import 'dart:ui';

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
    return values.where((item) => item.id == id).firstOrNull ?? sunset;
  }
}

class AppThemeSettings {
  const AppThemeSettings({required this.mode, required this.presetId});

  final ThemeMode mode;
  final String presetId;

  static const AppThemeSettings defaults = AppThemeSettings(
    mode: ThemeMode.light,
    presetId: 'sunset',
  );

  AppThemePreset get preset => AppThemePreset.fromId(presetId);

  AppThemeSettings copyWith({ThemeMode? mode, String? presetId}) {
    return AppThemeSettings(
      mode: mode ?? this.mode,
      presetId: presetId ?? this.presetId,
    );
  }

  factory AppThemeSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return defaults;
    }
    return AppThemeSettings(
      mode: switch (json['mode']?.toString()) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
      presetId: AppThemePreset.fromId(json['presetId']?.toString()).id,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
      },
      'presetId': preset.id,
    };
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

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
