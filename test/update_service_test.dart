import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sales_crm/core/update_service.dart';

void main() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('valid update manifest is accepted and normalized', () {
    final update = parseAppUpdateManifest(
      {
        'version': '0.0.7-alpha',
        'build_sha': 'new-build',
        'package_url': 'https://example.test/sales-crm.zip',
        'sha256': hash.toUpperCase(),
      },
      runningBuildSha: 'old-build',
      runningVersion: '0.0.6-alpha',
    );

    expect(update, isNotNull);
    expect(update!.version, '0.0.7-alpha');
    expect(update.sha256, hash);
  });

  test('current build and invalid hashes are rejected', () {
    expect(
      parseAppUpdateManifest({
        'build_sha': 'same-build',
        'package_url': 'https://example.test/sales-crm.zip',
        'sha256': hash,
      }, runningBuildSha: 'same-build'),
      isNull,
    );
    expect(
      parseAppUpdateManifest({
        'build_sha': 'new-build',
        'package_url': 'https://example.test/sales-crm.zip',
        'sha256': 'not-a-sha256',
      }, runningBuildSha: 'old-build'),
      isNull,
    );
  });

  test('older and same semantic versions never trigger a downgrade', () {
    for (final version in ['0.0.6-alpha', '0.0.7-alpha']) {
      expect(
        parseAppUpdateManifest(
          {
            'version': version,
            'build_sha': 'another-build',
            'package_url': 'https://example.test/sales-crm.zip',
            'sha256': hash,
          },
          runningBuildSha: 'current-build',
          runningVersion: '0.0.7-alpha',
        ),
        isNull,
      );
    }
  });

  test('download progress exposes a bounded fraction', () {
    const progress = UpdateDownloadProgress(receivedBytes: 75, totalBytes: 100);
    const unknown = UpdateDownloadProgress(receivedBytes: 20, totalBytes: 0);

    expect(progress.fraction, 0.75);
    expect(unknown.fraction, isNull);
  });

  test(
    'lightweight updater replaces files and removes legacy executable',
    () async {
      if (!Platform.isWindows) return;
      final root = await Directory.systemTemp.createTemp('crm-updater-test-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final source = Directory('${root.path}\\source')..createSync();
      final target = Directory('${root.path}\\target')..createSync();
      final package = File('${root.path}\\package.zip');
      File('${source.path}\\new-version.txt').writeAsStringSync('updated');
      File('${target.path}\\sales_crm_updater.exe').writeAsStringSync('legacy');

      final archive = await Process.run('powershell.exe', [
        '-NoProfile',
        '-Command',
        'Compress-Archive -Path ${source.path}\\* -DestinationPath ${package.path} -Force',
      ]);
      expect(archive.exitCode, 0, reason: archive.stderr.toString());

      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        File('updater/sales_crm_updater.ps1').absolute.path,
        '-ProcessId',
        '2147483647',
        '-Package',
        package.path,
        '-Target',
        target.path,
        '-Relaunch',
        Platform.resolvedExecutable,
        '-NoRelaunch',
      ]);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        File('${target.path}\\new-version.txt').readAsStringSync(),
        'updated',
      );
      expect(
        File('${target.path}\\sales_crm_updater.exe').existsSync(),
        isFalse,
      );
    },
  );
}
