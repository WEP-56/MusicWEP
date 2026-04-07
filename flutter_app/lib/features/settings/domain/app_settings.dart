class AppSettings {
  const AppSettings({
    this.normal = const NormalSettings(),
    this.playMusic = const PlayMusicSettings(),
    this.download = const DownloadSectionSettings(),
    this.lyric = const LyricSettings(),
    this.plugin = const PluginSettings(),
    this.cache = const CacheSettings(),
  });

  final NormalSettings normal;
  final PlayMusicSettings playMusic;
  final DownloadSectionSettings download;
  final LyricSettings lyric;
  final PluginSettings plugin;
  final CacheSettings cache;

  static const AppSettings defaults = AppSettings();

  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    final raw = json ?? const <String, dynamic>{};
    return AppSettings(
      normal: NormalSettings.fromJson(_readMap(raw['normal'])),
      playMusic: PlayMusicSettings.fromJson(_readMap(raw['playMusic'])),
      download: DownloadSectionSettings.fromJson(_readMap(raw['download'])),
      lyric: LyricSettings.fromJson(_readMap(raw['lyric'])),
      plugin: PluginSettings.fromJson(_readMap(raw['plugin'])),
      cache: CacheSettings.fromJson(_readMap(raw['cache'])),
    );
  }

  AppSettings copyWith({
    NormalSettings? normal,
    PlayMusicSettings? playMusic,
    DownloadSectionSettings? download,
    LyricSettings? lyric,
    PluginSettings? plugin,
    CacheSettings? cache,
  }) {
    return AppSettings(
      normal: normal ?? this.normal,
      playMusic: playMusic ?? this.playMusic,
      download: download ?? this.download,
      lyric: lyric ?? this.lyric,
      plugin: plugin ?? this.plugin,
      cache: cache ?? this.cache,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'normal': normal.toJson(),
      'playMusic': playMusic.toJson(),
      'download': download.toJson(),
      'lyric': lyric.toJson(),
      'plugin': plugin.toJson(),
      'cache': cache.toJson(),
    };
  }
}

class NormalSettings {
  const NormalSettings({
    this.closeBehavior = 'tray',
    this.checkUpdate = true,
    this.autoLoadMore = true,
  });

  final String closeBehavior;
  final bool checkUpdate;
  final bool autoLoadMore;

  factory NormalSettings.fromJson(Map<String, dynamic> json) {
    return NormalSettings(
      closeBehavior: switch (json['closeBehavior']?.toString()) {
        'exit_app' => 'exit_app',
        'tray' => 'tray',
        _ => 'minimize',
      },
      checkUpdate: json['checkUpdate'] as bool? ?? true,
      autoLoadMore: json['autoLoadMore'] as bool? ?? true,
    );
  }

  NormalSettings copyWith({
    String? closeBehavior,
    bool? checkUpdate,
    bool? autoLoadMore,
  }) {
    return NormalSettings(
      closeBehavior: closeBehavior ?? this.closeBehavior,
      checkUpdate: checkUpdate ?? this.checkUpdate,
      autoLoadMore: autoLoadMore ?? this.autoLoadMore,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'closeBehavior': closeBehavior,
      'checkUpdate': checkUpdate,
      'autoLoadMore': autoLoadMore,
    };
  }
}

class PlayMusicSettings {
  const PlayMusicSettings({
    this.caseSensitiveInSearch = false,
    this.defaultQuality = 'standard',
    this.whenQualityMissing = 'lower',
    this.clickMusicList = 'replace',
    this.playError = 'skip',
  });

  final bool caseSensitiveInSearch;
  final String defaultQuality;
  final String whenQualityMissing;
  final String clickMusicList;
  final String playError;

  factory PlayMusicSettings.fromJson(Map<String, dynamic> json) {
    return PlayMusicSettings(
      caseSensitiveInSearch: json['caseSensitiveInSearch'] as bool? ?? false,
      defaultQuality: switch (json['defaultQuality']?.toString()) {
        'low' => 'low',
        'high' => 'high',
        'super' => 'super',
        _ => 'standard',
      },
      whenQualityMissing: switch (json['whenQualityMissing']?.toString()) {
        'higher' => 'higher',
        'skip' => 'skip',
        _ => 'lower',
      },
      clickMusicList: switch (json['clickMusicList']?.toString()) {
        'normal' => 'normal',
        _ => 'replace',
      },
      playError: switch (json['playError']?.toString()) {
        'pause' => 'pause',
        _ => 'skip',
      },
    );
  }

  PlayMusicSettings copyWith({
    bool? caseSensitiveInSearch,
    String? defaultQuality,
    String? whenQualityMissing,
    String? clickMusicList,
    String? playError,
  }) {
    return PlayMusicSettings(
      caseSensitiveInSearch:
          caseSensitiveInSearch ?? this.caseSensitiveInSearch,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      whenQualityMissing: whenQualityMissing ?? this.whenQualityMissing,
      clickMusicList: clickMusicList ?? this.clickMusicList,
      playError: playError ?? this.playError,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'caseSensitiveInSearch': caseSensitiveInSearch,
      'defaultQuality': defaultQuality,
      'whenQualityMissing': whenQualityMissing,
      'clickMusicList': clickMusicList,
      'playError': playError,
    };
  }
}

class DownloadSectionSettings {
  const DownloadSectionSettings({
    this.path,
    this.concurrency = 5,
    this.defaultQuality = 'standard',
    this.whenQualityMissing = 'lower',
  });

  final String? path;
  final int concurrency;
  final String defaultQuality;
  final String whenQualityMissing;

  factory DownloadSectionSettings.fromJson(Map<String, dynamic> json) {
    return DownloadSectionSettings(
      path: json['path']?.toString(),
      concurrency: (json['concurrency'] as num?)?.toInt() ?? 5,
      defaultQuality: switch (json['defaultQuality']?.toString()) {
        'low' => 'low',
        'high' => 'high',
        'super' => 'super',
        _ => 'standard',
      },
      whenQualityMissing: switch (json['whenQualityMissing']?.toString()) {
        'higher' => 'higher',
        'skip' => 'skip',
        _ => 'lower',
      },
    );
  }

  DownloadSectionSettings copyWith({
    String? path,
    bool clearPath = false,
    int? concurrency,
    String? defaultQuality,
    String? whenQualityMissing,
  }) {
    return DownloadSectionSettings(
      path: clearPath ? null : (path ?? this.path),
      concurrency: concurrency ?? this.concurrency,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      whenQualityMissing: whenQualityMissing ?? this.whenQualityMissing,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (path?.trim().isNotEmpty == true) 'path': path,
      'concurrency': concurrency,
      'defaultQuality': defaultQuality,
      'whenQualityMissing': whenQualityMissing,
    };
  }
}

class LyricSettings {
  const LyricSettings({
    this.enableDesktopLyric = false,
    this.lockLyric = false,
  });

  final bool enableDesktopLyric;
  final bool lockLyric;

  factory LyricSettings.fromJson(Map<String, dynamic> json) {
    return LyricSettings(
      enableDesktopLyric: json['enableDesktopLyric'] as bool? ?? false,
      lockLyric: json['lockLyric'] as bool? ?? false,
    );
  }

  LyricSettings copyWith({bool? enableDesktopLyric, bool? lockLyric}) {
    return LyricSettings(
      enableDesktopLyric: enableDesktopLyric ?? this.enableDesktopLyric,
      lockLyric: lockLyric ?? this.lockLyric,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enableDesktopLyric': enableDesktopLyric,
      'lockLyric': lockLyric,
    };
  }
}

class PluginSettings {
  const PluginSettings({
    this.autoUpdatePlugin = false,
    this.notCheckPluginVersion = false,
  });

  final bool autoUpdatePlugin;
  final bool notCheckPluginVersion;

  factory PluginSettings.fromJson(Map<String, dynamic> json) {
    return PluginSettings(
      autoUpdatePlugin: json['autoUpdatePlugin'] as bool? ?? false,
      notCheckPluginVersion: json['notCheckPluginVersion'] as bool? ?? false,
    );
  }

  PluginSettings copyWith({
    bool? autoUpdatePlugin,
    bool? notCheckPluginVersion,
  }) {
    return PluginSettings(
      autoUpdatePlugin: autoUpdatePlugin ?? this.autoUpdatePlugin,
      notCheckPluginVersion:
          notCheckPluginVersion ?? this.notCheckPluginVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'autoUpdatePlugin': autoUpdatePlugin,
      'notCheckPluginVersion': notCheckPluginVersion,
    };
  }
}

class CacheSettings {
  const CacheSettings({this.maxSizeMb = 512});

  final int maxSizeMb;

  factory CacheSettings.fromJson(Map<String, dynamic> json) {
    final rawValue = (json['maxSizeMb'] as num?)?.toInt() ?? 512;
    return CacheSettings(maxSizeMb: rawValue.clamp(64, 8192));
  }

  CacheSettings copyWith({int? maxSizeMb}) {
    return CacheSettings(
      maxSizeMb: (maxSizeMb ?? this.maxSizeMb).clamp(64, 8192),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'maxSizeMb': maxSizeMb};
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return const <String, dynamic>{};
}
