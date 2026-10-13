import 'dart:io';
import 'package:coin_flow/data/csv_service.dart';
import 'package:coin_flow/data/demo_data.dart';

void main() {
  File(
    'templates/full_backup.csv',
  ).writeAsStringSync(CsvService().export(demoData()));
}
