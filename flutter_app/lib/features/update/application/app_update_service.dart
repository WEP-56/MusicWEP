import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

import '../../../core/filesystem/app_paths.dart';
import '../domain/app_update_models.dart';

typedef AppUpdateProgressCallback =
    void Function(int receivedBytes, int? totalBytes);

class AppUpdateService {
  AppUpdateService({required AppPaths appPaths, http.Client? client})
    : _appPaths = appPaths,
      _client = client ?? http.Client();

  static final Uri _latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/WEP-56/MusicWEP/releases/latest',
  );

  final AppPaths _appPaths;
  final http.Client _client;

  Future<AppUpdateRelease?> fetchLatestRelease({
    required String currentVersion,
  }) async {
    final response = await _client.get(
      _latestReleaseUri,
      headers: const <String, String>{
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'MusicWEP-Updater',
      },
    );

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'GitHub Releases 请求失败: ${response.statusCode}',
        uri: _latestReleaseUri,
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('GitHub Releases 返回格式不正确');
    }

    final tagName = body['tag_name']?.toString() ?? '';
    final latestVersion = normalizeVersion(tagName);
    final localVersion = normalizeVersion(currentVersion);

    if (latestVersion <= localVersion) {
      return null;
    }

    final asset = _selectInstallerAsset(body['assets']);
    if (asset == null) {
      throw StateError('最新 Release 未找到可用的 Windows 安装包');
    }

    return AppUpdateRelease(
      tagName: tagName,
      version: latestVersion.toString(),
      assetName: asset.name,
      downloadUrl: asset.downloadUrl,
      releasePageUrl: body['html_url']?.toString() ?? '',
    );
  }

  Future<String> downloadInstaller(
    AppUpdateRelease release, {
    required AppUpdateProgressCallback onProgress,
  }) async {
    final updatesDirectory = Directory(
      path.join(_appPaths.cacheDirectory.path, 'updates'),
    );
    if (!await updatesDirectory.exists()) {
      await updatesDirectory.create(recursive: true);
    }

    final targetPath = path.join(updatesDirectory.path, release.assetName);
    final partialPath = '$targetPath.partial';
    final partialFile = File(partialPath);
    final targetFile = File(targetPath);

    if (await partialFile.exists()) {
      await partialFile.delete();
    }
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    final request = http.Request('GET', Uri.parse(release.downloadUrl))
      ..headers.addAll(const <String, String>{
        'Accept': 'application/octet-stream',
        'User-Agent': 'MusicWEP-Updater',
      });
    final response = await _client.send(request);

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        '安装包下载失败: ${response.statusCode}',
        uri: Uri.parse(release.downloadUrl),
      );
    }

    final sink = partialFile.openWrite();
    var receivedBytes = 0;
    final contentLength = response.contentLength;
    final totalBytes = contentLength != null && contentLength > 0
        ? contentLength
        : null;

    try {
      await for (final chunk in response.stream) {
        receivedBytes += chunk.length;
        sink.add(chunk);
        onProgress(receivedBytes, totalBytes);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    await partialFile.rename(targetPath);
    onProgress(receivedBytes, totalBytes ?? receivedBytes);
    return targetPath;
  }

  Future<void> launchInstallerAfterExit({
    required String installerPath,
    required int currentProcessId,
  }) async {
    final scriptDirectory = Directory(
      path.join(_appPaths.cacheDirectory.path, 'updates'),
    );
    if (!await scriptDirectory.exists()) {
      await scriptDirectory.create(recursive: true);
    }

    final scriptFile = File(
      path.join(scriptDirectory.path, 'launch_musicwep_update.ps1'),
    );
    final escapedInstallerPath = installerPath.replaceAll("'", "''");
    final script =
        '''
\$installerPath = '$escapedInstallerPath'
\$targetPid = $currentProcessId

for (\$i = 0; \$i -lt 2400; \$i++) {
  if (-not (Get-Process -Id \$targetPid -ErrorAction SilentlyContinue)) {
    break
  }
  Start-Sleep -Milliseconds 250
}

Start-Process -FilePath \$installerPath
''';
    await scriptFile.writeAsString(script, flush: true);

    await Process.start('powershell.exe', <String>[
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      scriptFile.path,
    ], mode: ProcessStartMode.detached);
  }

  void dispose() {
    _client.close();
  }
}

Version normalizeVersion(String rawVersion) {
  final normalized = rawVersion.trim().replaceFirst(RegExp(r'^[vV]\s*'), '');
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(normalized);
  if (match == null) {
    throw FormatException('无法解析版本号: $rawVersion');
  }
  return Version.parse(match.group(0)!);
}

String formatVersionLabel(String version) => 'v $version';

_ReleaseAsset? _selectInstallerAsset(Object? rawAssets) {
  if (rawAssets is! List) {
    return null;
  }

  _ReleaseAsset? bestMatch;
  var bestScore = -1;

  for (final entry in rawAssets) {
    if (entry is! Map) {
      continue;
    }
    final name = entry['name']?.toString() ?? '';
    final downloadUrl = entry['browser_download_url']?.toString() ?? '';
    if (name.isEmpty || downloadUrl.isEmpty) {
      continue;
    }
    final lowerName = name.toLowerCase();
    if (!lowerName.endsWith('.exe')) {
      continue;
    }

    var score = 1;
    if (lowerName.contains('setup')) {
      score += 4;
    }
    if (lowerName.contains('musicwep')) {
      score += 2;
    }

    if (score > bestScore) {
      bestScore = score;
      bestMatch = _ReleaseAsset(name: name, downloadUrl: downloadUrl);
    }
  }

  return bestMatch;
}

class _ReleaseAsset {
  const _ReleaseAsset({required this.name, required this.downloadUrl});

  final String name;
  final String downloadUrl;
}
