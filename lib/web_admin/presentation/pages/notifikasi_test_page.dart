import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/onesignal_service.dart';
import '../../data/models/pengumuman_model.dart';

class NotifikasiTestPage extends StatefulWidget {
  final String schoolName;

  const NotifikasiTestPage({super.key, required this.schoolName});

  @override
  State<NotifikasiTestPage> createState() => _NotifikasiTestPageState();
}

class _NotifikasiTestPageState extends State<NotifikasiTestPage>
    with SingleTickerProviderStateMixin {
  late TabController _mainTabController;

  // Controllers for Pengumuman
  final TextEditingController _pengumumanJudulController =
      TextEditingController();
  final TextEditingController _pengumumanIsiController =
      TextEditingController();
  final TextEditingController _searchRiwayatController =
      TextEditingController();

  // Controllers for Presensi Simulation & Direct Testing
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pushTitleController =
      TextEditingController(text: 'Uji Coba Push Notifikasi');
  final TextEditingController _pushMessageController = TextEditingController(
      text: 'Halo! Ini adalah pesan uji coba Push Notification dari Web Admin.');
  final TextEditingController _customNoteController = TextEditingController();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Loading States
  bool _isLoading = false;
  bool _isSendingPengumuman = false;
  bool _isSearching = false;
  bool _isLoadingKelas = false;
  bool _isLoadingKelasSiswa = false;
  bool _isLoadingRiwayat = false;
  bool _isTablePengumumanMissing = false;

  // Target Selections for Pengumuman
  String _targetTipe = 'semua'; // 'semua' | 'kelas' | 'siswa'
  int? _selectedKelasId;
  String? _selectedKelasNama;
  List<Map<String, dynamic>> _daftarKelas = [];
  List<Map<String, dynamic>> _kelasSiswaList = [];

  // Pengumuman Channel Selection
  NotificationChannel _selectedPengumumanChannel = NotificationChannel.onesignal;

  // Riwayat Pengumuman List
  List<Pengumuman> _riwayatPengumuman = [];
  String _searchRiwayatQuery = '';

  // Student Search Results & Selection
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedStudent;

  // Presensi Simulation State
  NotificationChannel _selectedChannel = NotificationChannel.both;
  NotificationType _selectedType = NotificationType.absent;
  String _selectedAbsentReason = 'Alpa (Tanpa Keterangan)';

  // Execution Log Output
  String _logOutput = '';

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 3, vsync: this);

    _customNoteController.addListener(_onStateChanged);
    _pengumumanJudulController.addListener(_onStateChanged);
    _pengumumanIsiController.addListener(_onStateChanged);
    _searchRiwayatController.addListener(() {
      setState(() {
        _searchRiwayatQuery = _searchRiwayatController.text.trim();
      });
    });

    _fetchKelas();
    _fetchRiwayatPengumuman();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _pengumumanJudulController.dispose();
    _pengumumanIsiController.dispose();
    _searchRiwayatController.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    _pushTitleController.dispose();
    _pushMessageController.dispose();
    _customNoteController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    setState(() {
      _logOutput = '[$timestamp] $message\n$_logOutput';
    });
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // DATA FETCHING METHODS
  // ============================================================

  Future<void> _fetchKelas() async {
    setState(() => _isLoadingKelas = true);
    try {
      final response = await _supabase
          .from('kelas')
          .select('id, nama_kelas')
          .order('nama_kelas');

      setState(() {
        _daftarKelas = List<Map<String, dynamic>>.from(response);
        _isLoadingKelas = false;
      });
    } catch (e) {
      _addLog('[PERINGATAN] Gagal memuat daftar kelas: $e');
      setState(() => _isLoadingKelas = false);
    }
  }

  Future<void> _onKelasChanged(int? kelasId) async {
    setState(() {
      _selectedKelasId = kelasId;
      _kelasSiswaList = [];
      _isLoadingKelasSiswa = true;
      if (kelasId != null) {
        final match = _daftarKelas.firstWhere(
          (k) => k['id'] == kelasId,
          orElse: () => {'nama_kelas': 'Kelas $kelasId'},
        );
        _selectedKelasNama = match['nama_kelas'] as String?;
      } else {
        _selectedKelasNama = null;
      }
    });

    if (kelasId == null) {
      setState(() => _isLoadingKelasSiswa = false);
      return;
    }

    try {
      final response = await _supabase
          .from('siswa')
          .select('id, nis, nama, orang_tua_nama, orang_tua_nomor')
          .eq('kelas_id', kelasId)
          .eq('status', 'aktif')
          .order('nama');

      setState(() {
        _kelasSiswaList = List<Map<String, dynamic>>.from(response);
        _isLoadingKelasSiswa = false;
      });

      _addLog(
        '[INFO] Kelas $_selectedKelasNama dipilih: ${_kelasSiswaList.length} siswa aktif ditemukan.',
      );
    } catch (e) {
      _addLog('[ERROR] Gagal memuat siswa kelas $kelasId: $e');
      setState(() => _isLoadingKelasSiswa = false);
    }
  }

  Future<void> _fetchRiwayatPengumuman() async {
    setState(() => _isLoadingRiwayat = true);
    try {
      final response = await _supabase
          .from('pengumuman')
          .select()
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((e) => Pengumuman.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _riwayatPengumuman = list;
        _isLoadingRiwayat = false;
        _isTablePengumumanMissing = false;
      });
    } catch (e) {
      _addLog('[PERINGATAN] Riwayat pengumuman: $e');
      setState(() {
        _isLoadingRiwayat = false;
        if (e.toString().contains('does not exist') ||
            e.toString().contains('42P01')) {
          _isTablePengumumanMissing = true;
        }
      });
    }
  }

  Future<void> _searchStudents(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await _supabase
          .from('siswa')
          .select(
              'id, nis, nama, orang_tua_nama, orang_tua_nomor, status, kelas(nama_kelas)')
          .or('nama.ilike.%$query%,nis.ilike.%$query%')
          .eq('status', 'aktif')
          .limit(10);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
        _isSearching = false;
      });
    } catch (e) {
      _addLog('[ERROR] Gagal mencari siswa: $e');
      setState(() => _isSearching = false);
    }
  }

  void _selectStudent(Map<String, dynamic> student) {
    setState(() {
      _selectedStudent = student;
      _searchController.text = student['nama'] ?? '';
      _searchResults = [];
    });
    _addLog('[INFO] Siswa dipilih: ${student['nama']} (ID: ${student['id']})');
  }

  void _clearSelection() {
    setState(() {
      _selectedStudent = null;
      _searchController.clear();
      _searchResults = [];
    });
  }

  // ============================================================
  // PENGUMUMAN ACTIONS
  // ============================================================

  Future<void> _sendPengumuman() async {
    final judul = _pengumumanJudulController.text.trim();
    final isi = _pengumumanIsiController.text.trim();

    if (judul.isEmpty) {
      _showSnackbar('Judul pengumuman tidak boleh kosong', isError: true);
      return;
    }
    if (isi.isEmpty) {
      _showSnackbar('Isi pengumuman tidak boleh kosong', isError: true);
      return;
    }

    if (_targetTipe == 'kelas' && _selectedKelasId == null) {
      _showSnackbar('Pilih kelas tujuan pengumuman terlebih dahulu',
          isError: true);
      return;
    }

    if (_targetTipe == 'siswa' && _selectedStudent == null) {
      _showSnackbar('Pilih siswa tujuan pengumuman terlebih dahulu',
          isError: true);
      return;
    }

    setState(() => _isSendingPengumuman = true);

    String targetNama = 'Semua Wali Murid';
    String? targetId;

    if (_targetTipe == 'kelas') {
      targetId = _selectedKelasId.toString();
      targetNama = _selectedKelasNama ?? 'Kelas $_selectedKelasId';
    } else if (_targetTipe == 'siswa') {
      targetId = (_selectedStudent!['id']).toString();
      targetNama = _selectedStudent!['nama'] ?? 'Siswa';
    }

    _addLog('[INFO] Memulai pengiriman pengumuman: "$judul"');
    _addLog('[INFO] Target: [$_targetTipe] $targetNama (ID: ${targetId ?? "ALL"})');
    _addLog('[INFO] Jalur: ${_selectedPengumumanChannel.displayName}');

    // 1. Simpan ke Supabase Tabel `pengumuman`
    try {
      final newRecord = {
        'judul': judul,
        'isi': isi,
        'target_tipe': _targetTipe,
        'target_id': targetId,
        'target_nama': targetNama,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase.from('pengumuman').insert(newRecord);
      _addLog('[SUKSES] Berhasil menyimpan pengumuman ke database Supabase');
    } catch (e) {
      _addLog('[PERINGATAN] Gagal menyimpan ke tabel `pengumuman`: $e');
    }

    // 2. Kirim via OneSignal REST API
    List<String>? studentExternalIds;
    int? targetSiswaId;
    int? targetKelasId;

    if (_targetTipe == 'siswa') {
      targetSiswaId = _selectedStudent!['id'] as int;
      studentExternalIds = ['$targetSiswaId'];
    } else if (_targetTipe == 'kelas') {
      targetKelasId = _selectedKelasId;
      studentExternalIds =
          _kelasSiswaList.map((s) => (s['id']).toString()).toList();
    }

    if (_selectedPengumumanChannel == NotificationChannel.onesignal ||
        _selectedPengumumanChannel == NotificationChannel.both) {
      final pushResult = await OneSignalService.sendPengumumanPush(
        judul: judul,
        isi: isi,
        targetTipe: _targetTipe,
        siswaId: targetSiswaId,
        kelasId: targetKelasId,
        studentExternalIds: studentExternalIds,
      );

      _addLog(pushResult.success
          ? '[SUKSES] OneSignal Push: ${pushResult.message}'
          : '[GAGAL] OneSignal Push: ${pushResult.message}');
    }

    // 3. Kirim via WhatsApp (WAHA) jika dipilih
    if (_selectedPengumumanChannel == NotificationChannel.whatsapp ||
        _selectedPengumumanChannel == NotificationChannel.both) {
      if (_targetTipe == 'siswa') {
        final phone = _selectedStudent!['orang_tua_nomor'] as String?;
        if (phone != null && phone.trim().isNotEmpty) {
          final waMsg = '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

*PENGUMUMAN RESMI SEKOLAH*
*${widget.schoolName}*

*Judul:* *$judul*
Ditujukan untuk: *${_selectedStudent!['nama']}* (NIS: ${_selectedStudent!['nis'] ?? '-'})

$isi

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Pusat Informasi ${widget.schoolName}_''';

          final waOk = await NotificationService.sendDirectWhatsApp(
            phoneNumber: phone,
            message: waMsg,
          );
          _addLog(waOk
              ? '[SUKSES] WhatsApp: Terkirim ke no $phone'
              : '[GAGAL] WhatsApp: Gagal kirim ke no $phone');
        } else {
          _addLog('[PERINGATAN] WhatsApp: Nomor orang tua siswa ini tidak tersedia');
        }
      } else if (_targetTipe == 'kelas') {
        int waSentCount = 0;
        for (final s in _kelasSiswaList) {
          final phone = s['orang_tua_nomor'] as String?;
          if (phone != null && phone.trim().isNotEmpty) {
            final waMsg = '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

*PENGUMUMAN RESMI KELAS $_selectedKelasNama*
*${widget.schoolName}*

*Judul:* *$judul*
Siswa: *${s['nama']}*

$isi

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Pusat Informasi ${widget.schoolName}_''';

            await NotificationService.sendDirectWhatsApp(
              phoneNumber: phone,
              message: waMsg,
            );
            waSentCount++;
            await Future.delayed(const Duration(milliseconds: 150));
          }
        }
        _addLog(
            '[SUKSES] WhatsApp: Berhasil dikirim ke $waSentCount orang tua siswa kelas $_selectedKelasNama');
      } else {
        _addLog(
            '[INFO] WhatsApp: Broadcast ke semua wali murid dilakukan bertahap/via OneSignal Push.');
      }
    }

    _showSnackbar('Pengumuman berhasil diproses dan dikirimkan!');
    _pengumumanJudulController.clear();
    _pengumumanIsiController.clear();
    await _fetchRiwayatPengumuman();

    setState(() => _isSendingPengumuman = false);
  }

  Future<void> _deletePengumuman(Pengumuman item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Hapus Pengumuman?'),
          ],
        ),
        content: Text(
          'Pengumuman "${item.judul}" akan dihapus dari riwayat database.\nTindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('pengumuman').delete().eq('id', item.id);
      _showSnackbar('Pengumuman "${item.judul}" berhasil dihapus');
      _addLog('[INFO] Pengumuman ID ${item.id} ("${item.judul}") dihapus dari database');
      await _fetchRiwayatPengumuman();
    } catch (e) {
      _showSnackbar('Gagal menghapus pengumuman: $e', isError: true);
      _addLog('[ERROR] Gagal menghapus pengumuman: $e');
    }
  }

  // ============================================================
  // PRESENSI SIMULATION ACTIONS
  // ============================================================

  Future<void> _sendNotificationToSelectedStudent() async {
    if (_selectedStudent == null) {
      _showSnackbar('Pilih siswa terlebih dahulu', isError: true);
      return;
    }

    final siswaId = _selectedStudent!['id'] as int;
    final nama = _selectedStudent!['nama'] as String? ?? 'Siswa';
    final parentPhone = _selectedStudent!['orang_tua_nomor'] as String?;
    final customNote = _customNoteController.text.trim();
    final alasan =
        _selectedType == NotificationType.absent ? _selectedAbsentReason : null;

    setState(() => _isLoading = true);
    _addLog(
        '[INFO] Memulai pengiriman presensi [${_selectedType.displayName}] via [${_selectedChannel.displayName}]');
    _addLog('[INFO] Target: $nama (ID: $siswaId, No. Ortu: ${parentPhone ?? "-"})');
    if (alasan != null) {
      _addLog('[INFO] Alasan Ketidakhadiran: $alasan');
    }
    if (customNote.isNotEmpty) {
      _addLog('[INFO] Pesan untuk Orang Tua: "$customNote"');
    }

    try {
      final result = await NotificationService.testNotificationBySiswaId(
        siswaId: siswaId,
        schoolName: widget.schoolName,
        type: _selectedType,
        channel: _selectedChannel,
        customMessage: customNote.isNotEmpty ? customNote : null,
        alasan: alasan,
      );

      final details = (result['details'] as List<dynamic>?) ?? [];
      for (final detail in details) {
        _addLog('[DETAIL] $detail');
      }

      final success = result['success'] == true;
      _addLog(success
          ? '[SUKSES] Pengiriman presensi selesai dengan sukses'
          : '[PERINGATAN] Pengiriman presensi selesai dengan kendala');

      _showSnackbar(
        result['message'] as String? ?? 'Selesai diproses',
        isError: !success,
      );
    } catch (e) {
      _addLog('[ERROR] $e');
      _showSnackbar('Error: $e', isError: true);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testWahaConnection() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackbar('Masukkan nomor WhatsApp tujuan terlebih dahulu',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);
    _addLog('[INFO] Menguji koneksi WAHA ke nomor: $phone');

    try {
      final success = await NotificationService.testWahaConnection(
        testPhoneNumber: phone,
      );

      _addLog(success
          ? '[SUKSES] BERHASIL kirim pesan test WhatsApp ke $phone'
          : '[GAGAL] GAGAL kirim pesan test WhatsApp ke $phone');

      _showSnackbar(
        success
            ? 'Pesan test WhatsApp berhasil terkirim!'
            : 'Gagal mengirim pesan WhatsApp',
        isError: !success,
      );
    } catch (e) {
      _addLog('[ERROR] WAHA: $e');
      _showSnackbar('Error WAHA: $e', isError: true);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testOneSignalConnection() async {
    setState(() => _isLoading = true);
    _addLog('[INFO] Memeriksa kredensial OneSignal API...');

    try {
      final result = await NotificationService.testOneSignalConnection();
      final success = result['success'] == true;
      final msg = result['message'] as String? ?? '';

      _addLog(success ? '[SUKSES] $msg' : '[GAGAL] $msg');
      _showSnackbar(msg, isError: !success);
    } catch (e) {
      _addLog('[ERROR] Validasi OneSignal: $e');
      _showSnackbar('Error OneSignal: $e', isError: true);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _sendTestBroadcastPush() async {
    final title = _pushTitleController.text.trim();
    final message = _pushMessageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      _showSnackbar('Judul dan isi push notification tidak boleh kosong',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);
    _addLog('[INFO] Mengirim Broadcast Push Notification ke semua perangkat...');

    try {
      final result = await OneSignalService.sendBroadcastPush(
        title: title,
        message: message,
        data: {'test_broadcast': true},
      );

      _addLog(result.success ? '[SUKSES] ${result.message}' : '[GAGAL] ${result.message}');
      _showSnackbar(result.message, isError: !result.success);
    } catch (e) {
      _addLog('[ERROR] Broadcast Push: $e');
      _showSnackbar('Error: $e', isError: true);
    }

    setState(() => _isLoading = false);
  }

  // ============================================================
  // BUILD METHOD & ROOT UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isWahaReady = AppConstants.isWahaConfigured;
    final isOneSignalReady = AppConstants.isOneSignalConfigured;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(
              isWahaReady: isWahaReady,
              isOneSignalReady: isOneSignalReady,
            ),
            const SizedBox(height: 16),
            _buildMainTabBar(),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _mainTabController,
                children: [
                  // TAB 1: Kirim Pengumuman & Riwayat
                  _buildPengumumanTab(),

                  // TAB 2: Simulasi Notifikasi Presensi Siswa
                  _buildPresensiNotificationTab(),

                  // TAB 3: Uji Gateway
                  _buildGatewayDiagnosticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER & TAB BAR
  // ============================================================

  Widget _buildHeader(
      {required bool isWahaReady, required bool isOneSignalReady}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.campaign_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pusat Notifikasi & Pengumuman Sekolah',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kirim pengumuman resmi ke seluruh wali murid, per kelas, atau siswa tertentu via OneSignal Push & WhatsApp',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // Gateway Status Badges
          Row(
            children: [
              _buildStatusBadge(
                label: 'WAHA (WA)',
                isReady: isWahaReady,
                activeColor: const Color(0xFF25D366),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(
                label: 'OneSignal Push',
                isReady: isOneSignalReady,
                activeColor: const Color(0xFFE54B4D),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required bool isReady,
    required Color activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isReady
            ? activeColor.withValues(alpha: 0.2)
            : Colors.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReady ? activeColor : Colors.amber,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isReady ? activeColor : Colors.amber,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ${isReady ? "Siap" : "Belum Setup"}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isReady ? Colors.white : Colors.amber.shade200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TabBar(
        controller: _mainTabController,
        labelColor: const Color(0xFF4F46E5),
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: const Color(0xFF4F46E5),
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
        tabs: const [
          Tab(
            icon: Icon(Icons.campaign_rounded, size: 18),
            text: 'Kirim Pengumuman & Riwayat',
          ),
          Tab(
            icon: Icon(Icons.co_present_rounded, size: 18),
            text: 'Notifikasi Presensi Siswa',
          ),
          Tab(
            icon: Icon(Icons.settings_input_component_rounded, size: 18),
            text: 'Uji Koneksi Gateway',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 1: PENGUMUMAN UTAMA & RIWAYAT
  // ============================================================

  Widget _buildPengumumanTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Form Kirim Pengumuman
              Expanded(
                flex: 6,
                child: _buildPengumumanFormCard(),
              ),
              const SizedBox(width: 20),
              // Right Column: Live Logs & Info Card
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildLogCard(height: 380),
                    const SizedBox(height: 16),
                    _buildOneSignalInfoCard(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Bottom Section: Tabel Riwayat Pengumuman
          _buildRiwayatPengumumanCard(),
        ],
      ),
    );
  }

  Widget _buildPengumumanFormCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Color(0xFF4F46E5), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kirim Notifikasi / Pengumuman Siswa',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Pilih target penerima (Semua / Kelas / Siswa), tulis pengumuman, lalu kirim ke OneSignal & WA',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // 1. Target Selector
            const Text(
              '1. Pilih Target Pengiriman:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTargetOption(
                    tipe: 'semua',
                    icon: Icons.public_rounded,
                    title: 'Semua Wali Murid',
                    subtitle: 'Broadcast ke seluruh aplikasi',
                    color: const Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTargetOption(
                    tipe: 'kelas',
                    icon: Icons.class_outlined,
                    title: 'Per Kelas',
                    subtitle: 'Spesifik satu rombel kelas',
                    color: const Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTargetOption(
                    tipe: 'siswa',
                    icon: Icons.person_outline_rounded,
                    title: 'Siswa Tertentu',
                    subtitle: 'Khusus 1 anak/wali murid',
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 1.B Target Specific Detail Container
            if (_targetTipe == 'semua') ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF4F46E5), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pengumuman akan dikirim ke seluruh HP wali murid yang memasang aplikasi (Segment: Total Subscriptions).',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF3730A3)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_targetTipe == 'kelas') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Kelas Tujuan:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E)),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingKelas
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<int>(
                            initialValue: _selectedKelasId,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFF99F6E4)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFCCFBF1)),
                              ),
                            ),
                            hint: const Text('Pilih Kelas (Contoh: Kelas 8A)'),
                            items: _daftarKelas.map((k) {
                              return DropdownMenuItem<int>(
                                value: k['id'] as int,
                                child: Text(k['nama_kelas'] ?? "-"),
                              );
                            }).toList(),
                            onChanged: _onKelasChanged,
                          ),
                    if (_selectedKelasId != null) ...[
                      const SizedBox(height: 10),
                      _isLoadingKelasSiswa
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Row(
                              children: [
                                const Icon(Icons.people_alt_outlined,
                                    size: 16, color: Color(0xFF0F766E)),
                                const SizedBox(width: 6),
                                Text(
                                  'Total ${_kelasSiswaList.length} siswa di $_selectedKelasNama (External IDs: [${_kelasSiswaList.map((e) => e['id']).take(4).join(', ')}${_kelasSiswaList.length > 4 ? "..." : ""}])',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF115E59),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ],
                ),
              ),
            ] else if (_targetTipe == 'siswa') ...[
              // Search Box Siswa
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Cari Nama atau NIS Siswa',
                  hintText: 'Ketik nama siswa untuk memilih...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _selectedStudent != null
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: _clearSelection,
                        )
                      : _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                  filled: true,
                  fillColor: const Color(0xFFFFFBEB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                  ),
                ),
                onChanged: (value) {
                  if (_selectedStudent != null) _clearSelection();
                  _searchStudents(value);
                },
                enabled: _selectedStudent == null,
              ),

              if (_searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final student = _searchResults[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFFEF3C7),
                          child: const Icon(Icons.person,
                              size: 16, color: Color(0xFFD97706)),
                        ),
                        title: Text(student['nama'] ?? '-',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'NIS: ${student['nis'] ?? '-'} • Kelas: ${student['kelas']?['nama_kelas'] ?? '-'} • Ortu: ${student['orang_tua_nama'] ?? '-'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => _selectStudent(student),
                      );
                    },
                  ),
                ),

              if (_selectedStudent != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedStudent!['nama']} (ID: ${_selectedStudent!['id']}, Kelas: ${_selectedStudent!['kelas']?['nama_kelas'] ?? "-"})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _clearSelection,
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: Color(0xFFD97706)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 16),

            // 2. Channel Selector
            const Text(
              '2. Pilih Jalur Pengiriman:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPengumumanChannelOption(
                    channel: NotificationChannel.onesignal,
                    icon: Icons.phone_iphone_rounded,
                    title: 'Push App (OneSignal)',
                    subtitle: 'Bebas ban, langsung ke HP',
                    activeColor: const Color(0xFFE54B4D),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPengumumanChannelOption(
                    channel: NotificationChannel.whatsapp,
                    icon: Icons.chat_rounded,
                    title: 'WhatsApp (WAHA)',
                    subtitle: 'Chat langsung ke ortu',
                    activeColor: const Color(0xFF25D366),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPengumumanChannelOption(
                    channel: NotificationChannel.both,
                    icon: Icons.all_inclusive_rounded,
                    title: 'Keduanya (Hybrid)',
                    subtitle: 'Push + WA bersamaan',
                    activeColor: const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 3. Judul Pengumuman
            Row(
              children: [
                const Text(
                  '3. Judul Pengumuman:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Contoh Judul Cepat:',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildQuickTitleChip('Pemberitahuan Kegiatan Sekolah'),
                _buildQuickTitleChip('Informasi Penilaian Tengah Semester'),
                _buildQuickTitleChip('Libur Hari Raya & Cuti Bersama'),
                _buildQuickTitleChip('Undangan Rapat Wali Murid'),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pengumumanJudulController,
              maxLength: 100,
              decoration: InputDecoration(
                hintText:
                    'Contoh: Undangan Rapat Pleno Wali Murid Tahun Ajaran Baru',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                suffixIcon: _pengumumanJudulController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => _pengumumanJudulController.clear(),
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 10),

            // 4. Isi Pengumuman
            Row(
              children: [
                const Text(
                  '4. Isi Pengumuman:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                if (_pengumumanIsiController.text.isNotEmpty)
                  InkWell(
                    onTap: () => _pengumumanIsiController.clear(),
                    child: const Text(
                      'Kosongkan Isi',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildQuickIsiChip(
                  'Dimohon kehadiran Bapak/Ibu Wali Murid pada acara Rapat Pleno Sekolah yang akan dilaksanakan hari Sabtu pukul 08.00 WIB.',
                ),
                _buildQuickIsiChip(
                  'Diberitahukan bahwa Kegiatan Belajar Mengajar (KBM) pada hari Senin ditiadakan sehubungan dengan agenda Rapat Dinas Guru.',
                ),
                _buildQuickIsiChip(
                  'Ujian Penilaian Akhir Semester (PAS) akan dimulai pada tanggal 10. Mohon bimbingan belajar siswa di rumah.',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pengumumanIsiController,
              maxLines: 4,
              maxLength: 600,
              decoration: InputDecoration(
                hintText:
                    'Tuliskan isi pengumuman atau instruksi lengkap yang akan diterima oleh wali murid...',
                alignLabelWithHint: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Live Preview Card
            _buildPengumumanLivePreviewBox(),

            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSendingPengumuman ? null : _sendPengumuman,
                icon: _isSendingPengumuman
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _isSendingPengumuman
                      ? 'Sedang Mengirim Pengumuman...'
                      : _targetTipe == 'semua'
                          ? 'Kirim Pengumuman ke Semua Wali Murid'
                          : _targetTipe == 'kelas'
                              ? 'Kirim Pengumuman ke ${_selectedKelasNama ?? "Kelas"}'
                              : 'Kirim Pengumuman ke ${_selectedStudent?['nama'] ?? "Siswa"}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetOption({
    required String tipe,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _targetTipe == tipe;

    return InkWell(
      onTap: () => setState(() => _targetTipe = tipe),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: isSelected ? color : Colors.grey.shade600),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, size: 16, color: color)
                else
                  Icon(Icons.radio_button_unchecked,
                      size: 16, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: isSelected ? color : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPengumumanChannelOption({
    required NotificationChannel channel,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color activeColor,
  }) {
    final isSelected = _selectedPengumumanChannel == channel;

    return InkWell(
      onTap: () => setState(() => _selectedPengumumanChannel = channel),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: isSelected ? activeColor : Colors.grey.shade600),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, size: 16, color: activeColor)
                else
                  Icon(Icons.radio_button_unchecked,
                      size: 16, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? activeColor : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTitleChip(String title) {
    return InkWell(
      onTap: () {
        setState(() {
          _pengumumanJudulController.text = title;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF334155)),
        ),
      ),
    );
  }

  Widget _buildQuickIsiChip(String text) {
    return InkWell(
      onTap: () {
        setState(() {
          _pengumumanIsiController.text = text;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline,
                size: 11, color: Color(0xFF4F46E5)),
            const SizedBox(width: 4),
            Text(
              text.length > 42 ? '${text.substring(0, 42)}...' : text,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPengumumanLivePreviewBox() {
    final judul = _pengumumanJudulController.text.trim().isEmpty
        ? 'Judul Pengumuman Sekolah'
        : _pengumumanJudulController.text.trim();
    final isi = _pengumumanIsiController.text.trim().isEmpty
        ? 'Isi pengumuman yang dituliskan akan muncul di sini...'
        : _pengumumanIsiController.text.trim();

    String targetLabel = 'Semua Wali Murid';
    if (_targetTipe == 'kelas') {
      targetLabel = _selectedKelasNama ?? 'Kelas Tertentu';
    } else if (_targetTipe == 'siswa') {
      targetLabel = _selectedStudent?['nama'] ?? 'Siswa Tertentu';
    }

    final isPushActive =
        _selectedPengumumanChannel == NotificationChannel.onesignal ||
            _selectedPengumumanChannel == NotificationChannel.both;
    final isWaActive =
        _selectedPengumumanChannel == NotificationChannel.whatsapp ||
            _selectedPengumumanChannel == NotificationChannel.both;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye_outlined,
                  size: 16, color: Color(0xFF475569)),
              const SizedBox(width: 8),
              const Text(
                'Pratinjau Pesan yang Diterima Wali Murid:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  'Target: $targetLabel',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Push Notification Card Preview
          if (isPushActive) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.campaign_rounded,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                judul,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const Text(
                              'Baru saja',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isi,
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF334155),
                              height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isWaActive && isPushActive) const SizedBox(height: 8),

          // WhatsApp Bubble Preview
          if (isWaActive) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F8E8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: SelectableText(
                '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

*PENGUMUMAN RESMI SEKOLAH*
*${widget.schoolName}*

*Judul:* *$judul*
[INFO] Target: $targetLabel

$isi

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Pusat Informasi ${widget.schoolName}_''',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.4,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // TABEL RIWAYAT PENGUMUMAN (PRECISE FULL-WIDTH FLEX TABLE)
  // ============================================================

  Widget _buildRiwayatPengumumanCard() {
    final filteredList = _riwayatPengumuman.where((p) {
      if (_searchRiwayatQuery.isEmpty) return true;
      final q = _searchRiwayatQuery.toLowerCase();
      return p.judul.toLowerCase().contains(q) ||
          p.isi.toLowerCase().contains(q) ||
          (p.targetNama?.toLowerCase().contains(q) ?? false) ||
          p.targetTipe.toLowerCase().contains(q);
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history_edu_rounded,
                      color: Color(0xFF0F172A), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Riwayat Pengumuman Terkirim',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: Text(
                              '${_riwayatPengumuman.length} Pengumuman',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Daftar pengumuman yang tersimpan di Supabase dan telah didistribusikan ke wali murid',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _fetchRiwayatPengumuman,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Segarkan Riwayat',
                ),
              ],
            ),
            const Divider(height: 24),

            // Search Bar & Filter
            TextField(
              controller: _searchRiwayatController,
              decoration: InputDecoration(
                hintText:
                    'Cari berdasarkan judul, isi, atau target pengumuman...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchRiwayatQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => _searchRiwayatController.clear(),
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_isTablePengumumanMissing) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_rounded, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Text(
                          'Tabel `pengumuman` belum ditemukan di Supabase',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tabel `pengumuman` diperlukan untuk menyimpan riwayat. Klik tombol di bawah untuk melihat skrip SQL pembuatan tabel dan menjalankannya di Supabase SQL Editor.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _showSqlDialog,
                      icon: const Icon(Icons.code_rounded, size: 16),
                      label: const Text('Lihat / Salin Skrip SQL Tabel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Full-Width Flex Table Content
            if (_isLoadingRiwayat)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredList.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign_outlined,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      _searchRiwayatQuery.isNotEmpty
                          ? 'Tidak ada pengumuman yang cocok dengan pencarian "$_searchRiwayatQuery"'
                          : 'Belum ada pengumuman yang dikirim',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gunakan formulir di atas untuk mengirimkan pengumuman pertama Anda.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Header Row
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 35,
                            child: Text(
                              'No',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF334155)),
                            ),
                          ),
                          SizedBox(width: 12),
                          SizedBox(
                            width: 135,
                            child: Text(
                              'Tanggal',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF334155)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Judul Pengumuman',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF334155)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: Text(
                              'Isi Pengumuman',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF334155)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Target Pengiriman',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF334155)),
                            ),
                          ),
                          SizedBox(width: 12),
                          SizedBox(
                            width: 105,
                            child: Text(
                              'Dibuat Oleh',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF334155)),
                            ),
                          ),
                          SizedBox(width: 12),
                          SizedBox(
                            width: 75,
                            child: Center(
                              child: Text(
                                'Aksi',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF334155)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body Rows
                    ...List.generate(filteredList.length, (index) {
                      final item = filteredList[index];
                      final dateStr = DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
                          .format(item.createdAt);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: index % 2 == 0
                              ? Colors.white
                              : const Color(0xFFF8FAFC),
                          border: Border(
                            bottom: BorderSide(
                              color: index == filteredList.length - 1
                                  ? Colors.transparent
                                  : Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 35,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    fontSize: 12.5, color: Color(0xFF64748B)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 135,
                              child: Text(
                                dateStr,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF475569)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.judul,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Text(
                                item.isi,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF475569),
                                    height: 1.3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildTargetBadge(
                                    item.targetTipe, item.targetNama),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 105,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shield_outlined,
                                          size: 11, color: Color(0xFF475569)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Admin Web',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF334155)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 75,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 18,
                                        color: Color(0xFF4F46E5)),
                                    tooltip: 'Lihat Isi Lengkap',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    onPressed: () =>
                                        _showDetailPengumumanDialog(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Color(0xFFDC2626)),
                                    tooltip: 'Hapus Pengumuman',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    onPressed: () => _deletePengumuman(item),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetBadge(String targetTipe, String? targetNama) {
    Color bg;
    Color text;
    IconData icon;
    String label = targetNama ?? targetTipe;

    switch (targetTipe.toLowerCase()) {
      case 'semua':
        bg = const Color(0xFFEEF2FF);
        text = const Color(0xFF4338CA);
        icon = Icons.public_rounded;
        label = targetNama ?? 'Semua Wali Murid';
        break;
      case 'kelas':
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF047857);
        icon = Icons.class_outlined;
        label = targetNama != null && targetNama.isNotEmpty
            ? targetNama
            : 'Kelas';
        break;
      case 'siswa':
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFB45309);
        icon = Icons.person_outline_rounded;
        label = targetNama != null && targetNama.isNotEmpty
            ? targetNama
            : 'Siswa';
        break;
      default:
        bg = Colors.grey.shade100;
        text = Colors.grey.shade800;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: text.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: text),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailPengumumanDialog(Pengumuman p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.campaign_rounded,
                  color: Color(0xFF4F46E5), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                p.judul,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd MMMM yyyy, HH:mm WIB', 'id_ID')
                          .format(p.createdAt),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Target Penerima: ',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    _buildTargetBadge(p.targetTipe, p.targetNama),
                  ],
                ),
                const Divider(height: 24),
                const Text('Isi Pengumuman Lengkap:',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    p.isi,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showSqlDialog() {
    const sqlText = '''CREATE TABLE IF NOT EXISTS public.pengumuman (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  judul TEXT NOT NULL,
  isi TEXT NOT NULL,
  target_tipe TEXT NOT NULL CHECK (target_tipe IN ('semua', 'kelas', 'siswa')),
  target_id TEXT NULL,
  target_nama TEXT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.pengumuman ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read pengumuman" ON public.pengumuman FOR SELECT TO public USING (true);
CREATE POLICY "Allow authenticated insert pengumuman" ON public.pengumuman FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow authenticated delete pengumuman" ON public.pengumuman FOR DELETE TO public USING (true);''';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.code_rounded, color: Color(0xFF4F46E5)),
            SizedBox(width: 10),
            Text('Skrip SQL Tabel Pengumuman'),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jalankan perintah SQL ini di Supabase Dashboard -> SQL Editor:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const SelectableText(
                  sqlText,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF4ADE80)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildOneSignalInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.hub_outlined, color: Color(0xFFE54B4D), size: 18),
                SizedBox(width: 8),
                Text(
                  'Aturan ID OneSignal Mobile',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 18),
            _buildInfoBullet('Target Semua',
                'Segment: "Total Subscriptions" (Semua HP Terdaftar)'),
            const SizedBox(height: 6),
            _buildInfoBullet('Target Siswa',
                'External User ID = String id siswa (contoh: "94")'),
            const SizedBox(height: 6),
            _buildInfoBullet('Target Kelas',
                'External User ID = Array id siswa sekelas (contoh: ["94", "95"])'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBullet(String label, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TAB 2: SIMULASI NOTIFIKASI PRESENSI SISWA
  // ============================================================

  Widget _buildPresensiNotificationTab() {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Presensi Form Card
          Expanded(
            flex: 6,
            child: _buildStudentPresensiCard(),
          ),
          const SizedBox(width: 20),
          // Right Column: Live Terminal Logs
          Expanded(
            flex: 4,
            child: _buildLogCard(height: 600),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentPresensiCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.co_present_rounded,
                      color: Color(0xFF4F46E5), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifikasi Presensi Siswa Individual',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Pilih siswa, status presensi (Hadir/Tidak Hadir/Sakit/Izin), dan sampaikan pesan khusus ke orang tua',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Search Student Box
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari Nama atau NIS Siswa',
                hintText: 'Ketik minimal 1 huruf untuk mencari...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _selectedStudent != null
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: _clearSelection,
                      )
                    : _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (value) {
                if (_selectedStudent != null) _clearSelection();
                _searchStudents(value);
              },
              enabled: _selectedStudent == null,
            ),

            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = _searchResults[index];
                    final hasPhone = student['orang_tua_nomor'] != null &&
                        (student['orang_tua_nomor'] as String).isNotEmpty;

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: hasPhone
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        child: Icon(
                          hasPhone
                              ? Icons.person_rounded
                              : Icons.person_off_rounded,
                          size: 16,
                          color: hasPhone
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      title: Text(
                        student['nama'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'NIS: ${student['nis'] ?? '-'} • Kelas: ${student['kelas']?['nama_kelas'] ?? '-'} • Ortu: ${student['orang_tua_nama'] ?? '-'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: hasPhone
                          ? Text(
                              student['orang_tua_nomor'],
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w500),
                            )
                          : const Text('Tanpa No WA',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                      onTap: () => _selectStudent(student),
                    );
                  },
                ),
              ),

            if (_selectedStudent != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF4F46E5), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedStudent!['nama'] ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF312E81),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _clearSelection,
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: Color(0xFF4F46E5)),
                          tooltip: 'Batalkan pilihan',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildInfoPill(
                            'NIS: ${_selectedStudent!['nis'] ?? '-'}'),
                        const SizedBox(width: 8),
                        _buildInfoPill(
                            'Kelas: ${_selectedStudent!['kelas']?['nama_kelas'] ?? '-'}'),
                        const SizedBox(width: 8),
                        _buildInfoPill(
                            'Ortu: ${_selectedStudent!['orang_tua_nama'] ?? '-'}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 1. Channel Selector
            const Text(
              'Pilih Jalur Pengiriman (Notification Channel)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPresensiChannelOption(
                    channel: NotificationChannel.onesignal,
                    icon: Icons.phone_iphone_rounded,
                    title: 'Push App (OneSignal)',
                    subtitle: 'Bebas ban, cepat, hemat',
                    activeColor: const Color(0xFFE54B4D),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPresensiChannelOption(
                    channel: NotificationChannel.whatsapp,
                    icon: Icons.chat_rounded,
                    title: 'WhatsApp (WAHA)',
                    subtitle: 'Pesan chat langsung',
                    activeColor: const Color(0xFF25D366),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPresensiChannelOption(
                    channel: NotificationChannel.both,
                    icon: Icons.all_inclusive_rounded,
                    title: 'Keduanya (Hybrid)',
                    subtitle: 'WA + Push bersamaan',
                    activeColor: const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 2. Notification Type Selector
            const Text(
              'Tipe Notifikasi Presensi',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<NotificationType>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              items: NotificationType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(
                        type == NotificationType.present
                            ? Icons.check_circle_outline
                            : type == NotificationType.late
                                ? Icons.access_time
                                : type == NotificationType.absent
                                    ? Icons.cancel_outlined
                                    : Icons.home_outlined,
                        size: 18,
                        color: type == NotificationType.present
                            ? Colors.green
                            : type == NotificationType.late
                                ? Colors.orange
                                : type == NotificationType.absent
                                    ? Colors.red
                                    : Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      Text(type.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedType = value);
              },
            ),

            // 3. Custom Message & Absent Reason Section
            if (_selectedType == NotificationType.absent)
              _buildAbsentCustomMessageSection()
            else
              _buildGenericCustomMessageSection(),

            // 4. Live Message Preview Box
            _buildMessagePreviewBox(),

            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _selectedStudent == null
                    ? null
                    : _sendNotificationToSelectedStudent,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _isLoading
                      ? 'Sedang Mengirim...'
                      : 'Kirim Notifikasi ke ${_selectedStudent?['nama'] ?? 'Siswa'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsentCustomMessageSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.mark_chat_unread_rounded,
                  color: Color(0xFFB45309),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pesan & Catatan untuk Orang Tua (Siswa Tidak Hadir)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    Text(
                      'Kustomisasi alasan dan pesan tindak lanjut yang dikirim ke orang tua',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Status Alasan Chips
          const Text(
            'Kategori / Status Alasan:',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF78350F)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAbsentReasonChip('Alpa (Tanpa Keterangan)',
                  Icons.cancel_outlined, const Color(0xFFDC2626)),
              _buildAbsentReasonChip('Sakit', Icons.medical_services_outlined,
                  const Color(0xFFD97706)),
              _buildAbsentReasonChip('Izin',
                  Icons.assignment_turned_in_outlined, const Color(0xFF2563EB)),
              _buildAbsentReasonChip('Dispensasi', Icons.school_outlined,
                  const Color(0xFF7C3AED)),
            ],
          ),

          const SizedBox(height: 14),

          // Template Cepat
          Row(
            children: [
              const Icon(Icons.flash_on_rounded,
                  size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 4),
              const Text(
                'Template Pesan Cepat (Klik untuk memilih):',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF78350F)),
              ),
              const Spacer(),
              if (_customNoteController.text.isNotEmpty)
                InkWell(
                  onTap: () => _customNoteController.clear(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'Kosongkan',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPresensiTemplateChip(
                  'Mohon kirimkan surat keterangan sakit/dokter kepada wali kelas.'),
              _buildPresensiTemplateChip(
                  'Ananda belum hadir di sekolah hari ini tanpa pemberitahuan. Mohon konfirmasinya.'),
              _buildPresensiTemplateChip(
                  'Mohon Bapak/Ibu segera menghubungi pihak sekolah atau wali kelas.'),
              _buildPresensiTemplateChip(
                  'Diharapkan orang tua memastikan ananda dapat hadir kembali besok.'),
            ],
          ),

          const SizedBox(height: 14),

          // Text Input Pesan
          TextField(
            controller: _customNoteController,
            maxLines: 3,
            maxLength: 350,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Pesan Tambahan untuk Orang Tua',
              hintText:
                  'Ketik pesan tambahan atau arahan khusus untuk orang tua siswa di sini...',
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFCD34D)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFD97706), width: 1.5),
              ),
              suffixIcon: _customNoteController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () => _customNoteController.clear(),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsentReasonChip(String reason, IconData icon, Color color) {
    final isSelected = _selectedAbsentReason == reason;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedAbsentReason = reason;
          if (_customNoteController.text.isEmpty) {
            if (reason == 'Sakit') {
              _customNoteController.text =
                  'Mohon kirimkan surat keterangan sakit/dokter kepada wali kelas.';
            } else if (reason == 'Izin') {
              _customNoteController.text =
                  'Mohon konfirmasi surat izin tertulis kepada pihak sekolah/wali kelas.';
            } else if (reason == 'Alpa (Tanpa Keterangan)') {
              _customNoteController.text =
                  'Ananda belum hadir di sekolah hari ini tanpa kabar keterangan. Mohon konfirmasinya.';
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: isSelected ? color : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              reason,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresensiTemplateChip(String text) {
    return InkWell(
      onTap: () {
        setState(() {
          _customNoteController.text = text;
          _customNoteController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline_rounded,
                size: 12, color: Color(0xFFD97706)),
            const SizedBox(width: 4),
            Text(
              text.length > 40 ? '${text.substring(0, 40)}...' : text,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericCustomMessageSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: TextField(
        controller: _customNoteController,
        maxLines: 2,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: 'Pesan Tambahan untuk Orang Tua (Opsional)',
          hintText: 'Tulis catatan khusus jika diperlukan...',
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          suffixIcon: _customNoteController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () => _customNoteController.clear(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildMessagePreviewBox() {
    final studentName = _selectedStudent?['nama'] ?? '[Nama Siswa]';
    final customNote = _customNoteController.text.trim();
    final reason =
        _selectedType == NotificationType.absent ? _selectedAbsentReason : null;

    final isWaActive = _selectedChannel == NotificationChannel.whatsapp ||
        _selectedChannel == NotificationChannel.both;
    final isPushActive = _selectedChannel == NotificationChannel.onesignal ||
        _selectedChannel == NotificationChannel.both;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.remove_red_eye_outlined,
                    size: 16, color: Color(0xFF475569)),
                const SizedBox(width: 8),
                const Text(
                  'Pratinjau Pesan Presensi yang Dikirimkan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    _selectedChannel.displayName,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (isWaActive) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_rounded,
                          size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      const Text(
                        'Format WhatsApp:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _selectedStudent?['orang_tua_nomor'] != null &&
                                (_selectedStudent!['orang_tua_nomor'] as String)
                                    .isNotEmpty
                            ? 'No: ${_selectedStudent!['orang_tua_nomor']}'
                            : 'Tanpa Nomor WA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _selectedStudent?['orang_tua_nomor'] != null &&
                                  (_selectedStudent!['orang_tua_nomor']
                                          as String)
                                      .isNotEmpty
                              ? const Color(0xFF16A34A)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F8E8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(0),
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SelectableText(
                      NotificationService.formatWhatsAppPreview(
                        studentName: studentName,
                        type: _selectedType,
                        schoolName: widget.schoolName,
                        customMessage:
                            customNote.isNotEmpty ? customNote : null,
                        alasan: reason,
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        height: 1.4,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPushActive) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.phone_iphone_rounded,
                          size: 14, color: Color(0xFFDC2626)),
                      SizedBox(width: 6),
                      Text(
                        'Format Push Notifikasi (HP Ortu):',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.notifications_active,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      NotificationService.formatPushTitlePreview(
                                        studentName: studentName,
                                        type: _selectedType,
                                        alasan: reason,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'Baru saja',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                NotificationService.formatPushPreview(
                                  studentName: studentName,
                                  type: _selectedType,
                                  schoolName: widget.schoolName,
                                  customMessage:
                                      customNote.isNotEmpty ? customNote : null,
                                  alasan: reason,
                                ),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF334155),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresensiChannelOption({
    required NotificationChannel channel,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color activeColor,
  }) {
    final isSelected = _selectedChannel == channel;

    return InkWell(
      onTap: () => setState(() => _selectedChannel = channel),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: isSelected ? activeColor : Colors.grey.shade600),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, size: 16, color: activeColor)
                else
                  Icon(Icons.radio_button_unchecked,
                      size: 16, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? activeColor : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF3730A3),
            fontWeight: FontWeight.w500),
      ),
    );
  }

  // ============================================================
  // TAB 3: UJI KONEKSI GATEWAY
  // ============================================================

  Widget _buildGatewayDiagnosticsTab() {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: _buildDirectTestingTabs(),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 4,
            child: _buildLogCard(height: 500),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectTestingTabs() {
    return DefaultTabController(
      length: 2,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TabBar(
                labelColor: Color(0xFF1E293B),
                unselectedLabelColor: Color(0xFF94A3B8),
                indicatorColor: Color(0xFF4F46E5),
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: Icon(Icons.phone_iphone_rounded, size: 18),
                    text: 'Uji OneSignal Push',
                  ),
                  Tab(
                    icon: Icon(Icons.chat_rounded, size: 18),
                    text: 'Uji WhatsApp Direct',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: TabBarView(
                  children: [
                    // Tab 1: OneSignal Push Test
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _pushTitleController,
                                decoration: const InputDecoration(
                                  labelText: 'Judul Push',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed:
                                  _isLoading ? null : _testOneSignalConnection,
                              icon: const Icon(Icons.sync_rounded, size: 16),
                              label: const Text('Cek API'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE54B4D),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _pushMessageController,
                          decoration: const InputDecoration(
                            labelText: 'Pesan Push Notification',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isLoading ? null : _sendTestBroadcastPush,
                            icon: const Icon(Icons.cell_tower_rounded,
                                size: 18),
                            label: const Text(
                                'Kirim Test Push Broadcast (Semua User App)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE54B4D),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Tab 2: WhatsApp Test
                    Column(
                      children: [
                        TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor WhatsApp Tujuan',
                            hintText: '08123456789 atau 628123456789',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Mengirim pesan test verifikasi server WAHA gateway langsung ke nomor WhatsApp di atas.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isLoading ? null : _testWahaConnection,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('Kirim Test Pesan WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOG CARD
  // ============================================================

  Widget _buildLogCard({double height = 400}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.terminal_rounded,
                      color: Colors.greenAccent, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Live Execution Log',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _logOutput = ''),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: 'Bersihkan log',
                ),
              ],
            ),
            const Divider(height: 16),
            SizedBox(
              height: height,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _logOutput.isEmpty
                        ? 'Menunggu aksi pengiriman notifikasi / pengumuman...\nSemua respons WhatsApp & OneSignal akan dicatat secara langsung di sini.'
                        : _logOutput,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.5,
                      color: _logOutput.isEmpty
                          ? Colors.grey
                          : const Color(0xFF4ADE80),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
