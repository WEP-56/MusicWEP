import '../../../core/media/media_models.dart';

enum DownloadTaskStatus { waiting, downloading, completed, failed }

enum DownloadEnqueueResult {
  queued,
  alreadyQueued,
  alreadyDownloaded,
  localTrack,
  missingPlugin,
}

class DownloadSettings {
  const DownloadSettings({
    required this.downloadDirectoryPath,
    this.concurrency = 5,
    this.defaultQuality = 'standard',
    this.whenQualityMissing = 'lower',
  });

  final String downloadDirectoryPath;
  final int concurrency;
  final String defaultQuality;
  final String whenQualityMissing;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'path': downloadDirectoryPath,
      'concurrency': concurrency,
      'defaultQuality': defaultQuality,
      'whenQualityMissing': whenQualityMissing,
    };
  }
}

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.track,
    required this.createdAt,
    required this.updatedAt,
    this.pluginId,
    this.requestedQuality = 'standard',
    this.status = DownloadTaskStatus.waiting,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.filePath,
    this.errorMessage,
  });

  final String id;
  final MusicItem track;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? pluginId;
  final String requestedQuality;
  final DownloadTaskStatus status;
  final int downloadedBytes;
  final int? totalBytes;
  final String? filePath;
  final String? errorMessage;

  String get trackKey => '${track.platform}@${track.id}';
  bool get isCompleted => status == DownloadTaskStatus.completed;
  bool get isActive =>
      status == DownloadTaskStatus.waiting ||
      status == DownloadTaskStatus.downloading;
  bool get isQueueVisible => status != DownloadTaskStatus.completed;

  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return downloadedBytes / total;
  }

  DownloadTask copyWith({
    String? id,
    MusicItem? track,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? pluginId,
    String? requestedQuality,
    DownloadTaskStatus? status,
    int? downloadedBytes,
    int? totalBytes,
    bool clearTotalBytes = false,
    String? filePath,
    bool clearFilePath = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      track: track ?? this.track,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pluginId: pluginId ?? this.pluginId,
      requestedQuality: requestedQuality ?? this.requestedQuality,
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: clearTotalBytes ? null : (totalBytes ?? this.totalBytes),
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id']?.toString() ?? '',
      track: MusicItem.fromJson(
        (json['track'] is Map)
            ? (json['track'] as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              )
            : const <String, dynamic>{},
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      pluginId: json['pluginId']?.toString(),
      requestedQuality: json['requestedQuality']?.toString() ?? 'standard',
      status: DownloadTaskStatus.values.byName(
        json['status']?.toString() ?? DownloadTaskStatus.waiting.name,
      ),
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt(),
      filePath: json['filePath']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'track': track.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'pluginId': pluginId,
      'requestedQuality': requestedQuality,
      'status': status.name,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'filePath': filePath,
      'errorMessage': errorMessage,
    };
  }
}

MusicItem attachDownloadData(
  MusicItem track, {
  required String filePath,
  required String quality,
}) {
  final nested = (track.extra[r'$'] is Map)
      ? (track.extra[r'$'] as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        )
      : <String, dynamic>{};
  nested['downloadData'] = <String, dynamic>{
    'path': filePath,
    'quality': quality,
  };
  return track.mergePatch(
    MusicInfoPatch(extra: <String, dynamic>{...track.extra, r'$': nested}),
  );
}
