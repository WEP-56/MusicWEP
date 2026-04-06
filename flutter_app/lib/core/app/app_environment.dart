import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

enum AppTargetPlatform {
  windows('windows'),
  android('android'),
  macos('macos'),
  linux('linux'),
  ios('ios');

  const AppTargetPlatform(this.runtimeOs);

  final String runtimeOs;
}

class AppEnvironment {
  const AppEnvironment({
    required this.platform,
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
    required this.languageTag,
  });

  final AppTargetPlatform platform;
  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;
  final String languageTag;

  bool get isDesktop =>
      platform == AppTargetPlatform.windows ||
      platform == AppTargetPlatform.macos ||
      platform == AppTargetPlatform.linux;

  bool get isMobile =>
      platform == AppTargetPlatform.android ||
      platform == AppTargetPlatform.ios;

  String get runtimeOs => platform.runtimeOs;

  factory AppEnvironment.fromPackageInfo({
    required PackageInfo packageInfo,
    required String languageTag,
  }) {
    return AppEnvironment(
      platform: _detectPlatform(),
      appName: packageInfo.appName,
      packageName: packageInfo.packageName,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      languageTag: languageTag,
    );
  }

  static AppTargetPlatform _detectPlatform() {
    if (Platform.isWindows) {
      return AppTargetPlatform.windows;
    }
    if (Platform.isAndroid) {
      return AppTargetPlatform.android;
    }
    if (Platform.isMacOS) {
      return AppTargetPlatform.macos;
    }
    if (Platform.isLinux) {
      return AppTargetPlatform.linux;
    }
    if (Platform.isIOS) {
      return AppTargetPlatform.ios;
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}
