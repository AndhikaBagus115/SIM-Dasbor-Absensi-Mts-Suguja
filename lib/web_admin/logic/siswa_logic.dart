import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart'; // Butuh Material untuk BuildContext & Colors
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html; // Khusus Web Download
import '../core/services/master_data_cache_service.dart';
import '../data/repositories/siswa_repository.dart';
import '../data/repositories/kelas_repository.dart';

class DataSiswaLogic with ChangeNotifier {
  final SupabaseClient supabase;
  final SiswaRepository siswaRepository;
  final KelasRepository kelasRepository;

  DataSiswaLogic({
    SupabaseClient? client,
    SiswaRepository? siswaRepo,
    KelasRepository? kelasRepo,
  })  : supabase = client ?? Supabase.instance.client,
        siswaRepository = siswaRepo ?? SiswaRepositoryImpl(client ?? Supabase.instance.client),
        kelasRepository = kelasRepo ?? KelasRepositoryImpl(client ?? Supabase.instance.client);

  // --- State ---
  bool _isLoading = true;
  bool _isKelasLoading = true;

  List<Map<String, dynamic>> _siswaData = [];
  List<Map<String, dynamic>> _kelasList = [];

  // Filter State
  String? _selectedKelasId; // Disimpan sebagai String biar fleksibel
  String? _selectedStatus;
  String _lastSearchQuery = "";

  // Pagination State
  int _itemLimit = 10;
  int _currentPage = 1;
  int _totalItems = 0;

  // --- Getters ---
  bool get isLoading => _isLoading;
  bool get isKelasLoading => _isKelasLoading;
  List<Map<String, dynamic>> get siswaData => _siswaData;
  List<Map<String, dynamic>> get kelasList => _kelasList;

  // Getter untuk UI
  int? get selectedKelasId => int.tryParse(_selectedKelasId ?? '');
  String? get selectedStatus => _selectedStatus;

  int get itemLimit => _itemLimit;
  int get currentPage => _currentPage;
  int get totalItems => _totalItems;

  int get totalPages {
    if (_itemLimit == 0) return 0;
    return (_totalItems / _itemLimit).ceil();
  }

  String get paginationInfo {
    if (_totalItems == 0) return "0 - 0 dari 0";
    int start = (_currentPage - 1) * _itemLimit + 1;
    int end = start + _siswaData.length - 1;
    return "$start - $end dari $_totalItems";
  }

  String get selectedKelasNama {
    if (_selectedKelasId == null) return "Semua Kelas";
    try {
      final k = _kelasList.firstWhere(
        (e) => e['id'].toString() == _selectedKelasId,
        orElse: () => {'nama_kelas': 'Kelas'},
      );
      return k['nama_kelas'];
    } catch (_) {
      return "Kelas";
    }
  }

  // --- INIT ---
  Future<void> init(String? initialKelasId) async {
    _selectedKelasId = initialKelasId;
    await _fetchKelas();
    // fetchSiswa dipanggil di akhir _fetchKelas
  }

  // --- FETCHING ---

  Future<void> _fetchKelas({bool forceRefresh = false}) async {
    _isKelasLoading = true;
    notifyListeners();

    try {
      final response = await MasterDataCacheService.instance
          .getKelasList(forceRefresh: forceRefresh);
      _kelasList = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching kelas: $e');
    } finally {
      _isKelasLoading = false;
      notifyListeners();
      // Setelah kelas siap, baru fetch siswa
      fetchSiswa("");
    }
  }

  Future<void> fetchSiswa(String searchQuery, {bool resetPage = false}) async {
    _lastSearchQuery = searchQuery; 

    if (resetPage) {
      _currentPage = 1;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // ---------------------------------------------------------
      // 1. QUERY BUILDER (Dasar)
      // ---------------------------------------------------------
      // Kita buat base query dulu tanpa di-execute.
      // Filter akan diterapkan ke base query ini.

      // Query untuk data utama
      var query = supabase.from('siswa').select('*, kelas!inner(nama_kelas)');

      // Query untuk menghitung total (Count)
      var countQuery = supabase
          .from('siswa')
          .select('id'); // Select ID saja biar ringan

      // ---------------------------------------------------------
      // 2. TERAPKAN FILTER (Ke kedua query)
      // ---------------------------------------------------------
      if (_selectedKelasId != null) {
        query = query.eq('kelas_id', _selectedKelasId!);
        countQuery = countQuery.eq('kelas_id', _selectedKelasId!);
      }

      if (_selectedStatus != null) {
        query = query.eq('status', _selectedStatus!);
        countQuery = countQuery.eq('status', _selectedStatus!);
      }

      if (searchQuery.isNotEmpty) {
        query = query.ilike('nama', '%$searchQuery%');
        countQuery = countQuery.ilike('nama', '%$searchQuery%');
      }

      // ---------------------------------------------------------
      // 3. EKSEKUSI COUNT (Total Data)
      // ---------------------------------------------------------
      // Panggil .count() DI AKHIR setelah semua filter terpasang
      final countRes = await countQuery.count(CountOption.exact);
      _totalItems = countRes.count;

      // ---------------------------------------------------------
      // 4. EKSEKUSI MAIN DATA (Pagination & Sorting)
      // ---------------------------------------------------------
      final from = (_currentPage - 1) * _itemLimit;
      final to = from + _itemLimit - 1;

      // Order dan Range dipasang terakhir sebelum await
      final response = await query
          .order('created_at', ascending: false)
          .range(from, to);

      _siswaData = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching siswa: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Di dalam DataSiswaLogic

  Future<void> prosesKenaikanKelas({
    required int sourceKelasId,
    int? targetKelasId,
    required bool isLuluskan,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (isLuluskan) {
        // OPSI 1: LULUSKAN SEMUA SISWA DI KELAS SUMBER (Misal 9A -> Lulus)
        await supabase
            .from('siswa')
            .update({'status': 'lulus'})
            .eq('kelas_id', sourceKelasId)
            .eq('status', 'aktif'); // Hanya yang aktif
      } else {
        // OPSI 2: PINDAHKAN SEMUA SISWA (Misal 7A -> 8A)
        if (targetKelasId != null) {
          await supabase
              .from('siswa')
              .update({'kelas_id': targetKelasId}) // Update ID Kelas
              .eq('kelas_id', sourceKelasId)
              .eq('status', 'aktif');
        }
      }

      // Refresh Data
      await fetchSiswa("");
    } catch (e) {
      debugPrint("Error kenaikan kelas: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Tambahkan fungsi ini di dalam class DataSiswaLogic

  /// Fungsi untuk mengubah status siswa (misal: aktif -> lulus, atau lulus -> aktif)
  Future<String?> updateStatusSiswa(int id, String status) async {
    try {
      await supabase
          .from('siswa')
          .update({'status': status}) // Update kolom status
          .eq('id', id);

      // Refresh data tabel agar perubahan langsung terlihat
      await fetchSiswa(_lastSearchQuery);

      return null; // Null artinya sukses (tidak ada error)
    } catch (e) {
      debugPrint("Error update status: $e");
      return 'Gagal mengubah status: $e';
    }
  }

  // --- PAGINATION & FILTER ACTIONS ---

  void updateLimit(int newLimit, String searchKeyword) {
    _itemLimit = newLimit;
    fetchSiswa(searchKeyword, resetPage: true);
  }

  void nextPage(String searchKeyword) {
    if (_currentPage < totalPages) {
      _currentPage++;
      fetchSiswa(searchKeyword);
    }
  }

  void previousPage(String searchKeyword) {
    if (_currentPage > 1) {
      _currentPage--;
      fetchSiswa(searchKeyword);
    }
  }

  void onKelasSelected(int? kelasId, String searchKeyword) {
    _selectedKelasId = kelasId?.toString();
    fetchSiswa(searchKeyword, resetPage: true);
  }

  void onStatusSelected(String? status, String searchKeyword) {
    _selectedStatus = status;
    fetchSiswa(searchKeyword, resetPage: true);
  }

  // --- CRUD ---

  Future<String?> saveSiswa({
    required bool isEdit,
    int? siswaId,
    required String nis,
    required String nama,
    required int? kelasId,
    required String ortuNama,
    required String ortuNomor,
    required String? status,
  }) async {
    try {
      final data = {
        'nis': nis,
        'nama': nama,
        'kelas_id': kelasId,
        'orang_tua_nama': ortuNama,
        'orang_tua_nomor': ortuNomor,
        'status': status ?? 'aktif',
      };

      if (isEdit) {
        await supabase.from('siswa').update(data).eq('id', siswaId!);
      } else {
        await supabase.from('siswa').insert(data);
      }

      MasterDataCacheService.instance.invalidateSiswa(kelasId: kelasId);
      await fetchSiswa(""); // Refresh tanpa reset filter
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String?> deleteSiswa(int id) async {
    try {
      await supabase.from('siswa').delete().eq('id', id);
      MasterDataCacheService.instance.invalidateSiswa();
      await fetchSiswa("");
      return null;
    } catch (e) {
      return 'Gagal menghapus: $e';
    }
  }

  // --- IMPORT EXCEL (Optimized for Web) ---

  Future<void> importExcel(BuildContext context) async {
    if (_selectedKelasId == null) {
      _showSnackbar(
        context,
        'Pilih filter Kelas terlebih dahulu!',
        isError: true,
      );
      return;
    }

    final int targetKelasId = int.parse(_selectedKelasId!);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true, // WAJIB true untuk Web
      );

      if (result == null || result.files.single.bytes == null) return;

      // Loading Indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      final bytes = result.files.single.bytes!;
      var excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) throw "File Excel kosong.";

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.length < 2) {
        throw "Sheet kosong/format salah.";
      }

      final List<Map<String, dynamic>> batchData = [];

      // Helper baca cell aman
      String? getCell(List<Data?> row, int index) {
        if (index >= row.length) return null;
        return row[index]?.value?.toString().trim();
      }

      // Loop mulai baris ke-2 (index 1)
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        // Mapping Kolom Excel (Sesuaikan index 0, 1, 2 dst)
        // Asumsi: A=No, B=NIS, C=Nama, D=Ortu
        final nis = getCell(row, 1); // Kolom B
        final nama = getCell(row, 2); // Kolom C
        final ortu = getCell(row, 3) ?? '-'; // Kolom D

        if (nis != null && nis.isNotEmpty && nama != null && nama.isNotEmpty) {
          batchData.add({
            'nis': nis,
            'nama': nama,
            'kelas_id': targetKelasId,
            'orang_tua_nama': ortu,
            'status': 'aktif',
          });
        }
      }

      if (batchData.isEmpty) throw "Tidak ada data valid ditemukan.";

      // Bulk Insert
      await supabase.from('siswa').upsert(batchData, onConflict: 'nis');
      MasterDataCacheService.instance.invalidateSiswa(kelasId: targetKelasId);

      // Tutup Loading
      if (context.mounted) {
        Navigator.pop(context);
        _showSnackbar(context, 'Berhasil import ${batchData.length} data!');
      }
      await fetchSiswa("");
    } catch (e) {
      if (context.mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        _showSnackbar(context, 'Gagal import: $e', isError: true);
      }
    }
  }

  // --- PDF & QR CODE ---

  Future<void> generateBarcodePdf(BuildContext context) async {
    // 1. Tampilkan loading dialog agar user mengetahui proses persiapan PDF semua siswa
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Menyiapkan semua QR Code siswa...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      // 2. Fetch seluruh data siswa sesuai filter aktif (tanpa batasan pagination)
      var query = supabase
          .from('siswa')
          .select('id, nis, nama, status, kelas_id, kelas!inner(nama_kelas)');

      if (_selectedKelasId != null) {
        query = query.eq('kelas_id', _selectedKelasId!);
      }

      if (_selectedStatus != null) {
        query = query.eq('status', _selectedStatus!);
      }

      if (_lastSearchQuery.isNotEmpty) {
        query = query.ilike('nama', '%$_lastSearchQuery%');
      }

      final response = await query.order('nama', ascending: true);
      final List<Map<String, dynamic>> allSiswa =
          List<Map<String, dynamic>>.from(response);

      // Tutup loading dialog
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (allSiswa.isEmpty) {
        if (context.mounted) {
          _showSnackbar(
            context,
            'Tidak ada data siswa yang sesuai filter untuk dicetak.',
            isError: true,
          );
        }
        return;
      }

      // 3. Bangun dokumen PDF dengan seluruh QR code siswa
      final pdf = pw.Document();

      final List<pw.Widget> grids = allSiswa.map((s) {
        final nis = s['nis']?.toString() ?? '-';
        final nama = s['nama']?.toString() ?? 'Siswa';
        final kelasNama =
            s['kelas']?['nama_kelas']?.toString() ?? selectedKelasNama;

        return pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                nama,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
                maxLines: 1,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                kelasNama,
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey700,
                ),
                textAlign: pw.TextAlign.center,
                maxLines: 1,
              ),
              pw.SizedBox(height: 6),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: nis,
                width: 80,
                height: 80,
                drawText: false,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'NIS: $nis',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
        );
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          header: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Kartu QR Code Presensi - $selectedKelasNama (${allSiswa.length} Siswa)',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          build: (context) => [
            pw.GridView(
              crossAxisCount: 3,
              childAspectRatio: 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: grids,
            ),
          ],
        ),
      );

      // Trigger Print / Download di Browser
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name:
            'QR_${selectedKelasNama}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        _showSnackbar(context, 'Gagal generate PDF: $e', isError: true);
      }
    }
  }

  Future<void> downloadBarcode(Uint8List bytes, String filename) async {
    final base64 = base64Encode(bytes);
    final href = 'data:application/octet-stream;base64,$base64';
    html.AnchorElement(href: href)
      ..setAttribute("download", filename)
      ..click();
  }

  // --- Helper Snackbar ---
  void _showSnackbar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}
