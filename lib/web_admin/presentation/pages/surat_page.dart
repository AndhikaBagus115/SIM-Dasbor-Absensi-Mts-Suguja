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
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _applyClientSearchFilter(resetPage: true);
    });
  }

  void _applyClientSearchFilter({bool resetPage = false}) {
    final keyword = searchController.text.trim().toLowerCase();

    final filtered = (keyword.isEmpty)
        ? List<Map<String, dynamic>>.from(_allSuratData)
        : _allSuratData.where((s) {
            final nama = (s['siswa']?['nama'] ?? '').toString().toLowerCase();
            return nama.contains(keyword);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      var query = supabase.from('surat').select('*, siswa(nama)');

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

      setState(() {
        _allSuratData = allData;
        _currentPage = 1;
        isLoading = false;
      });

      _applyClientSearchFilter(resetPage: false);
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackbar('Gagal memuat data surat: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllSuratForGlobalAction() async {
    final res = await supabase
        .from('surat')
        .select('id, siswa_id, tanggal, jenis, file_url, siswa(nama)')
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
      _showSnackbar('Backup berhasil: $zipName');
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

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('⚠️ HAPUS SEMUA DATA SURAT'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tindakan ini akan menghapus SEMUA data surat (DB) dan file di Storage.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text('• Total data: $total'),
                    Text('• Dengan file: $withFile'),
                    const SizedBox(height: 12),
                    Text(
                      'Hapus bersifat PERMANEN dan tidak bisa dikembalikan.',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ketik "HAPUS SEMUA" untuk melanjutkan:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmCtrl,
                      autofocus: true,
                      onChanged: (v) {
                        setLocal(() {
                          canDelete = v.trim().toUpperCase() == 'HAPUS SEMUA';
                        });
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'HAPUS SEMUA',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.backup),
                  label: const Text('Backup ZIP'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _backupAllSuratToZipWeb();
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Hapus Permanen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
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
    int failedFiles = 0;

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
        } else {
          failedFiles++;
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
        'Selesai. DB: $deletedRows baris, Storage: $deletedFiles file, gagal-path: $failedFiles',
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
      _showSnackbar('Mengunduh dan mengkonversi gambar ke PDF...');
      try {
        final response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode != 200) {
          _showSnackbar(
            'Gagal mengambil gambar. Status: ${response.statusCode}',
          );
          return;
        }

        final imageBytes = response.bodyBytes;
        final pdf = pw.Document();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (_) =>
                pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
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
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 28),
            _buildFilter(),
            const SizedBox(height: 20),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Text(
              'Data Surat Siswa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.schoolName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                "Filter Data Surat",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 90,
                child: DropdownButtonFormField<int>(
                  initialValue: _rowsPerPage,
                  decoration: InputDecoration(
                    labelText: 'Show',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [5, 10, 20, 50]
                      .map(
                        (val) =>
                            DropdownMenuItem(value: val, child: Text('$val')),
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
              SizedBox(
                width: 220,
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
              SizedBox(
                width: 220,
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
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: selectedJenisSurat,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text("Semua Jenis"),
                    ),
                    ...jenisSuratList.map(
                      (jenis) => DropdownMenuItem<String?>(
                        value: jenis,
                        child: Text(jenis),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => selectedJenisSurat = value);
                    fetchSurat();
                  },
                  decoration: InputDecoration(
                    labelText: 'Jenis Surat',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 385,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Cari Nama Siswa',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _backupAllSuratToZipWeb,
                  icon: const Icon(Icons.backup),
                  label: const Text('Backup ZIP'),
                ),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _confirmDeleteAllGlobal,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Hapus Semua'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
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
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: currentValue ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2050),
        );
        if (pickedDate != null) onPicked(pickedDate);
      },
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(currentValue == null ? Icons.calendar_today : Icons.clear),
          onPressed: currentValue == null ? null : onClear,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (suratData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Tidak ada data surat ditemukan dengan filter saat ini.'),
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

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              double minTableWidth = constraints.maxWidth;
              if (!minTableWidth.isFinite) minTableWidth = 0.0;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minTableWidth),
                  child: DataTable(
                    columnSpacing: 24,
                    headingRowHeight: 56,
                    dataRowHeight: 64,
                    headingRowColor: WidgetStateProperty.all(
                      Colors.blue.shade50,
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'No',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'ID Siswa',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Nama Siswa',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Tanggal',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Jenis Surat',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Aksi',
                          style: TextStyle(fontWeight: FontWeight.bold),
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

                      return DataRow(
                        cells: [
                          DataCell(Text('$rowNumber')),
                          DataCell(Text('${s['siswa_id'] ?? '-'}')),
                          DataCell(Text('${s['siswa']?['nama'] ?? '-'}')),
                          DataCell(Text(tanggal)),
                          DataCell(Text('${s['jenis'] ?? '-'}')),
                          DataCell(
                            _buildAction(
                              Icons.visibility,
                              'Lihat',
                              Colors.green,
                              () => _showDetailDialog(s),
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
        ),
        const SizedBox(height: 20),
        _buildPaginationControls(),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildPaginationControls() {
    if (suratData.isEmpty) return const SizedBox.shrink();

    final int totalPages = (suratData.length / _rowsPerPage).ceil();
    final int startItem = ((_currentPage - 1) * _rowsPerPage) + 1;
    final int endItem = min(_currentPage * _rowsPerPage, suratData.length);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          "$startItem - $endItem dari ${suratData.length}",
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 1
              ? () => setState(() => _currentPage--)
              : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "$_currentPage",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < totalPages
              ? () => setState(() => _currentPage++)
              : null,
        ),
      ],
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

    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;

        final double maxW = min(size.width * 0.9, 1400);
        final double maxH = min(size.height * 0.75, 760);

        return AlertDialog(
          title: const Text('Detail Surat'),
          content: SizedBox(
            width: maxW,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('ID Surat:', '${surat['id'] ?? '-'}'),
                  _buildDetailRow('ID Siswa:', '${surat['siswa_id'] ?? '-'}'),
                  _buildDetailRow(
                    'Nama Siswa:',
                    '${surat['siswa']?['nama'] ?? '-'}',
                  ),
                  _buildDetailRow('Tanggal:', tanggal),
                  _buildDetailRow('Jenis Surat:', '${surat['jenis'] ?? '-'}'),
                  const SizedBox(height: 20),
                  const Text(
                    'Preview Surat',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (!hasFile)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text('Tidak ada foto surat.'),
                    )
                  else
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxW,
                          maxHeight: maxH,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            fileUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (c, child, progress) {
                              if (progress == null) return child;
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (c, e, s) => Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(16),
                              color: Colors.grey.shade100,
                              child: const Text('Gagal memuat foto surat'),
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
            horizontal: 24,
            vertical: 16,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasFile
                        ? () {
                            Navigator.of(context).pop();
                            final filename = 'surat_${surat['id'] ?? 'file'}';
                            _handleDownload(fileUrl, filename);
                          }
                        : null,
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: onPressed,
    );
  }
}
