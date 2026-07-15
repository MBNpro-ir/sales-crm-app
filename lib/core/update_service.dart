import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const currentAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'development',
);
const currentBuildSha = String.fromEnvironment('BUILD_SHA', defaultValue: '');
const updateRepository = String.fromEnvironment(
  'UPDATE_REPOSITORY',
  defaultValue: 'MBNpro-ir/sales-crm-app',
);

class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.buildSha,
    required this.packageUrl,
    required this.sha256,
  });

  final String version;
  final String buildSha;
  final String packageUrl;
  final String sha256;
}

class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    this.verifying = false,
  });

  const UpdateDownloadProgress.initial()
    : receivedBytes = 0,
      totalBytes = 0,
      verifying = false;

  final int receivedBytes;
  final int totalBytes;
  final bool verifying;

  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;
}

AppUpdate? parseAppUpdateManifest(
  Map<String, dynamic> manifest, {
  required String runningBuildSha,
  String runningVersion = currentAppVersion,
}) {
  final buildSha = manifest['build_sha']?.toString() ?? '';
  final packageUrl = manifest['package_url']?.toString() ?? '';
  final expectedHash = manifest['sha256']?.toString().toLowerCase() ?? '';
  final candidateVersion = manifest['version']?.toString() ?? runningVersion;
  if (buildSha.isEmpty ||
      packageUrl.isEmpty ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash) ||
      buildSha == runningBuildSha ||
      !_isNewerVersion(candidateVersion, runningVersion)) {
    return null;
  }
  return AppUpdate(
    version: candidateVersion,
    buildSha: buildSha,
    packageUrl: packageUrl,
    sha256: expectedHash,
  );
}

bool _isNewerVersion(String candidate, String running) {
  List<int>? parts(String value) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$').firstMatch(value);
    if (match == null) return null;
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
  }

  final candidateParts = parts(candidate);
  final runningParts = parts(running);
  if (candidateParts == null || runningParts == null) return true;
  for (var index = 0; index < candidateParts.length; index++) {
    if (candidateParts[index] != runningParts[index]) {
      return candidateParts[index] > runningParts[index];
    }
  }
  return false;
}

/// The CRM downloads and verifies the release package itself. A tiny bundled
/// PowerShell launcher only waits for this process to exit, swaps files, and
/// relaunches the application; it never performs network access.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isSupported => Platform.isWindows;

  Future<AppUpdate?> checkForUpdate() async {
    if (!isSupported) return null;
    await _removeLegacyUpdater();
    if (currentBuildSha.isEmpty) return null;
    final releaseUrl = Uri.parse(
      'https://api.github.com/repos/$updateRepository/releases?per_page=20',
    );
    final release = await _client.get(
      releaseUrl,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'sales-crm-windows-updater',
      },
    );
    if (release.statusCode != HttpStatus.ok) return null;
    final releases = List<Map<String, dynamic>>.from(
      (jsonDecode(release.body) as List).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final body = releases.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['prerelease'] == true && item?['draft'] != true,
      orElse: () => null,
    );
    if (body == null) return null;
    final assets = List<Map<String, dynamic>>.from(
      (body['assets'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final manifestAsset = assets.cast<Map<String, dynamic>?>().firstWhere(
      (asset) => asset?['name'] == 'sales-crm-update.json',
      orElse: () => null,
    );
    final manifestUrl = manifestAsset?['browser_download_url']?.toString();
    if (manifestUrl == null || manifestUrl.isEmpty) return null;
    final manifestResponse = await _client.get(
      Uri.parse(manifestUrl),
      headers: const {'User-Agent': 'sales-crm-windows-updater'},
    );
    if (manifestResponse.statusCode != HttpStatus.ok) return null;
    final manifest = Map<String, dynamic>.from(
      jsonDecode(manifestResponse.body) as Map,
    );
    return parseAppUpdateManifest(manifest, runningBuildSha: currentBuildSha);
  }

  Future<void> downloadAndInstall(
    AppUpdate update, {
    required void Function(UpdateDownloadProgress progress) onProgress,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('به‌روزرسانی خودکار فقط در ویندوز فعال است.');
    }
    final executable = File(Platform.resolvedExecutable);
    final targetDirectory = executable.parent;
    final updater = File(p.join(targetDirectory.path, 'sales_crm_updater.ps1'));
    if (!await updater.exists()) {
      throw StateError('راه‌انداز سبک به‌روزرسانی کنار برنامه پیدا نشد.');
    }

    final buildFolder = update.buildSha.length > 12
        ? update.buildSha.substring(0, 12)
        : update.buildSha;
    final workDirectory = Directory(
      p.join(Directory.systemTemp.path, 'SalesCrmUpdate', buildFolder),
    );
    await workDirectory.create(recursive: true);
    final partialPackage = File(p.join(workDirectory.path, 'package.zip.part'));
    final package = File(p.join(workDirectory.path, 'package.zip'));
    if (await partialPackage.exists()) await partialPackage.delete();
    if (await package.exists()) await package.delete();

    final request = http.Request('GET', Uri.parse(update.packageUrl))
      ..headers['User-Agent'] = 'sales-crm-windows-updater';
    final response = await _client.send(request);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'دریافت بسته با خطای ${response.statusCode} متوقف شد.',
        uri: Uri.parse(update.packageUrl),
      );
    }
    final totalBytes = response.contentLength ?? 0;
    var receivedBytes = 0;
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
    final sink = partialPackage.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastProgressAt) >=
                const Duration(milliseconds: 80) ||
            (totalBytes > 0 && receivedBytes >= totalBytes)) {
          lastProgressAt = now;
          onProgress(
            UpdateDownloadProgress(
              receivedBytes: receivedBytes,
              totalBytes: totalBytes,
            ),
          );
        }
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await partialPackage.exists()) await partialPackage.delete();
      rethrow;
    }
    await sink.close();
    if (totalBytes > 0 && receivedBytes != totalBytes) {
      await partialPackage.delete();
      throw const HttpException('بستهٔ به‌روزرسانی ناقص دریافت شد.');
    }

    onProgress(
      UpdateDownloadProgress(
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
        verifying: true,
      ),
    );
    final digest = await sha256.bind(partialPackage.openRead()).first;
    if (digest.toString().toLowerCase() != update.sha256.toLowerCase()) {
      await partialPackage.delete();
      throw const FileSystemException(
        'صحت SHA-256 بسته تأیید نشد؛ نصب انجام نشد.',
      );
    }
    await partialPackage.rename(package.path);

    final launcher = File(p.join(workDirectory.path, 'sales_crm_updater.ps1'));
    if (await launcher.exists()) await launcher.delete();
    await updater.copy(launcher.path);
    await Process.start('powershell.exe', [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      launcher.path,
      '-ProcessId',
      pid.toString(),
      '-Package',
      package.path,
      '-Target',
      targetDirectory.path,
      '-Relaunch',
      executable.path,
    ], mode: ProcessStartMode.detached);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    exit(0);
  }

  Future<void> _removeLegacyUpdater() async {
    final legacy = File(
      p.join(
        File(Platform.resolvedExecutable).parent.path,
        'sales_crm_updater.exe',
      ),
    );
    try {
      if (await legacy.exists()) await legacy.delete();
    } on FileSystemException {
      // A locked legacy file is harmless and can be removed by the launcher.
    }
  }
}
