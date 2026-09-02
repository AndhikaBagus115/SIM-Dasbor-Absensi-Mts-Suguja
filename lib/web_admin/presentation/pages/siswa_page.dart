import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../../logic/siswa_logic.dart';

class DataSiswaPage extends StatefulWidget {
  final String schoolName;
  final String? initialKelasId;

  const DataSiswaPage({
    super.key,
    required this.schoolName,
    this.initialKelasId,
  });

  @override
  State<DataSiswaPage> createState() => _DataSiswaPageState();
}

class _DataSiswaPageState extends State<DataSiswaPage> {
  // 1. Instance Logic & Controller
  late final DataSiswaLogic _logic;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 2. Inisialisasi Logic
    _logic = DataSiswaLogic();
    _logic.addListener(_onLogicUpdate); // Dengarkan perubahan data
    _logic.init(widget.initialKelasId); // Fetch data awal

    // Listener pencarian
    searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant DataSiswaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialKelasId != oldWidget.initialKelasId) {
      _logic.onKelasSelected(
        widget.initialKelasId != null ? int.tryParse(widget.initialKelasId!) : null,
        searchController.text,
      );
    }
  }

  void _onLogicUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onSearchChanged() {
    _logic.fetchSiswa(searchController.text);
  }

  @override
  void dispose() {
    _logic.removeListener(_onLogicUpdate);
    searchController.removeListener(_onSearchChanged);
    _logic.dispose();
    searchController.dispose();
    super.dispose();
  }

  // --- DIALOG & ACTIONS ---

  Future<void> _showDeleteConfirmDialog(int id, String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Apakah Anda yakin ingin menghapus data $nama?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final error = await _logic.deleteSiswa(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Data siswa berhasil dihapus'),
            backgroundColor: error == null ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showSiswaForm({Map<String, dynamic>? siswa}) {
    final isEdit = siswa != null;
    final TextEditingController nisController = TextEditingController(
      text: siswa?['nis'] ?? '',
    );
    final TextEditingController namaController = TextEditingController(
      text: siswa?['nama'] ?? '',
    );
    final TextEditingController ortuNamaController = TextEditingController(
      text: siswa?['orang_tua_nama'] ?? '',
    );
    final TextEditingController ortuNomorController = TextEditingController(
      text: siswa?['orang_tua_nomor'] ?? '',
    );

    int? kelasId = siswa?['kelas_id'];
    String? status = siswa?['status'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(isEdit ? "Edit Siswa" : "Tambah Siswa"),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nisController,
                    decoration: const InputDecoration(
                      labelText: 'NIS',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: kelasId,
                    hint: const Text('Pilih Kelas'),
                    decoration: const InputDecoration(
                      labelText: 'Kelas',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ..._logic.kelasList.map(
                        (k) => DropdownMenuItem(
                          value: k['id'] as int,
                          child: Text(k['nama_kelas']),
                        ),
                      ),
                    ],
                    onChanged: (val) => kelasId = val,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ortuNamaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Orang Tua',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ortuNomorController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor WA Orang Tua',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    hint: const Text('Pilih Status'),
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                      DropdownMenuItem(
                        value: 'tidak aktif',
                        child: Text('Tidak Aktif'),
                      ),
                      DropdownMenuItem(value: 'lulus', child: Text('Lulus')),
                    ],
                    onChanged: (val) => status = val,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final error = await _logic.saveSiswa(
                  isEdit: isEdit,
                  siswaId: siswa?['id'],
                  nis: nisController.text,
                  nama: namaController.text,
                  kelasId: kelasId,
                  ortuNama: ortuNamaController.text,
                  ortuNomor: ortuNomorController.text,
                  status: status,
                );

                if (dialogCtx.mounted && error == null) {
                  Navigator.pop(dialogCtx);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error ??
                            (isEdit
                                ? 'Data berhasil diperbarui'
                                : 'Data siswa berhasil ditambahkan'),
                      ),
                      backgroundColor: error == null ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: Text(isEdit ? "Simpan" : "Tambah"),
            ),
          ],
        );
      },
    );
  }

  void _showBarcodeDialog(Map<String, dynamic> siswa) {
    final String nis = siswa['nis']?.toString() ?? '';
    final String nama = siswa['nama'] ?? 'Nama Tidak Ditemukan';

    if (nis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Siswa ini tidak memiliki NIS.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ScreenshotController screenshotController = ScreenshotController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("QR Code Siswa"),
          content: SizedBox(
            width: 350,
            child: Screenshot(
              controller: screenshotController,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nama,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "NIS: $nis",
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    BarcodeWidget(
                      barcode: Barcode.qrCode(),
                      data: nis,
                      width: 250,
                      height: 250,
                      drawText: false,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("Unduh"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final bytes = await screenshotController.capture(
                  delay: const Duration(milliseconds: 10),
                );
                if (bytes != null) {
                  final safeFilename = nama
                      .replaceAll(' ', '_')
                      .replaceAll(RegExp(r'[^\w.-]'), '');

                  await _logic.downloadBarcode(
                    bytes,
                    '$safeFilename-qrcode.png',
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDialogKenaikanKelas() {
    int? sourceKelasId;
    int? targetKelasId;
    bool isLuluskan = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setStateDialog) {
            return AlertDialog(
              title: const Text("Proses Kenaikan Kelas Massal"),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Pindahkan semua siswa AKTIF dari kelas lama ke kelas baru.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Dari Kelas (Sumber)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: sourceKelasId,
                      hint: const Text("Pilih Kelas Asal (Misal: 7A)"),
                      items: _logic.kelasList.map((k) {
                        return DropdownMenuItem(
                          value: k['id'] as int,
                          child: Text(k['nama_kelas']),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setStateDialog(() => sourceKelasId = val),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      title: const Text("Luluskan Siswa (Untuk Kelas 9)"),
                      subtitle: const Text(
                        "Status siswa akan berubah menjadi 'Lulus'",
                      ),
                      value: isLuluskan,
                      onChanged: (val) {
                        setStateDialog(() {
                          isLuluskan = val ?? false;
                          if (isLuluskan) {
                            targetKelasId = null;
                          }
                        });
                      },
                    ),
                    if (!isLuluskan) ...[
                      const SizedBox(height: 10),
                      const Text(
                        "Ke Kelas (Tujuan)",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButtonFormField<int>(
                        initialValue: targetKelasId,
                        hint: const Text("Pilih Kelas Tujuan (Misal: 8A)"),
                        items: _logic.kelasList.map((k) {
                          return DropdownMenuItem(
                            value: k['id'] as int,
                            child: Text(k['nama_kelas']),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setStateDialog(() => targetKelasId = val),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (sourceKelasId == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Pilih kelas asal!")),
                        );
                      }
                      return;
                    }
                    if (!isLuluskan && targetKelasId == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Pilih kelas tujuan!")),
                        );
                      }
                      return;
                    }

                    await _logic.prosesKenaikanKelas(
                      sourceKelasId: sourceKelasId!,
                      targetKelasId: targetKelasId,
                      isLuluskan: isLuluskan,
                    );

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Proses berhasil!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Text(
                    isLuluskan ? "Proses Kelulusan" : "Proses Pindah",
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showLulusConfirmDialog(int id, String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Kelulusan'),
        content: Text(
          'Apakah Anda yakin ingin meluluskan siswa **$nama**?\n\n'
          'Status siswa akan berubah menjadi Lulus dan tidak akan muncul di absensi harian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ya, Luluskan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final error = await _logic.updateStatusSiswa(id, 'lulus');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Siswa berhasil diluluskan'),
            backgroundColor: error == null ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showSiswaForm(),
                  icon: const Icon(Icons.add),
                  label: const Text("Tambah Siswa"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _logic.importExcel(context),
                  icon: const Icon(Icons.file_upload),
                  label: const Text("Import Excel"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showDialogKenaikanKelas(),
                  icon: const Icon(Icons.drive_file_move),
                  label: const Text("Kenaikan Kelas"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _logic.selectedKelasId == null
                      ? null
                      : () => _logic.generateBarcodePdf(context),
                  icon: const Icon(Icons.print),
                  label: const Text("Cetak QR Code Kelas"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            _buildFilter(),
            const SizedBox(height: 20),

            _logic.isLoading
                ? const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _buildTable(),
            const SizedBox(height: 20),
            _buildPagination(),
            const SizedBox(height: 50),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Data Siswa',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.school, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.schoolName,
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
                "Filter Data Siswa",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _logic.isKelasLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Memuat filter..."),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: DropdownButtonFormField<int>(
                        initialValue: _logic.itemLimit,
                        decoration: InputDecoration(
                          labelText: 'Show',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: [5, 10, 15, 20, 50, 100]
                            .map(
                              (val) => DropdownMenuItem(
                                value: val,
                                child: Text(val.toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _logic.updateLimit(val, searchController.text);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        initialValue: _logic.selectedKelasId,
                        hint: const Text("Semua Kelas"),
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Kelas',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text("Semua Kelas"),
                          ),
                          ..._logic.kelasList.map(
                            (kelas) => DropdownMenuItem<int>(
                              value: kelas['id'] as int,
                              child: Text(
                                kelas['nama_kelas'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          _logic.onKelasSelected(value, searchController.text);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText: 'Cari Nama',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _logic.selectedStatus,
                        hint: const Text("Semua Status"),
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text("Semua")),
                          DropdownMenuItem(
                            value: "aktif",
                            child: Text("Aktif"),
                          ),
                          DropdownMenuItem(
                            value: "tidak aktif",
                            child: Text("Tdk Aktif"),
                          ),
                          DropdownMenuItem(
                            value: "lulus",
                            child: Text("Lulus"),
                          ),
                        ],
                        onChanged: (value) {
                          _logic.onStatusSelected(value, searchController.text);
                        },
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_logic.siswaData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.folder_off_outlined, size: 60, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'Tidak ada data siswa ditemukan.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final ScrollController horizontalController = ScrollController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
              return Scrollbar(
                controller: horizontalController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columnSpacing: 24,
                      headingRowHeight: 56,
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 64,
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
                            'NIS',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Nama',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Kelas',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Nama Ortu',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'No. Ortu',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
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
                      rows: List.generate(_logic.siswaData.length, (i) {
                        final s = _logic.siswaData[i];
                        final int rowNumber =
                            ((_logic.currentPage - 1) * _logic.itemLimit) +
                            i +
                            1;

                        final String namaKelas =
                            (s['kelas']?['nama_kelas'] ?? '')
                                .toString()
                                .toUpperCase();

                        final bool isKelasAkhir =
                            namaKelas.contains('9') || namaKelas.contains('IX');

                        final bool isAktif = s['status'] == 'aktif';

                        return DataRow(
                          cells: [
                            DataCell(Text('$rowNumber')),
                            DataCell(Text('${s['nis'] ?? '-'}')),
                            DataCell(
                              Text(
                                '${s['nama'] ?? '-'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(Text(namaKelas.isEmpty ? '-' : namaKelas)),
                            DataCell(Text('${s['orang_tua_nama'] ?? '-'}')),
                            DataCell(Text('${s['orang_tua_nomor'] ?? '-'}')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isAktif
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : (s['status'] == 'lulus'
                                            ? Colors.purple.withValues(alpha: 0.1)
                                            : Colors.red.withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isAktif
                                        ? Colors.green
                                        : (s['status'] == 'lulus'
                                              ? Colors.purple
                                              : Colors.red),
                                  ),
                                ),
                                child: Text(
                                  (s['status'] ?? '-').toString().toUpperCase(),
                                  style: TextStyle(
                                    color: isAktif
                                        ? Colors.green
                                        : (s['status'] == 'lulus'
                                              ? Colors.purple
                                              : Colors.red),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildAction(
                                    Icons.qr_code_2,
                                    'QR Code',
                                    Colors.teal,
                                    () => _showBarcodeDialog(s),
                                  ),
                                  const SizedBox(width: 4),
                                  _buildAction(
                                    Icons.edit,
                                    'Edit Data',
                                    Colors.blue,
                                    () => _showSiswaForm(siswa: s),
                                  ),
                                  const SizedBox(width: 4),
                                  if (isAktif && isKelasAkhir) ...[
                                    _buildAction(
                                      Icons.school,
                                      'Luluskan Siswa',
                                      Colors.purple,
                                      () => _showLulusConfirmDialog(
                                        s['id'],
                                        s['nama'],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if (!isAktif) ...[
                                    _buildAction(
                                      Icons.restore,
                                      'Aktifkan Kembali',
                                      Colors.green,
                                      () => _logic.updateStatusSiswa(
                                        s['id'],
                                        'aktif',
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  _buildAction(
                                    Icons.delete,
                                    'Hapus Data',
                                    Colors.red,
                                    () => _showDeleteConfirmDialog(
                                      s['id'],
                                      s['nama'],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          _logic.paginationInfo,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: "Sebelumnya",
            onPressed: _logic.currentPage > 1
                ? () => _logic.previousPage(searchController.text)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            "${_logic.currentPage}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: "Selanjutnya",
            onPressed: _logic.currentPage < _logic.totalPages
                ? () => _logic.nextPage(searchController.text)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAction(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
