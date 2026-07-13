import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const currentAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.0.3-alpha',
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

/// Checks the GitHub pre-release manifest. The updater is intentionally a
/// separate executable so the running Windows binary can be replaced safely.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isSupported => Platform.isWindows;

  Future<AppUpdate?> checkForUpdate() async {
    if (!isSupported || currentBuildSha.isEmpty) return null;
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
    final buildSha = manifest['build_sha']?.toString() ?? '';
    final packageUrl = manifest['package_url']?.toString() ?? '';
    final sha256 = manifest['sha256']?.toString() ?? '';
    if (buildSha.isEmpty || packageUrl.isEmpty || sha256.isEmpty) return null;
    if (buildSha == currentBuildSha) return null;
    return AppUpdate(
      version: manifest['version']?.toString() ?? currentAppVersion,
      buildSha: buildSha,
      packageUrl: packageUrl,
      sha256: sha256,
    );
  }

  Future<void> install(AppUpdate update) async {
    if (!isSupported) return;
    final executable = File(Platform.resolvedExecutable);
    final targetDirectory = executable.parent;
    final updater = File(p.join(targetDirectory.path, 'sales_crm_updater.exe'));
    if (!await updater.exists()) {
      throw StateError('فایل به‌روزرسانی ویندوز در کنار برنامه پیدا نشد.');
    }
    final buildFolder = update.buildSha.length > 12
        ? update.buildSha.substring(0, 12)
        : update.buildSha;
    final launcherDirectory = Directory(
      p.join(Directory.systemTemp.path, 'SalesCrmUpdaterLauncher', buildFolder),
    );
    await launcherDirectory.create(recursive: true);
    final launcher = File(
      p.join(launcherDirectory.path, updater.uri.pathSegments.last),
    );
    await updater.copy(launcher.path);
    await Process.start(launcher.path, [
      '--pid',
      pid.toString(),
      '--url',
      update.packageUrl,
      '--sha256',
      update.sha256,
      '--target',
      targetDirectory.path,
      '--relaunch',
      executable.path,
    ], mode: ProcessStartMode.detached);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    exit(0);
  }
}
