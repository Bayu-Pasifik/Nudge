import 'dart:convert';

import '../db/database.dart';
import '../sync/remote.dart';
import '../sync/sync_tables.dart';

/// Version of the export format; bump if the shape changes.
const exportFormatVersion = 1;

/// Builds a full, human-readable JSON backup of every live row. Reuses the
/// sync encoding so a backup has the same field names as the server schema.
///
/// Deleted rows (tombstones) are left out: a backup is what the user can see.
Future<String> buildExportJson(AppDatabase db, {DateTime? now}) async {
  final tables = <String, List<Row>>{};
  for (final t in syncTables) {
    final rows = await t.all(db, 'local');
    tables[t.name] = [
      for (final r in rows)
        if (r['deleted_at'] == null) _clean(r),
    ];
  }
  return const JsonEncoder.withIndent('  ').convert({
    'app': 'Nudge',
    'format': exportFormatVersion,
    'exported_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'counts': {for (final e in tables.entries) e.key: e.value.length},
    'data': tables,
  });
}

/// Drops sync-only noise from a row.
Row _clean(Row r) => {
      for (final e in r.entries)
        if (e.key != 'user_id') e.key: e.value,
    };
