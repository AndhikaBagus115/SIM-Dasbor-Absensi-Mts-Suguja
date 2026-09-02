import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/onesignal_service.dart';
import '../../data/models/pengumuman_model.dart';
import '../widgets/notifikasi/gateway_diagnostics_card.dart';
import '../widgets/notifikasi/notifikasi_dialogs.dart';
import '../widgets/notifikasi/pengumuman_form_card.dart';
import '../widgets/notifikasi/presensi_simulation_card.dart';
import '../widgets/notifikasi/riwayat_pengumuman_card.dart';

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

  void _onKelasChanged(int? kelasId) {
    setState(() {
      _selectedKelasId = kelasId;
      if (kelasId != null) {
        final k = _daftarKelas.firstWhere(
          (item) => item['id'] == kelasId,
          orElse: () => {'nama_kelas': 'Kelas $kelasId'},
        );
        _selectedKelasNama = k['nama_kelas'] as String?;
      } else {
        _selectedKelasNama = null;
      }
      _kelasSiswaList = [];
    });

    if (kelasId != null) {
      _fetchSiswaByKelas(kelasId);
    }
  }

  Future<void> _fetchSiswaByKelas(int kelasId) async {
    setState(() => _isLoadingKelasSiswa = true);
    try {
      final response = await _supabase
          .from('siswa')
          .select('id, nis, nama, orang_tua_nomor')
          .eq('kelas_id', kelasId)
          .eq('status', 'aktif');

      setState(() {
        _kelasSiswaList = List<Map<String, dynamic>>.from(response);
        _isLoadingKelasSiswa = false;
      });
      _addLog(
          '[INFO] Memuat ${_kelasSiswaList.length} siswa aktif di kelas $_selectedKelasNama');
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
    _addLog(
        '[INFO] Target: [$_targetTipe] $targetNama (ID: ${targetId ?? "ALL"})');
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
          _addLog(
              '[PERINGATAN] WhatsApp: Nomor orang tua siswa ini tidak tersedia');
        }
      } else if (_targetTipe == 'kelas') {
        int waSentCount = 0;
        for (final s in _kelasSiswaList) {
          final phone = s['orang_tua_nomor'] as String?;
          if (phone != null && phone.trim().isNotEmpty) {
            final waMsg = '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

*PENGUMUMAN KELAS ($_selectedKelasNama)*
*${widget.schoolName}*

*Judul:* *$judul*
Untuk: *${s['nama']}*

$isi

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Pusat Informasi ${widget.schoolName}_''';

            final ok = await NotificationService.sendDirectWhatsApp(
              phoneNumber: phone,
              message: waMsg,
            );
            if (ok) waSentCount++;
          }
        }
        _addLog(
            '[INFO] WhatsApp: Selesai mengirim ke $waSentCount dari ${_kelasSiswaList.length} wali murid di $_selectedKelasNama');
      } else {
        _addLog(
            '[INFO] WhatsApp: Broadcast ke semua wali murid via WhatsApp dilewati untuk mencegah banned nomor. Gunakan OneSignal Push.');
      }
    }

    setState(() => _isSendingPengumuman = false);
    _showSnackbar('Pengumuman berhasil diproses dan dikirim!');

    _pengumumanJudulController.clear();
    _pengumumanIsiController.clear();
    _fetchRiwayatPengumuman();
  }

  Future<void> _deletePengumuman(Pengumuman item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text(
            'Apakah Anda yakin ingin menghapus pengumuman "${item.judul}" dari riwayat?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('pengumuman').delete().eq('id', item.id);
      _addLog('[SUKSES] Pengumuman ID ${item.id} berhasil dihapus');
      _showSnackbar('Pengumuman berhasil dihapus');
      _fetchRiwayatPengumuman();
    } catch (e) {
      _addLog('[ERROR] Gagal menghapus pengumuman: $e');
      _showSnackbar('Gagal menghapus: $e', isError: true);
    }
  }

  // ============================================================
  // PRESENSI SIMULATION ACTIONS
  // ============================================================

  Future<void> _sendPresensiTest() async {
    final studentName = _selectedStudent?['nama'] ?? 'Ahmad Fadhil';
    final studentId = _selectedStudent?['id'] as int? ?? 1;
    final parentPhone = _phoneController.text.trim().isNotEmpty
        ? _phoneController.text.trim()
        : (_selectedStudent?['orang_tua_nomor'] as String? ?? '081234567890');
    final customNote = _customNoteController.text.trim();

    _addLog(
        '[START] Memulai simulasi notifikasi presensi untuk: $studentName (ID: $studentId)');
    _addLog('[CONFIG] Status: ${_selectedType.displayName}');
    _addLog('[CONFIG] Jalur: ${_selectedChannel.displayName}');

    setState(() => _isLoading = true);

    try {
      final ok = await NotificationService.sendNotificationToParent(
        siswaId: studentId,
        studentName: studentName,
        parentPhoneNumber: parentPhone,
        type: _selectedType,
        channel: _selectedChannel,
        schoolName: widget.schoolName,
        customMessage: customNote.isNotEmpty ? customNote : null,
        alasan: _selectedType == NotificationType.absent
            ? _selectedAbsentReason
            : null,
      );

      _addLog('--- HASIL PENGIRIMAN ---');
      _addLog(ok
          ? '✅ [SUKSES] ${_selectedChannel.displayName}: Notifikasi terkirim'
          : '❌ [GAGAL] ${_selectedChannel.displayName}: Pengiriman gagal');

      _showSnackbar(
        ok
            ? 'Notifikasi presensi berhasil dikirim!'
            : 'Gagal mengirim notifikasi. Cek panel execution log.',
        isError: !ok,
      );
    } catch (e) {
      _addLog('[CRITICAL ERROR] $e');
      _showSnackbar('Terjadi kesalahan: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // GATEWAY DIAGNOSTICS ACTIONS
  // ============================================================

  Future<void> _testOneSignalConnection() async {
    _addLog('[DIAGNOSTIK] Memeriksa status konfigurasi OneSignal REST API...');
    final isConfigured = OneSignalService.isConfigured;
    _addLog('[CONFIG] OneSignal App ID: ${AppConstants.onesignalAppId}');
    _addLog('[CONFIG] REST API Key: ${AppConstants.onesignalRestApiKey.isNotEmpty ? "Tersedia (${AppConstants.onesignalRestApiKey.length} karakter)" : "KOSONG"}');

    if (!isConfigured) {
      _addLog(
          '[PERINGATAN] OneSignal belum terkonfigurasi lengkap di constants.dart!');
      _showSnackbar('OneSignal belum lengkap dikonfigurasi', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final ok = await OneSignalService.verifyConnection();
      _addLog(ok
          ? '[SUKSES] Koneksi ke OneSignal REST API berhasil & valid!'
          : '[GAGAL] Respon OneSignal tidak valid atau API Key salah');
      _showSnackbar(ok
          ? 'Koneksi OneSignal valid!'
          : 'Verifikasi OneSignal gagal. Cek log.');
    } catch (e) {
      _addLog('[ERROR] $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestBroadcastPush() async {
    final title = _pushTitleController.text.trim().isEmpty
        ? 'Test Notifikasi'
        : _pushTitleController.text.trim();
    final message = _pushMessageController.text.trim().isEmpty
        ? 'Pesan uji coba push notifikasi dari Web Admin'
        : _pushMessageController.text.trim();

    _addLog('[START] Mengirim push broadcast ke semua user: "$title"');
    setState(() => _isLoading = true);

    try {
      final result = await OneSignalService.sendBroadcastPush(
        title: title,
        message: message,
        data: {
          'source': 'web_admin_test_page',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _addLog(result.success
          ? '[SUKSES] Broadcast OneSignal: ${result.message} (ID: ${result.notificationId})'
          : '[GAGAL] Broadcast OneSignal: ${result.message}');
      _showSnackbar(result.message, isError: !result.success);
    } catch (e) {
      _addLog('[ERROR] $e');
      _showSnackbar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testWahaConnection() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackbar('Masukkan nomor WhatsApp tujuan uji coba', isError: true);
      return;
    }

    _addLog('[START] Mengirim pesan uji coba WAHA ke nomor: $phone');
    setState(() => _isLoading = true);

    try {
      final testMsg =
          'Halo! Ini adalah pesan uji coba koneksi gateway WhatsApp dari Web Admin SIM Absensi ${widget.schoolName}. [Waktu: ${DateTime.now().toString().split('.')[0]}]';

      final ok = await NotificationService.sendDirectWhatsApp(
        phoneNumber: phone,
        message: testMsg,
      );

      _addLog(ok
          ? '[SUKSES] Pesan WhatsApp berhasil dikirim ke $phone'
          : '[GAGAL] Gagal mengirim pesan via WAHA gateway');
      _showSnackbar(
        ok ? 'Pesan WhatsApp terkirim!' : 'Gagal kirim via WAHA',
        isError: !ok,
      );
    } catch (e) {
      _addLog('[ERROR] $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // UI BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isWahaReady = NotificationService.isWahaConfigured;
    final isOneSignalReady = OneSignalService.isConfigured;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(
                isWahaReady: isWahaReady,
                isOneSignalReady: isOneSignalReady,
              ),

              const SizedBox(height: 20),

              // Tab Bar Navigation
              _buildMainTabBar(),

              const SizedBox(height: 20),

              // Tab Content Area
              AnimatedBuilder(
                animation: _mainTabController,
                builder: (context, _) {
                  switch (_mainTabController.index) {
                    case 0:
                      return _buildPengumumanTab();
                    case 1:
                      return _buildPresensiTab();
                    case 2:
                      return _buildDiagnosticsTab();
                    default:
                      return _buildPengumumanTab();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildPengumumanTab() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Form Pengumuman
            Expanded(
              flex: 6,
              child: PengumumanFormCard(
                judulController: _pengumumanJudulController,
                isiController: _pengumumanIsiController,
                searchController: _searchController,
                targetTipe: _targetTipe,
                onTargetTipeChanged: (val) => setState(() {
                  _targetTipe = val;
                  _selectedStudent = null;
                }),
                selectedKelasId: _selectedKelasId,
                selectedKelasNama: _selectedKelasNama,
                daftarKelas: _daftarKelas,
                isLoadingKelas: _isLoadingKelas,
                onKelasChanged: _onKelasChanged,
                kelasSiswaList: _kelasSiswaList,
                isLoadingKelasSiswa: _isLoadingKelasSiswa,
                selectedStudent: _selectedStudent,
                searchResults: _searchResults,
                isSearching: _isSearching,
                onSearchStudents: _searchStudents,
                onSelectStudent: _selectStudent,
                onClearStudent: _clearSelection,
                selectedChannel: _selectedPengumumanChannel,
                onChannelChanged: (NotificationChannel c) =>
                    setState(() => _selectedPengumumanChannel = c),
                isSending: _isSendingPengumuman,
                onSendPengumuman: _sendPengumuman,
                schoolName: widget.schoolName,
              ),
            ),
            const SizedBox(width: 20),
            // Right Column: Live Logs & Info Card
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  ExecutionLogCard(
                    logOutput: _logOutput,
                    onClearLogs: () => setState(() => _logOutput = ''),
                    height: 380,
                  ),
                  const SizedBox(height: 16),
                  const OneSignalInfoCard(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Bottom Section: Tabel Riwayat Pengumuman
        RiwayatPengumumanCard(
          riwayatList: _riwayatPengumuman,
          searchQuery: _searchRiwayatQuery,
          searchController: _searchRiwayatController,
          isLoading: _isLoadingRiwayat,
          isTableMissing: _isTablePengumumanMissing,
          onRefresh: _fetchRiwayatPengumuman,
          onShowDetail: (p) => DetailPengumumanDialog.show(context, p),
          onDelete: _deletePengumuman,
          onShowSqlDialog: () => SqlSchemaDialog.show(context),
        ),
      ],
    );
  }

  Widget _buildPresensiTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Presensi Form
        Expanded(
          flex: 6,
          child: PresensiSimulationCard(
            searchController: _searchController,
            phoneController: _phoneController,
            customNoteController: _customNoteController,
            selectedStudent: _selectedStudent,
            searchResults: _searchResults,
            isSearching: _isSearching,
            onSearchStudents: _searchStudents,
            onSelectStudent: _selectStudent,
            onClearStudent: _clearSelection,
            selectedChannel: _selectedChannel,
            onChannelChanged: (NotificationChannel c) =>
                setState(() => _selectedChannel = c),
            selectedType: _selectedType,
            onTypeChanged: (NotificationType t) =>
                setState(() => _selectedType = t),
            selectedAbsentReason: _selectedAbsentReason,
            onAbsentReasonChanged: (r) =>
                setState(() => _selectedAbsentReason = r),
            isLoading: _isLoading,
            onSendPresensiTest: _sendPresensiTest,
            schoolName: widget.schoolName,
          ),
        ),
        const SizedBox(width: 20),
        // Right Column: Live Logs
        Expanded(
          flex: 4,
          child: ExecutionLogCard(
            logOutput: _logOutput,
            onClearLogs: () => setState(() => _logOutput = ''),
            height: 600,
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Gateway Testing Tools
        Expanded(
          flex: 6,
          child: GatewayDiagnosticsCard(
            pushTitleController: _pushTitleController,
            pushMessageController: _pushMessageController,
            phoneController: _phoneController,
            isLoading: _isLoading,
            onTestOneSignalConnection: _testOneSignalConnection,
            onSendTestBroadcastPush: _sendTestBroadcastPush,
            onTestWahaConnection: _testWahaConnection,
          ),
        ),
        const SizedBox(width: 20),
        // Right Column: Live Logs
        Expanded(
          flex: 4,
          child: ExecutionLogCard(
            logOutput: _logOutput,
            onClearLogs: () => setState(() => _logOutput = ''),
            height: 500,
          ),
        ),
      ],
    );
  }
}
