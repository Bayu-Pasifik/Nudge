import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../db/database.dart';
import 'export_json.dart';

class ExportResult {
  const ExportResult({required this.json, required this.path});
  final String json;

  /// Where the file was written.
  final String path;
}

String _stamp(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}'
    '-${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';

/// Writes a JSON backup to the user's Downloads folder (desktop) or the app
/// documents folder (Android, where there is no public Downloads API without
/// extra permissions; the caller also copies the text to the clipboard).
Future<ExportResult> exportAll(AppDatabase db, {Directory? directory}) async {
  final now = DateTime.now();
  final json = await buildExportJson(db, now: now);
  final dir = directory ??
      await getDownloadsDirectory() ??
      await getApplicationDocumentsDirectory();
  await dir.create(recursive: true);
  final file = File('${dir.path}${Platform.pathSeparator}nudge-export-${_stamp(now)}.json');
  await file.writeAsString(json);
  return ExportResult(json: json, path: file.path);
}
