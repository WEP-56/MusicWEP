import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_environment.dart';

final appEnvironmentProvider = FutureProvider<AppEnvironment>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return AppEnvironment.fromPackageInfo(
    packageInfo: packageInfo,
    languageTag: Platform.localeName.replaceAll('_', '-'),
  );
});
