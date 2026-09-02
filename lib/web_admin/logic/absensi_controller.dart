import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/master_data_cache_service.dart';
import '../data/repositories/absensi_repository.dart';
import '../data/repositories/kelas_repository.dart';

class AbsensiController extends ChangeNotifier {
  final SupabaseClient supabase;
  final AbsensiRepository absensiRepository;
  final KelasRepository kelasRepository;
  final String schoolName;

  // --- STATE UTAMA ---
  bool isRekapMode = false; // FALSE = Harian, TRUE = Rekap Bulanan

  // State Filter
  DateTime selectedDate = DateTime.now();
  int? selectedKelasId;
  int itemLimit = 10;
  int currentPage = 1;

  // State Data & UI
  bool isLoading = false;
  bool isKelasLoading = false;

  // Container Data
  List<Map<String, dynamic>> absensiData = []; // Data Harian
  List<Map<String, dynamic>> rekapData = []; // Data Rekap Bulanan

  // Pagination Info
  int totalRows = 0;

  // Data Kelas (Untuk Dropdown)
  List<Map<String, dynamic>> daftarKelas = [];

  AbsensiController({
    required this.schoolName,
    SupabaseClient? client,
    AbsensiRepository? absensiRepo,
    KelasRepository? kelasRepo,
  })  : supabase = client ?? Supabase.instance.client,
        absensiRepository = absensiRepo ?? AbsensiRepositoryImpl(client ?? Supabase.instance.client),
        kelasRepository = kelasRepo ?? KelasRepositoryImpl(client ?? Supabase.instance.client) {
    fetchKelas();
    fetchData();
  }

  // --- ACTIONS ---

  void toggleMode(bool isRekap) {
    if (isRekapMode == isRekap) return;
    isRekapMode = isRekap;
    currentPage = 1; // Reset halaman saat ganti mode
    notifyListeners();
    fetchData();
  }

  Future<void> fetchData() async {
    if (isRekapMode) {
      await _fetchRekapBulanan();
    } else {
      await _fetchAbsensiHarian();
    }
  }

  // --- FETCHING LOGIC ---

  Future<void> fetchKelas({bool forceRefresh = false}) async {
    isKelasLoading = true;
    notifyListeners();
    try {
      final response = await MasterDataCacheService.instance
          .getKelasList(forceRefresh: forceRefresh);
      daftarKelas = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error Fetch Kelas: $e");
    } finally {
      isKelasLoading = false;
      notifyListeners();
    }
  }

  // 1. Fetch Absensi Harian (Server-side Pagination)
  Future<void> _fetchAbsensiHarian() async {
    isLoading = true;
    notifyListeners();

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final startRow = (currentPage - 1) * itemLimit;
      final endRow = startRow + itemLimit - 1;

      // ============================================================
      // OPTIMASI: SINGLE QUERY (DATA + COUNT)
      // ============================================================

      // 1. Mulai Query
      var query = supabase
          .from('absensi')
          .select(
            '*, siswa!inner(nama, kelas_id, nis, status), guru:updated_by(nama)',
          ); // Jangan pakai FetchOptions disini untuk v2

      // 2. Filter Tanggal (Gunakan Index Database)
      query = query.eq('tanggal', dateStr);

      // 3. Filter Status Siswa (HANYA AKTIF)
      query = query.eq('siswa.status', 'aktif');

      // 3. Filter Kelas (Inner Join)
      if (selectedKelasId != null) {
        query = query.eq('siswa.kelas_id', selectedKelasId!);
      }

      // 4. Eksekusi dengan CountOption.exact
      // Dengan menambahkan .count(), return type berubah menjadi PostgrestResponse
      final response = await query
          .order('waktu_masuk', ascending: true)
          .range(startRow, endRow)
          .count(CountOption.exact);

      // 5. Ambil Data dan Count sekaligus
      // Tidak perlu query terpisah lagi!
      final dataList = List<Map<String, dynamic>>.from(response.data as List);
      final total = response.count;

      absensiData = dataList;
      totalRows = total;
    } catch (e) {
      debugPrint("Error Harian: $e");
      absensiData = [];
      totalRows = 0;

      // Tips: Jika error "The getter 'data' isn't defined",
      // pastikan package supabase_flutter sudah versi terbaru (v2.x)
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 2. Fetch Rekap Bulanan (Optimized via RPC Database)
  Future<void> _fetchRekapBulanan() async {
    isLoading = true;
    notifyListeners();

    try {
      // Panggil Store Procedure (Function) di Database
      // Pastikan fungsi 'get_rekap_absensi' sudah dibuat di SQL Editor Supabase
      final params = {
        'p_month': selectedDate.month,
        'p_year': selectedDate.year,
        'p_kelas_id': selectedKelasId, // Bisa null, RPC akan handle
      };

      final response = await supabase.rpc('get_rekap_absensi', params: params);

      // Hasil RPC sudah matang (ada kolom hadir, sakit, izin, persentase)
      rekapData = List<Map<String, dynamic>>.from(response as List);

      // Total Rows di rekap = Jumlah Siswa
      totalRows = rekapData.length;
    } catch (e) {
      debugPrint("Error Rekap RPC: $e");
      // Fallback jika RPC gagal/belum dibuat (Opsional: Kosongkan data)
      rekapData = [];
      totalRows = 0;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // --- FILTER HELPERS ---

  Future<void> updateLimit(int? val) async {
    if (val == null || val == itemLimit) return;
    itemLimit = val;
    currentPage = 1;
    notifyListeners();
    await fetchData();
  }

  void onKelasSelected(int? val) {
    selectedKelasId = val;
    currentPage = 1;
    fetchData();
  }

  Future<void> handleDatePick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: isRekapMode
          ? "PILIH BULAN (Tanggal Bebas)"
          : "PILIH TANGGAL ABSENSI",
    );
    if (picked != null && picked != selectedDate) {
      selectedDate = picked;
      currentPage = 1;
      fetchData();
    }
  }

  // --- PAGINATION HELPERS ---

  void nextPage() {
    // Cek batas halaman
    if (currentPage < totalPages) {
      currentPage++;
      fetchData();
    }
  }

  void prevPage() {
    if (currentPage > 1) {
      currentPage--;
      fetchData();
    }
  }

  int get totalPages {
    if (totalRows == 0 || itemLimit == 0) return 1;
    return (totalRows / itemLimit).ceil();
  }

  // --- FORMATTERS ---

  String fmtTime(String? time) {
    if (time == null) return '-';
    try {
      // Jika format HH:MM:SS
      final parts = time.split(':');
      if (parts.length >= 2) {
        return "${parts[0]}:${parts[1]}";
      }
      return time;
    } catch (_) {
      return time;
    }
  }

  // --- PDF EXPORT ---

  Future<void> exportPdf(BuildContext context) async {
    try {
      if (isRekapMode) {
        await _generatePdfRekap(context);
      } else {
        await _generatePdfHarian(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal export PDF: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generatePdfRekap(BuildContext context) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoExtraLight();
    final bulanStr = DateFormat('MMMM yyyy', 'id_ID').format(selectedDate);

    // Siapkan Data Table
    final tableHeaders = ['No', 'Nama Siswa', 'H', 'T', 'S', 'I', 'A', '%'];
    final tableData = rekapData.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final d = entry.value;
      return [
        '$i',
        d['nama_siswa'] ?? '-', // Sesuaikan dengan key return RPC
        '${d['hadir'] ?? 0}',
        '${d['terlambat'] ?? 0}',
        '${d['sakit'] ?? 0}',
        '${d['izin'] ?? 0}',
        '${d['alpha'] ?? 0}',
        '${d['persentase']}%',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font),
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              schoolName,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
            ),
          ),
          pw.Paragraph(text: "Laporan Rekapitulasi Absensi - $bulanStr"),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: tableHeaders,
            data: tableData,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center, // No
              2: pw.Alignment.center, // H
              3: pw.Alignment.center, // T
              4: pw.Alignment.center, // S
              5: pw.Alignment.center, // I
              6: pw.Alignment.center, // A
              7: pw.Alignment.center, // %
            },
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _generatePdfHarian(BuildContext context) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoExtraLight();
    final tglStr = DateFormat('dd MMMM yyyy', 'id_ID').format(selectedDate);

    final tableHeaders = [
      'No',
      'Nama Siswa',
      'Masuk',
      'Pulang',
      'Status',
      'Ket',
    ];
    final tableData = absensiData.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final d = entry.value;
      final siswa = d['siswa'] ?? {};
      return [
        '$i',
        siswa['nama'] ?? '-',
        fmtTime(d['waktu_masuk']),
        fmtTime(d['waktu_pulang']),
        (d['status'] ?? '-').toString().toUpperCase(),
        d['keterangan'] ?? '-',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font),
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              schoolName,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
            ),
          ),
          pw.Paragraph(text: "Laporan Harian - $tglStr"),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: tableHeaders,
            data: tableData,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {0: pw.Alignment.center},
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}
