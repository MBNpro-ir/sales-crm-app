import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release version has one canonical value and workflow derives the rest', () {
    final metadata = Map<String, dynamic>.from(
      jsonDecode(File('release-version.json').readAsStringSync()) as Map,
    );
    final version = metadata['version']?.toString() ?? '';

    expect(metadata.keys, ['version']);
    expect(version, matches(RegExp(r'^\d+\.\d+\.\d+-alpha$')));
    expect(
      File('.github/workflows/prerelease.yml').readAsStringSync(),
      isNot(contains(version)),
      reason: 'The workflow must derive metadata instead of repeating the version.',
    );
  });
}
