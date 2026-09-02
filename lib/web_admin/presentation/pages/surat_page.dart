import 'dart:io';
import 'dart:math';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:archive/archive.dart';

import '../../core/theme.dart';

const List<String> jenisSuratList = ['izin', 'sakit'];

class DataSuratPage extends StatefulWidget {
  final String schoolName;

  const DataSuratPage({super.key, required this.schoolName});

  @override
  State<DataSuratPage> createState() => _DataSuratPageState();
}

class _DataSuratPageState extends State<DataSuratPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  List<Map<String, dynamic>> _allSuratData = [];
  List<Map<String, dynamic>> suratData = [];

  int _currentPage = 1;
  int _rowsPerPage = 10;

  String? selectedJenisSurat;
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  final TextEditingController searchController = TextEditingController();
  Timer? _searchDebounce;

  late final TextEditingController _startDateCtrl;
  late final TextEditingController _endDateCtrl;

  static const String _bucketName = 'surat_keterangan';

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'id_ID';

    _startDateCtrl = TextEditingController();
    _endDateCtrl = TextEditingController();

    searchController.addListener(_onSearchChanged);
    fetchSurat();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _applyClientSearchFilter(resetPage: true);
    });
  }

  void _applyClientSearchFilter({bool resetPage = false}) {
    final keyword = searchController.text.trim().toLowerCase();

    final filtered = (keyword.isEmpty)
        ? List<Map<String, dynamic>>.from(_allSuratData)
        : _allSuratData.where((s) {
            final nama = (s['siswa']?['nama'] ?? '').toString().toLowerCase();
            final nis = (s['siswa']?['nis'] ?? s['siswa_id'] ?? '').toString().toLowerCase();
            return nama.contains(keyword) || nis.contains(keyword);
          }).toList();

    setState(() {
      suratData = filtered;
      if (resetPage) _currentPage = 1;
    });
  }

  void _syncDateControllers() {
    _startDateCtrl.text = selectedStartDate == null
        ? ''
        : DateFormat('dd MMM yyyy').format(selectedStartDate!);
    _endDateCtrl.text = selectedEndDate == null
        ? ''
        : DateFormat('dd MMM yyyy').format(selectedEndDate!);
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String? _extractObjectPathFromPublicUrl({
    required String fileUrl,
    required String bucketName,
  }) {
    try {
      final uri = Uri.parse(fileUrl);
      final path = uri.path;
      final marker = '/storage/v1/object/public/$bucketName/';
      final idx = path.indexOf(marker);
      if (idx == -1) return null;
      return path.substring(idx + marker.length);
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchSurat() async {
    setState(() => isLoading = true);

    try {
      var query = supabase.from('surat').select('*, siswa(nama, nis)');

      if (selectedStartDate != null) {
        query = query.gte(
          'tanggal',
          DateFormat('yyyy-MM-dd').format(selectedStartDate!),
        );
      }
      if (selectedEndDate != null) {
        query = query.lte(
          'tanggal',
          DateFormat('yyyy-MM-dd').format(selectedEndDate!),
        );
      }
      if (selectedJenisSurat != null && selectedJenisSurat!.isNotEmpty) {
        query = query.eq('jenis', selectedJenisSurat!);
      }

      final response = await query.order('tanggal', ascending: false);
      final allData = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _allSuratData = allData;
          _currentPage = 1;
          isLoading = false;
        });
        _applyClientSearchFilter(resetPage: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackbar('Gagal memuat data surat: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllSuratForGlobalAction() async {
    final res = await supabase
        .from('surat')
        .select('id, siswa_id, tanggal, jenis, file_url, siswa(nama, nis)')
        .order('tanggal', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> _backupAllSuratToZipWeb() async {
    if (!kIsWeb) {
      _showSnackbar('Backup ZIP ini khusus untuk Web.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final data = await _fetchAllSuratForGlobalAction();
      if (data.isEmpty) {
        _showSnackbar('Tidak ada data surat untuk dibackup.');
        return;
      }

      _showSnackbar('Menyiapkan backup ZIP...');

      final archive = Archive();
      int added = 0;

      for (final s in data) {
        final url = (s['file_url'] ?? '').toString().trim();
        if (url.isEmpty) continue;

        final lower = url.toLowerCase();
        final isImage =
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.png') ||
            lower.endsWith('.webp');
        if (!isImage) continue;

        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode != 200) continue;

        final siswaName = (s['siswa']?['nama'] ?? 'unknown').toString();
        final tanggal = (s['tanggal'] ?? 'unknown').toString();
        final jenis = (s['jenis'] ?? 'unknown').toString();
        final ext = '.${lower.split('.').last}';

        final filename = '${siswaName}_${tanggal}_$jenis$ext';

        archive.addFile(
          ArchiveFile(filename, resp.bodyBytes.length, resp.bodyBytes),
        );
        added++;
      }

      if (added == 0) {
        _showSnackbar('Tidak ada foto surat yang valid untuk dibackup.');
        return;
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        _showSnackbar('Gagal membuat ZIP.');
        return;
      }

      final blob = html.Blob([Uint8List.fromList(zipBytes)], 'application/zip');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final zipName = 'backup_surat_$now.zip';

      html.AnchorElement(href: url)
        ..setAttribute('download', zipName)
        ..click();

      html.Url.revokeObjectUrl(url);
      _showSnackbar('Backup berhasil diunduh: $zipName');
    } catch (e) {
      _showSnackbar('Backup gagal: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _confirmDeleteAllGlobal() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    List<Map<String, dynamic>> all;
    try {
      all = await _fetchAllSuratForGlobalAction();
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      _showSnackbar('Gagal memuat data surat: $e');
      return;
    } finally {
      if (mounted) setState(() => isLoading = false);
    }

    if (all.isEmpty) {
      _showSnackbar('Tidak ada data surat untuk dihapus.');
      return;
    }

    final int total = all.length;
    final int withFile = all
        .where((e) => (e['file_url'] ?? '').toString().trim().isNotEmpty)
        .length;

    final confirmCtrl = TextEditingController();
    bool canDelete = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Hapus Semua Data Surat',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tindakan ini akan menghapus SEMUA data surat dari database dan file lampiran dari penyimpanan storage.',
                      style: TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• Total data surat: $total'),
                          const SizedBox(height: 4),
                          Text('• File foto/dokumen: $withFile'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Ketik "HAPUS SEMUA" untuk konfirmasi:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmCtrl,
                      autofocus: true,
                      onChanged: (v) {
                        setLocal(() {
                          canDelete = v.trim().toUpperCase() == 'HAPUS SEMUA';
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        hintText: 'HAPUS SEMUA',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.backup_rounded, size: 16),
                  label: const Text('Backup Dulu'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _backupAllSuratToZipWeb();
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Hapus Permanen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: canDelete
                      ? () {
                          Navigator.pop(ctx);
                          _deleteAllSuratAndStorage(all);
                        }
                      : null,
                ),
              ],
            );
          },
        );
      },
    );

    confirmCtrl.dispose();
  }

  Future<void> _deleteAllSuratAndStorage(
    List<Map<String, dynamic>> items,
  ) async {
    setState(() => isLoading = true);

    int deletedFiles = 0;
    int deletedRows = 0;

    try {
      final paths = <String>[];
      for (final s in items) {
        final fileUrl = (s['file_url'] ?? '').toString().trim();
        if (fileUrl.isEmpty) continue;

        final path = _extractObjectPathFromPublicUrl(
          fileUrl: fileUrl,
          bucketName: _bucketName,
        );
        if (path != null) {
          paths.add(path);
        }
      }

      for (int i = 0; i < paths.length; i += 100) {
        final part = paths.sublist(i, min(i + 100, paths.length));
        await supabase.storage.from(_bucketName).remove(part);
        deletedFiles += part.length;
      }

      final ids = items.map((e) => e['id']).toList();
      for (int i = 0; i < ids.length; i += 200) {
        final part = ids.sublist(i, min(i + 200, ids.length));
        await supabase.from('surat').delete().inFilter('id', part);
        deletedRows += part.length;
      }

      _showSnackbar(
        'Selesai. Terhapus: $deletedRows data surat & $deletedFiles file storage.',
      );
      await fetchSurat();
    } catch (e) {
      _showSnackbar('Gagal menghapus data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleDownload(String fileUrl, String fileName) async {
    if (fileUrl.isEmpty) {
      _showSnackbar('URL file tidak tersedia.');
      return;
    }

    final lower = fileUrl.toLowerCase();
    final isImage =
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');

    if (isImage) {
      _showSnackbar('Mengunduh & mengonversi gambar ke PDF...');
      try {
        final response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode != 200) {
          _showSnackbar('Gagal mengambil gambar. Status: ${response.statusCode}');
          return;
        }

        final imageBytes = response.bodyBytes;
        final pdf = pw.Document();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (_) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );

        final Uint8List pdfBytes = await pdf.save();
        final finalFileName = '$fileName.pdf';

        if (kIsWeb) {
          final blob = html.Blob([pdfBytes], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute("download", finalFileName)
            ..click();
          html.Url.revokeObjectUrl(url);
          _showSnackbar('PDF berhasil diunduh.');
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$finalFileName');
          await file.writeAsBytes(pdfBytes);

          final ok = await launchUrl(
            Uri.file(file.path),
            mode: LaunchMode.externalApplication,
          );
          _showSnackbar(
            ok ? 'PDF dibuat dan dibuka.' : 'PDF dibuat, tapi gagal dibuka.',
          );
        }
      } catch (e) {
        _showSnackbar('Gagal download/konversi: $e');
      }
      return;
    }

    final uri = Uri.parse(fileUrl);
    if (!await canLaunchUrl(uri)) {
      _showSnackbar('URL tidak bisa dibuka.');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    _syncDateControllers();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Banner
            _buildHeader(),

            const SizedBox(height: 20),

            // 2. Filter & Action Card
            _buildFilterCard(),

            const SizedBox(height: 20),

            // 3. Table Card
            isLoading
                ? Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _buildTableCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Surat Siswa',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Kelola dan arsipkan surat keterangan izin & sakit siswa',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_outlined, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  widget.schoolName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    final bool hasActiveFilter = selectedStartDate != null ||
        selectedEndDate != null ||
        selectedJenisSurat != null ||
        searchController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: Judul Filter + Tombol Aksi Global (Backup & Hapus)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Filter & Pencarian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              if (hasActiveFilter) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      selectedStartDate = null;
                      selectedEndDate = null;
                      selectedJenisSurat = null;
                      searchController.clear();
                    });
                    fetchSurat();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Reset Filter', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
              const Spacer(),
              // Action buttons
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _backupAllSuratToZipWeb,
                    icon: const Icon(Icons.cloud_download_outlined, size: 16),
                    label: const Text('Backup ZIP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : _confirmDeleteAllGlobal,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Hapus Semua'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 1),
          ),

          // Baris 2: Input Filter
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Cari Nama / NIS Siswa
                  SizedBox(
                    width: isNarrow ? constraints.maxWidth : 280,
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau NIS siswa...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  searchController.clear();
                                  _applyClientSearchFilter(resetPage: true);
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  // Filter Jenis Surat
                  SizedBox(
                    width: isNarrow ? (constraints.maxWidth - 12) / 2 : 170,
                    child: DropdownButtonFormField<String?>(
                      initialValue: selectedJenisSurat,
                      style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text("Semua Jenis"),
                        ),
                        ...jenisSuratList.map(
                          (jenis) => DropdownMenuItem<String?>(
                            value: jenis,
                            child: Text(jenis[0].toUpperCase() + jenis.substring(1)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => selectedJenisSurat = value);
                        fetchSurat();
                      },
                      decoration: InputDecoration(
                        labelText: 'Jenis Surat',
                        labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  // Dari Tanggal
                  SizedBox(
                    width: isNarrow ? (constraints.maxWidth - 12) / 2 : 180,
                    child: _buildDateFilter(
                      label: 'Dari Tanggal',
                      controller: _startDateCtrl,
                      currentValue: selectedStartDate,
                      onPicked: (date) {
                        setState(() => selectedStartDate = date);
                        fetchSurat();
                      },
                      onClear: () {
                        setState(() => selectedStartDate = null);
                        fetchSurat();
                      },
                    ),
                  ),

                  // Sampai Tanggal
                  SizedBox(
                    width: isNarrow ? (constraints.maxWidth - 12) / 2 : 180,
                    child: _buildDateFilter(
                      label: 'Sampai Tanggal',
                      controller: _endDateCtrl,
                      currentValue: selectedEndDate,
                      onPicked: (date) {
                        setState(() => selectedEndDate = date);
                        fetchSurat();
                      },
                      onClear: () {
                        setState(() => selectedEndDate = null);
                        fetchSurat();
                      },
                    ),
                  ),

                  // Tampilkan (Rows Per Page)
                  SizedBox(
                    width: isNarrow ? (constraints.maxWidth - 12) / 2 : 110,
                    child: DropdownButtonFormField<int>(
                      initialValue: _rowsPerPage,
                      style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                      decoration: InputDecoration(
                        labelText: 'Baris',
                        labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      items: const [5, 10, 20, 50]
                          .map(
                            (val) => DropdownMenuItem(
                              value: val,
                              child: Text('$val'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _rowsPerPage = val;
                          _currentPage = 1;
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter({
    required String label,
    required TextEditingController controller,
    required DateTime? currentValue,
    required ValueChanged<DateTime?> onPicked,
    required VoidCallback onClear,
  }) {
    return TextFormField(
      readOnly: true,
      controller: controller,
      style: const TextStyle(fontSize: 13),
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: currentValue ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2050),
          builder: (ctx, child) {
            return Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: AppColors.textDark,
                ),
              ),
              child: child!,
            );
          },
        );
        if (pickedDate != null) onPicked(pickedDate);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
        suffixIcon: currentValue != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: onClear,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildTableCard() {
    if (suratData.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_unread_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak Ada Data Surat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tidak ada surat yang sesuai dengan filter atau kata kunci saat ini.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final int startIndex = (_currentPage - 1) * _rowsPerPage;
    final int endIndex = min(startIndex + _rowsPerPage, suratData.length);

    if (startIndex >= suratData.length && suratData.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _currentPage = 1);
      });
      return const SizedBox.shrink();
    }

    final currentData = suratData.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table layout
          LayoutBuilder(
            builder: (context, constraints) {
              double minTableWidth = constraints.maxWidth;
              if (!minTableWidth.isFinite) minTableWidth = 0.0;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minTableWidth),
                  child: DataTable(
                    columnSpacing: 24,
                    horizontalMargin: 20,
                    headingRowHeight: 50,
                    dataRowMinHeight: 58,
                    dataRowMaxHeight: 58,
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF8FAFC),
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'NO',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'NIS',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'NAMA SISWA',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'TANGGAL SURAT',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'JENIS SURAT',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'AKSI',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                    rows: List.generate(currentData.length, (i) {
                      final s = currentData[i];
                      final rawTanggal = s['tanggal'];
                      final tanggal = rawTanggal == null
                          ? '-'
                          : DateFormat('dd MMM yyyy').format(
                              DateTime.parse(rawTanggal.toString()).toLocal(),
                            );
                      final int rowNumber = startIndex + i + 1;
                      final String jenis = (s['jenis'] ?? '').toString().toLowerCase();
                      final String displayNis = (s['siswa']?['nis'] ?? s['siswa_id'] ?? '-').toString();

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '$rowNumber',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                displayNis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    ((s['siswa']?['nama'] ?? 'S').toString().isNotEmpty)
                                        ? (s['siswa']?['nama'] ?? 'S').toString()[0].toUpperCase()
                                        : 'S',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${s['siswa']?['nama'] ?? '-'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_month_outlined,
                                  size: 15,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tanggal,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          DataCell(_buildJenisBadge(jenis)),
                          DataCell(
                            ElevatedButton.icon(
                              onPressed: () => _showDetailDialog(s),
                              icon: const Icon(Icons.visibility_rounded, size: 15),
                              label: const Text('Lihat'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                                foregroundColor: const Color(0xFF047857),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              );
            },
          ),

          const Divider(height: 1, thickness: 1),

          // Pagination Footer
          _buildPaginationFooter(),
        ],
      ),
    );
  }

  Widget _buildJenisBadge(String jenis) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String label;

    if (jenis == 'sakit') {
      bg = const Color(0xFFFEF3C7);
      border = const Color(0xFFFDE68A);
      text = const Color(0xFFB45309);
      icon = Icons.healing_rounded;
      label = 'Sakit';
    } else if (jenis == 'izin') {
      bg = const Color(0xFFE0F2FE);
      border = const Color(0xFFBAE6FD);
      text = const Color(0xFF0369A1);
      icon = Icons.assignment_outlined;
      label = 'Izin';
    } else {
      bg = Colors.grey.shade100;
      border = Colors.grey.shade300;
      text = Colors.grey.shade700;
      icon = Icons.description_outlined;
      label = jenis.isNotEmpty ? jenis : '-';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: text),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter() {
    if (suratData.isEmpty) return const SizedBox.shrink();

    final int totalPages = (suratData.length / _rowsPerPage).ceil();
    final int startItem = ((_currentPage - 1) * _rowsPerPage) + 1;
    final int endItem = min(_currentPage * _rowsPerPage, suratData.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(
            "Menampilkan $startItem - $endItem dari ${suratData.length} data surat",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Prev button
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            color: AppColors.primary,
            disabledColor: Colors.grey.shade300,
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
            tooltip: 'Halaman Sebelumnya',
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$_currentPage / $totalPages",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Next button
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            color: AppColors.primary,
            disabledColor: Colors.grey.shade300,
            onPressed: _currentPage < totalPages
                ? () => setState(() => _currentPage++)
                : null,
            tooltip: 'Halaman Berikutnya',
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> surat) {
    final rawTanggal = surat['tanggal'];
    final String tanggal = rawTanggal == null
        ? '-'
        : DateFormat(
            'EEEE, dd MMMM yyyy',
          ).format(DateTime.parse(rawTanggal.toString()).toLocal());

    final String fileUrl = (surat['file_url'] ?? '').toString();
    final bool hasFile = fileUrl.isNotEmpty;
    final String jenis = (surat['jenis'] ?? '').toString().toLowerCase();
    final String displayNis = (surat['siswa']?['nis'] ?? surat['siswa_id'] ?? '-').toString();

    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final double maxW = min(size.width * 0.85, 720);
        final double maxH = min(size.height * 0.8, 640);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Detail Surat Keterangan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              _buildJenisBadge(jenis),
            ],
          ),
          content: SizedBox(
            width: maxW,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('ID Surat', '#${surat['id'] ?? '-'}'),
                        const SizedBox(height: 6),
                        _buildDetailRow('NIS Siswa', displayNis),
                        const SizedBox(height: 6),
                        _buildDetailRow('Nama Siswa', '${surat['siswa']?['nama'] ?? '-'}'),
                        const SizedBox(height: 6),
                        _buildDetailRow('Tanggal Surat', tanggal),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Lampiran Foto / Dokumen',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!hasFile)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.hide_image_outlined,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tidak ada foto/lampiran surat.',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxW,
                          maxHeight: maxH * 0.65,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.network(
                              fileUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (c, child, progress) {
                                if (progress == null) return child;
                                return const Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (c, e, s) => Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(24),
                                color: Colors.grey.shade50,
                                child: const Text('Gagal memuat foto surat'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Tutup'),
                  ),
                ),
                if (hasFile) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        final filename = 'surat_${surat['id'] ?? 'file'}';
                        _handleDownload(fileUrl, filename);
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        const Text(': ', style: TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
