import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/update/update_service.dart';

String _release(String tag, {bool prerelease = false}) => jsonEncode({
      'tag_name': tag,
      'html_url': 'https://github.com/x/y/releases/tag/$tag',
      'body': 'notes',
      'prerelease': prerelease,
      'assets': [
        {
          'name': 'Nudge-$tag-android.apk',
          'browser_download_url': 'https://dl/apk',
        },
        {
          'name': 'Nudge-$tag-windows-x64.zip',
          'browser_download_url': 'https://dl/zip',
        },
      ],
    });

void main() {
  test('compareVersions', () {
    expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
    expect(compareVersions('v1.10.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0.0+5'), 0);
    expect(compareVersions('1.0', '1.0.0'), 0);
    expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
  });

  GithubUpdateChecker checker(String current, Future<String> Function(Uri) f) =>
      GithubUpdateChecker(currentVersion: () async => current, fetch: f);

  test('newer release is reported with asset url', () async {
    final r = await checker('1.0.0', (_) async => _release('v1.1.0')).check();
    expect(r, isA<UpdateAvailable>());
    final info = (r as UpdateAvailable).info;
    expect(info.version, '1.1.0');
    expect(info.downloadUrl, anyOf('https://dl/apk', 'https://dl/zip'));
  });

  test('same version is up to date', () async {
    final r = await checker('1.1.0', (_) async => _release('v1.1.0')).check();
    expect(r, isA<UpToDate>());
  });

  test('prerelease ignored', () async {
    final r = await checker(
      '1.0.0',
      (_) async => _release('v2.0.0', prerelease: true),
    ).check();
    expect(r, isA<UpToDate>());
  });

  test('network error becomes UpdateFailed', () async {
    final r = await checker('1.0.0', (_) async => throw StateError('x')).check();
    expect(r, isA<UpdateFailed>());
  });
}
