import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

enum ReportFormat { xlsx, csv }

class TabularReport {
  TabularReport({
    required this.filename,
    required this.headers,
    required this.rows,
  });
  final String filename;
  final List<String> headers;
  final List<List<Object?>> rows;
}

class ReportExportService {
  static Uint8List encode(TabularReport report, ReportFormat format) {
    if (format == ReportFormat.csv) {
      final table = [
        report.headers,
        ...report.rows,
      ].map((row) => row.map(_safeCsvCell).toList()).toList();
      return Uint8List.fromList(
        utf8.encode('\uFEFF${const ListToCsvConverter().convert(table)}'),
      );
    }
    final workbook = Excel.createExcel();
    workbook.rename(workbook.getDefaultSheet()!, 'Laporan');
    final sheet = workbook['Laporan'];
    for (final row in [report.headers, ...report.rows]) {
      sheet.appendRow(
        row
            .map(
              (value) => switch (value) {
                int number => IntCellValue(number),
                double number => DoubleCellValue(number),
                bool flag => BoolCellValue(flag),
                _ => TextCellValue(value?.toString() ?? ''),
              },
            )
            .toList(),
      );
    }
    return Uint8List.fromList(workbook.encode()!);
  }

  static Object _safeCsvCell(Object? value) {
    if (value == null) return '';
    if (value is! String) return value;
    // Spreadsheet apps must not execute formulas supplied through school data.
    return RegExp(r'^\s*[=+@-]').hasMatch(value) ? "'$value" : value;
  }
}
