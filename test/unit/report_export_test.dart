import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_admin_mts/web_admin/core/services/report_export_service.dart';
import 'package:web_admin_mts/web_admin/data/repositories/report_repository.dart';

void main() {
  test(
    'teacher and class exports include every page and their displayed fields',
    () async {
      for (final table in ['guru', 'kelas']) {
        var requests = 0;
        final client = SupabaseClient(
          'https://example.supabase.co',
          'fixture',
          httpClient: MockClient((request) async {
            expect(request.url.path, '/rest/v1/$table');
            requests++;
            final data = table == 'guru'
                ? {
                    'id': 'uuid-$requests',
                    'nama': 'Guru $requests',
                    'email': 'fixture@example.invalid',
                    'role': 'guru',
                    'no_hp': '08123',
                  }
                : {
                    'id': requests,
                    'nama_kelas': 'Kelas $requests',
                    'jam_masuk': '07:00',
                    'jam_pulang': '13:00',
                    'guru': {'nama': 'Wali $requests'},
                  };
            return http.Response(
              jsonEncode([data]),
              200,
              request: request,
              headers: {
                'content-type': 'application/json',
                'content-range': '${requests - 1}-${requests - 1}/2',
              },
            );
          }),
        );
        try {
          final repository = ReportRepository(client);
          final report = table == 'guru'
              ? await repository.guru()
              : await repository.kelas();
          expect(report.rows.length, 2);
          expect(requests, 2);
          expect(report.rows.first.length, report.headers.length);
          expect(
            report.rows.last.first,
            table == 'guru' ? 'Guru 2' : 'Kelas 2',
          );
        } finally {
          await client.dispose();
        }
      }
    },
  );
  test(
    'monthly export paginates the same RPC with the selected month/year/class',
    () async {
      var requests = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/get_rekap_absensi');
          expect(jsonDecode(request.body), {
            'p_month': 11,
            'p_year': 2026,
            'p_kelas_id': 7,
          });
          requests++;
          return http.Response(
            jsonEncode([
              {
                'nama_siswa': 'Siswa $requests',
                'hadir': 3,
                'alpha': 1,
                'persentase': 75,
              },
            ]),
            200,
            request: request,
            headers: {
              'content-type': 'application/json',
              'content-range': '${requests - 1}-${requests - 1}/2',
            },
          );
        }),
      );
      addTearDown(client.dispose);
      final report = await ReportRepository(
        client,
      ).absensi(DateTime(2026, 11, 22), kelasId: 7, monthly: true);
      expect(report.rows.length, 2);
      expect(report.rows.last.first, 'Siswa 2');
      expect(report.filename, 'rekap_2026-11');
    },
  );
  final report = TabularReport(
    filename: 'fixture',
    headers: ['NIS', 'Nama', 'Jumlah'],
    rows: [
      ['00123', 'Nama, dengan\nbaris baru', 12],
      ['00999', '=HYPERLINK("bad")', 3],
    ],
  );
  test('CSV preserves Unicode/newlines and neutralizes formulas', () {
    final bytes = ReportExportService.encode(report, ReportFormat.csv);
    final text = utf8.decode(bytes).replaceFirst('\uFEFF', '');
    final decoded = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(text);
    expect(decoded[1], ['00123', 'Nama, dengan\nbaris baru', '12']);
    expect(decoded[2][1], startsWith("'="));
  });
  test('XLSX keeps identifiers as text and numeric cells as numbers', () {
    final bytes = ReportExportService.encode(report, ReportFormat.xlsx);
    final workbook = Excel.decodeBytes(bytes);
    final rows = workbook['Laporan'].rows;
    expect(rows[1][0]!.value, isA<TextCellValue>());
    expect(rows[1][0]!.value.toString(), '00123');
    expect(rows[1][2]!.value, isA<IntCellValue>());
    expect(rows[2][1]!.value, isA<TextCellValue>());
  });
  test(
    'student export reads every row even when server caps pages below requested size',
    () async {
      final offsets = <int>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['kelas_id'], 'eq.7');
          expect(request.url.queryParameters['status'], 'eq.aktif');
          expect(request.url.queryParameters['nama'], 'ilike.%Nama%');
          final from = int.parse(request.url.queryParameters['offset']!);
          offsets.add(from);
          final data = List.generate(
            5,
            (index) => {
              'id': index + 1,
              'nis': '00$index',
              'nama': 'Nama $index',
              'kelas': {'nama_kelas': '7A'},
            },
          ).skip(from).take(2).toList();
          return http.Response(
            jsonEncode(data),
            200,
            request: request,
            headers: {
              'content-type': 'application/json',
              'content-range': '$from-${from + data.length - 1}/5',
            },
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await ReportRepository(
        client,
      ).siswa(kelasId: '7', status: 'aktif', search: 'Nama');
      expect(result.rows.length, 5);
      expect(offsets, [0, 2, 4]);
      expect(result.rows.last[0], '004');
    },
  );
  test(
    'daily export includes every page with the selected date and class',
    () async {
      var requests = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['tanggal'], 'eq.2026-11-22');
          expect(request.url.queryParameters['siswa.kelas_id'], 'eq.7');
          requests++;
          return http.Response(
            jsonEncode([
              {
                'id': requests,
                'siswa': {
                  'nama': 'Student $requests',
                  'kelas': {'nama_kelas': '7A'},
                },
              },
            ]),
            200,
            request: request,
            headers: {
              'content-type': 'application/json',
              'content-range': '${requests - 1}-${requests - 1}/3',
            },
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await ReportRepository(
        client,
      ).absensi(DateTime(2026, 11, 22), kelasId: 7);
      expect(result.rows.length, 3);
      expect(requests, 3);
    },
  );
}
