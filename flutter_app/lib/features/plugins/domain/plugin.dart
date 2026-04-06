class PluginUserVariableDefinition {
  const PluginUserVariableDefinition({required this.key, this.name, this.hint});

  final String key;
  final String? name;
  final String? hint;

  factory PluginUserVariableDefinition.fromJson(Map<String, dynamic> json) {
    return PluginUserVariableDefinition(
      key: json['key'] as String? ?? '',
      name: json['name'] as String?,
      hint: json['hint'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'key': key, 'name': name, 'hint': hint};
  }
}

enum PluginParseStatus { mounted, warning, error }

class PluginDiagnostics {
  const PluginDiagnostics({
    required this.status,
    required this.checkedAt,
    this.message,
    this.stackTrace,
    this.logs = const <String>[],
    this.requiredPackages = const <String>[],
    this.missingPackages = const <String>[],
  });

  final PluginParseStatus status;
  final DateTime checkedAt;
  final String? message;
  final String? stackTrace;
  final List<String> logs;
  final List<String> requiredPackages;
  final List<String> missingPackages;

  factory PluginDiagnostics.fromJson(Map<String, dynamic> json) {
    return PluginDiagnostics(
      status: PluginParseStatus.values.byName(
        json['status'] as String? ?? PluginParseStatus.error.name,
      ),
      checkedAt:
          DateTime.tryParse(json['checkedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      message: json['message'] as String?,
      stackTrace: json['stackTrace'] as String?,
      logs: (json['logs'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toList(growable: false),
      requiredPackages:
          (json['requiredPackages'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false),
      missingPackages:
          (json['missingPackages'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'checkedAt': checkedAt.toIso8601String(),
      'message': message,
      'stackTrace': stackTrace,
      'logs': logs,
      'requiredPackages': requiredPackages,
      'missingPackages': missingPackages,
    };
  }
}

class PluginManifest {
  const PluginManifest({
    required this.platform,
    this.version,
    this.appVersion,
    this.author,
    this.description,
    this.sourceUrl,
    this.supportedMethods = const <String>[],
    this.supportedSearchTypes = const <String>[],
    this.userVariables = const <PluginUserVariableDefinition>[],
  });

  final String platform;
  final String? version;
  final String? appVersion;
  final String? author;
  final String? description;
  final String? sourceUrl;
  final List<String> supportedMethods;
  final List<String> supportedSearchTypes;
  final List<PluginUserVariableDefinition> userVariables;

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
      platform: json['platform'] as String? ?? '',
      version: json['version'] as String?,
      appVersion: json['appVersion'] as String?,
      author: json['author'] as String?,
      description: json['description'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      supportedMethods:
          (json['supportedMethods'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString())
              .toList(growable: false),
      supportedSearchTypes:
          (json['supportedSearchTypes'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString())
              .toList(growable: false),
      userVariables:
          (json['userVariables'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(PluginUserVariableDefinition.fromJson)
              .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'version': version,
      'appVersion': appVersion,
      'author': author,
      'description': description,
      'sourceUrl': sourceUrl,
      'supportedMethods': supportedMethods,
      'supportedSearchTypes': supportedSearchTypes,
      'userVariables': userVariables.map((entry) => entry.toJson()).toList(),
    };
  }
}

class PluginMetaRecord {
  const PluginMetaRecord({
    required this.enabled,
    required this.order,
    this.sourceUrl,
    this.installedVersion,
    this.lastUpdateMessage,
    this.lastUpdatedAt,
    this.diagnostics,
  });

  factory PluginMetaRecord.initial() {
    return PluginMetaRecord(
      enabled: true,
      order: 0,
      diagnostics: PluginDiagnostics(
        status: PluginParseStatus.warning,
        checkedAt: DateTime.now(),
        message: 'Waiting for plugin inspection.',
      ),
    );
  }

  final bool enabled;
  final int order;
  final String? sourceUrl;
  final String? installedVersion;
  final String? lastUpdateMessage;
  final DateTime? lastUpdatedAt;
  final PluginDiagnostics? diagnostics;

  PluginMetaRecord copyWith({
    bool? enabled,
    int? order,
    String? sourceUrl,
    String? installedVersion,
    String? lastUpdateMessage,
    DateTime? lastUpdatedAt,
    PluginDiagnostics? diagnostics,
  }) {
    return PluginMetaRecord(
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      installedVersion: installedVersion ?? this.installedVersion,
      lastUpdateMessage: lastUpdateMessage ?? this.lastUpdateMessage,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      diagnostics: diagnostics ?? this.diagnostics,
    );
  }

  factory PluginMetaRecord.fromJson(Map<String, dynamic> json) {
    return PluginMetaRecord(
      enabled: json['enabled'] as bool? ?? true,
      order: json['order'] as int? ?? 0,
      sourceUrl: json['sourceUrl'] as String?,
      installedVersion: json['installedVersion'] as String?,
      lastUpdateMessage: json['lastUpdateMessage'] as String?,
      lastUpdatedAt: DateTime.tryParse(json['lastUpdatedAt'] as String? ?? ''),
      diagnostics: json['diagnostics'] is Map<String, dynamic>
          ? PluginDiagnostics.fromJson(
              json['diagnostics'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'order': order,
      'sourceUrl': sourceUrl,
      'installedVersion': installedVersion,
      'lastUpdateMessage': lastUpdateMessage,
      'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
      'diagnostics': diagnostics?.toJson(),
    };
  }
}

class PluginRecord {
  const PluginRecord({
    required this.filePath,
    required this.fileName,
    required this.hash,
    required this.meta,
    this.manifest,
  });

  final String filePath;
  final String fileName;
  final String hash;
  final PluginManifest? manifest;
  final PluginMetaRecord meta;

  String get storageKey =>
      manifest?.platform.isNotEmpty == true ? manifest!.platform : 'hash:$hash';

  String get displayName =>
      manifest?.platform.isNotEmpty == true ? manifest!.platform : fileName;

  String? get version => manifest?.version ?? meta.installedVersion;

  String? get sourceUrl => manifest?.sourceUrl ?? meta.sourceUrl;

  PluginDiagnostics? get diagnostics => meta.diagnostics;
}

class PluginSubscription {
  const PluginSubscription({
    required this.name,
    required this.url,
    this.lastRefreshedAt,
    this.lastRefreshMessage,
    this.lastRefreshSucceeded,
    this.installedPluginCount,
  });

  final String name;
  final String url;
  final DateTime? lastRefreshedAt;
  final String? lastRefreshMessage;
  final bool? lastRefreshSucceeded;
  final int? installedPluginCount;

  PluginSubscription copyWith({
    String? name,
    String? url,
    DateTime? lastRefreshedAt,
    String? lastRefreshMessage,
    bool? lastRefreshSucceeded,
    int? installedPluginCount,
  }) {
    return PluginSubscription(
      name: name ?? this.name,
      url: url ?? this.url,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
      lastRefreshMessage: lastRefreshMessage ?? this.lastRefreshMessage,
      lastRefreshSucceeded: lastRefreshSucceeded ?? this.lastRefreshSucceeded,
      installedPluginCount: installedPluginCount ?? this.installedPluginCount,
    );
  }

  factory PluginSubscription.fromJson(Map<String, dynamic> json) {
    return PluginSubscription(
      name: json['name'] as String? ?? 'Default',
      url: json['url'] as String? ?? '',
      lastRefreshedAt: DateTime.tryParse(
        json['lastRefreshedAt'] as String? ?? '',
      ),
      lastRefreshMessage: json['lastRefreshMessage'] as String?,
      lastRefreshSucceeded: json['lastRefreshSucceeded'] as bool?,
      installedPluginCount: json['installedPluginCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'lastRefreshedAt': lastRefreshedAt?.toIso8601String(),
      'lastRefreshMessage': lastRefreshMessage,
      'lastRefreshSucceeded': lastRefreshSucceeded,
      'installedPluginCount': installedPluginCount,
    };
  }
}
