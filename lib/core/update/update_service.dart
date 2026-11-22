import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// A newer release found on GitHub.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    required this.downloadUrl,
  });

  /// Version without the leading "v", e.g. `1.2.0`.
  final String version;
  final String notes;

  /// The GitHub release page.
  final String pageUrl;

  /// Direct link to the asset for this platform (APK / Windows zip), or the
  /// release page when the release has no matching asset.
  final String downloadUrl;
}

sealed class UpdateResult {
  const UpdateResult();
}

class UpToDate extends UpdateResult {
  const UpToDate(this.current);
  final String current;
}

class UpdateAvailable extends UpdateResult {
  const UpdateAvailable(this.current, this.info);
  final String current;
  final UpdateInfo info;
}

class UpdateFailed extends UpdateResult {
  const UpdateFailed(this.message);
  final String message;
}

/// Compares dotted versions like `1.2.10` vs `1.2.9`. Ignores a leading `v`
/// and any `+build` / `-pre` suffix. Returns >0 when [a] is newer than [b].
int compareVersions(String a, String b) {
  List<int> parse(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    s = s.split('+').first.split('-').first;
    return s.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  final pa = parse(a), pb = parse(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// Picks the release asset for the running platform by file name.
String? pickAssetUrl(List<dynamic> assets, {required bool android}) {
  for (final a in assets) {
    if (a is! Map) continue;
    final name = (a['name'] as String? ?? '').toLowerCase();
    final url = a['browser_download_url'] as String?;
    if (url == null) continue;
    if (android && name.endsWith('.apk')) return url;
    if (!android && name.endsWith('.zip') && name.contains('windows')) {
      return url;
    }
  }
  return null;
}

/// Parses the GitHub `releases/latest` JSON.
UpdateInfo? parseRelease(Map<String, dynamic> json, {required bool android}) {
  if (json['draft'] == true || json['prerelease'] == true) return null;
  final tag = json['tag_name'] as String?;
  if (tag == null || tag.isEmpty) return null;
  final page = json['html_url'] as String? ?? '';
  return UpdateInfo(
    version: tag.startsWith('v') ? tag.substring(1) : tag,
    notes: (json['body'] as String? ?? '').trim(),
    pageUrl: page,
    downloadUrl:
        pickAssetUrl(json['assets'] as List? ?? const [], android: android) ??
            page,
  );
}

abstract class UpdateChecker {
  Future<UpdateResult> check();

  /// Opens the download (browser on Android, default handler on Windows).
  Future<bool> open(String url);
}

class GithubUpdateChecker implements UpdateChecker {
  GithubUpdateChecker({
    this.repo = 'Bayu-Pasifik/Nudge',
    Future<String> Function()? currentVersion,
    Future<String> Function(Uri url)? fetch,
  })  : _currentVersion = currentVersion ?? _packageVersion,
        _fetch = fetch ?? _httpGet;

  final String repo;
  final Future<String> Function() _currentVersion;
  final Future<String> Function(Uri url) _fetch;

  static Future<String> _packageVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  static Future<String> _httpGet(Uri url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(url);
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'nudge-app');
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 404) throw const _NoRelease();
      if (res.statusCode != 200) {
        throw HttpException('GitHub membalas ${res.statusCode}');
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<UpdateResult> check() async {
    try {
      final current = await _currentVersion();
      final body = await _fetch(
        Uri.https('api.github.com', '/repos/$repo/releases/latest'),
      );
      final info = parseRelease(
        jsonDecode(body) as Map<String, dynamic>,
        android: Platform.isAndroid,
      );
      if (info == null || compareVersions(info.version, current) <= 0) {
        return UpToDate(current);
      }
      return UpdateAvailable(current, info);
    } on _NoRelease {
      return UpToDate(await _currentVersion());
    } on SocketException {
      return const UpdateFailed('Tidak ada koneksi internet.');
    } catch (e) {
      return UpdateFailed('Gagal memeriksa pembaruan: $e');
    }
  }

  @override
  Future<bool> open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

class _NoRelease implements Exception {
  const _NoRelease();
}

/// Test double: returns a fixed result and records opened links.
class FakeUpdateChecker implements UpdateChecker {
  FakeUpdateChecker(this.result);
  UpdateResult result;
  final opened = <String>[];

  @override
  Future<UpdateResult> check() async => result;

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }
}

final updateCheckerProvider =
    Provider<UpdateChecker>((ref) => GithubUpdateChecker());
