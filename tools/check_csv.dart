import 'dart:convert';
import 'dart:io';
import 'package:coin_flow/data/csv_service.dart';
import 'package:coin_flow/domain/models.dart';

/// Read-only format check; no app repository or preferences are opened.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tools/check_csv.dart <path-to-csv>');
    exitCode = 64;
    return;
  }
  try {
    final file = File(args.single);
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException('Файл больше 5 МБ');
    }
    final preview = CsvService().preview(await file.readAsString());
    stdout.writeln(
      jsonEncode({
        'format': preview.formatName,
        'cards': {
          for (final kind in CardKind.values)
            kind.name: preview.data.cards.where((c) => c.kind == kind).length,
        },
        'entries': {
          for (final kind in EntryKind.values)
            kind.name: preview.data.entries.where((e) => e.kind == kind).length,
        },
        'totalEntries': preview.data.entries.length,
        'mode': 'read-only',
      }),
    );
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
