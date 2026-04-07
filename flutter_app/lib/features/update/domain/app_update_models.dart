enum AppUpdateStage {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  launchingInstaller,
  error,
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.tagName,
    required this.version,
    required this.assetName,
    required this.downloadUrl,
    required this.releasePageUrl,
  });

  final String tagName;
  final String version;
  final String assetName;
  final String downloadUrl;
  final String releasePageUrl;
}

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.currentVersion,
    required this.stage,
    this.latestVersion,
    this.latestTagName,
    this.progress,
    this.message,
    this.errorDetails,
  });

  final String currentVersion;
  final AppUpdateStage stage;
  final String? latestVersion;
  final String? latestTagName;
  final double? progress;
  final String? message;
  final String? errorDetails;

  bool get isBusy =>
      stage == AppUpdateStage.checking ||
      stage == AppUpdateStage.downloading ||
      stage == AppUpdateStage.launchingInstaller;

  bool get hasUpdate =>
      stage == AppUpdateStage.updateAvailable ||
      stage == AppUpdateStage.downloading ||
      stage == AppUpdateStage.launchingInstaller;

  AppUpdateStatus copyWith({
    String? currentVersion,
    AppUpdateStage? stage,
    String? latestVersion,
    bool clearLatestVersion = false,
    String? latestTagName,
    bool clearLatestTagName = false,
    double? progress,
    bool clearProgress = false,
    String? message,
    bool clearMessage = false,
    String? errorDetails,
    bool clearErrorDetails = false,
  }) {
    return AppUpdateStatus(
      currentVersion: currentVersion ?? this.currentVersion,
      stage: stage ?? this.stage,
      latestVersion: clearLatestVersion
          ? null
          : (latestVersion ?? this.latestVersion),
      latestTagName: clearLatestTagName
          ? null
          : (latestTagName ?? this.latestTagName),
      progress: clearProgress ? null : (progress ?? this.progress),
      message: clearMessage ? null : (message ?? this.message),
      errorDetails: clearErrorDetails
          ? null
          : (errorDetails ?? this.errorDetails),
    );
  }
}
