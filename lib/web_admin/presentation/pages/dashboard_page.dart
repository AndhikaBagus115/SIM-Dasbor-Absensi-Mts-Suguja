import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/dashboard/dashboard_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  RealtimeChannel? _absensiChannel;
  Timer? _refreshDebounce;

  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastUpdated;

  // Quick Stats (Hari ini)
  int _totalSiswaAktif = 0;
  int _hadirHariIni = 0;
  int _terlambatHariIni = 0;
  int _absenHariIni = 0;

  // Aktivitas + Alerts
  List<Map<String, dynamic>> _aktivitasTerbaru = [];
  List<Map<String, dynamic>> _alerts = [];

  // Distribusi kelas
  List<Map<String, dynamic>> _distribusiKelas = [];

  // Rekapan semester
  int _hadirSemester = 0;
  int _terlambatSemester = 0;
  int _absenSemester = 0;
  int _totalHariSemester = 0;

  final List<Color> _pieColors = const [
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFFFFA726),
    Color(0xFFEF5350),
    Color(0xFF26C6DA),
    Color(0xFF7E57C2),
    Color(0xFFD4E157),
  ];

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'id_ID';
    _initializeDashboard();
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    final ch = _absensiChannel;
    if (ch != null) supabase.removeChannel(ch);
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    await _fetchDashboardData(showLoadingOverlay: true);

    // Realtime listener: debounce agar tidak spam fetch
    _absensiChannel = supabase.channel('public:absensi');

    _absensiChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'absensi',
          callback: (_) {
            _refreshDebounce?.cancel();
            _refreshDebounce = Timer(const Duration(milliseconds: 500), () {
              if (mounted) _fetchDashboardData(showLoadingOverlay: false);
            });
          },
        )
        .subscribe();
  }

  // =========================
  // DATA CONSISTENCY HELPERS
  // =========================
  String _normStatus(dynamic s) => (s ?? '').toString().trim().toLowerCase();

  bool _isHadirLike(String status) => status == 'hadir' || status == 'pulang';

  bool _isAbsenLike(String status) =>
      status == 'sakit' || status == 'izin' || status == 'alfa';

  // =========================
  // FETCH
  // =========================
  Future<void> _fetchDashboardData({required bool showLoadingOverlay}) async {
    if (!mounted) return;

    if (showLoadingOverlay) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      // keep UI stable; update quietly
      setState(() => _errorMessage = null);
    }

    try {
      final now = DateTime.now();
      final tglHariIni = DateFormat('yyyy-MM-dd').format(now);

      // Semester: Jan-Jun (semester genap) / Jul-Dec (semester ganjil)
      final currentYear = now.year;
      final bool isJanToJun = now.month >= 1 && now.month <= 6;

      final tglMulaiSemester = DateFormat('yyyy-MM-dd').format(
        DateTime(currentYear, isJanToJun ? 1 : 7, 1),
      );

      final tglAkhirSemester = DateFormat('yyyy-MM-dd').format(
        DateTime(currentYear, isJanToJun ? 6 : 12, isJanToJun ? 30 : 31),
      );

      // 1) Total siswa aktif (optimasi count query)
      final countRes = await supabase
          .from('siswa')
          .select('id')
          .eq('status', 'aktif')
          .count(CountOption.exact);
      final totalSiswaAktif = countRes.count;

      // 2) Absensi hari ini (ambil minimal kolom yang dibutuhkan)
      final absensiHariIni = await supabase
          .from('absensi')
          .select('status, created_at, waktu_masuk, siswa_id')
          .eq('tanggal', tglHariIni);

      // 3) Aktivitas terbaru (join siswa)
      final aktivitasRes = await supabase
          .from('absensi')
          .select('status, created_at, waktu_masuk, siswa(nama)')
          .order('created_at', ascending: false)
          .limit(6);

      // 4) Distribusi kelas (kelas dengan count siswa)
      final distribusiRes =
          await supabase.from('kelas').select('id, nama_kelas, siswa(count)');

      // 5) Rekapan semester (status + tanggal)
      final rekapanSemesterRes = await supabase
          .from('absensi')
          .select('status, tanggal')
          .gte('tanggal', tglMulaiSemester)
          .lte('tanggal', tglAkhirSemester);

      // =========================
      // PROCESS: HARI INI
      // =========================
      int hadir = 0;
      int terlambat = 0;
      int absen = 0;

      int inputLuarJam = 0;
      int totalTerlambatHariIni = 0;

      for (final row in (absensiHariIni as List)) {
        final status = _normStatus(row['status']);

        if (_isHadirLike(status)) {
          hadir++;
        } else if (status == 'terlambat') {
          terlambat++;
          totalTerlambatHariIni++;
        } else if (_isAbsenLike(status)) {
          absen++;
        }

        final createdAt = row['created_at']?.toString();
        if (createdAt != null) {
          final dt = DateTime.tryParse(createdAt)?.toLocal();
          if (dt != null) {
            if (dt.hour < 6 || dt.hour >= 17) inputLuarJam++;
          }
        }
      }

      // =========================
      // PROCESS: DISTRIBUSI KELAS
      // =========================
      final List<Map<String, dynamic>> distribusiData = [];
      int colorIndex = 0;

      for (final item in (distribusiRes as List)) {
        final siswaCountList = item['siswa'];
        final int count = (siswaCountList is List && siswaCountList.isNotEmpty)
            ? (siswaCountList[0]['count'] as int? ?? 0)
            : 0;

        if (count > 0) {
          distribusiData.add({
            'label': (item['nama_kelas'] ?? '-').toString(),
            'value': count.toDouble(),
            'color': _pieColors[colorIndex % _pieColors.length],
          });
          colorIndex++;
        }
      }

      // =========================
      // PROCESS: SEMESTER
      // =========================
      int hadirSem = 0;
      int terlambatSem = 0;
      int absenSem = 0;
      final Set<String> hariUnik = {};

      for (final row in (rekapanSemesterRes as List)) {
        final status = _normStatus(row['status']);
        final tgl = row['tanggal']?.toString();
        if (tgl != null) hariUnik.add(tgl);

        if (_isHadirLike(status)) {
          hadirSem++;
        } else if (status == 'terlambat') {
          terlambatSem++;
        } else if (_isAbsenLike(status)) {
          absenSem++;
        }
      }

      // =========================
      // ALERTS (konsisten, deterministic)
      // =========================
      final List<Map<String, dynamic>> anomalyAlerts = [];

      if (inputLuarJam > 0) {
        anomalyAlerts.add({
          'icon': Icons.access_time_filled,
          'color': const Color(0xFFEF5350),
          'title': 'Aktivitas Luar Jam Operasional',
          'subtitle': 'Terdeteksi $inputLuarJam data diinput di luar jam sekolah.',
        });
      }

      if (now.weekday == DateTime.sunday && (absensiHariIni as List).isNotEmpty) {
        anomalyAlerts.add({
          'icon': Icons.event_busy,
          'color': const Color(0xFFFFA726),
          'title': 'Aktivitas di Hari Libur',
          'subtitle': 'Terdeteksi input absensi pada hari Minggu.',
        });
      }

      if (totalSiswaAktif > 0) {
        final p = totalTerlambatHariIni / totalSiswaAktif;
        if (p > 0.20) {
          anomalyAlerts.add({
            'icon': Icons.warning_rounded,
            'color': const Color(0xFF7E57C2),
            'title': 'Lonjakan Keterlambatan',
            'subtitle': 'Lebih dari 20% siswa terlambat hari ini.',
          });
        }
      }

      if (anomalyAlerts.isEmpty) {
        anomalyAlerts.add({
          'icon': Icons.verified_user,
          'color': const Color(0xFF66BB6A),
          'title': 'Sistem Berjalan Normal',
          'subtitle': 'Tidak ditemukan anomali pada data absensi hari ini.',
        });
      }

      // =========================
      // APPLY STATE
      // =========================
      if (!mounted) return;
      setState(() {
        _totalSiswaAktif = totalSiswaAktif;

        _hadirHariIni = hadir;
        _terlambatHariIni = terlambat;
        _absenHariIni = absen;

        _aktivitasTerbaru = List<Map<String, dynamic>>.from(aktivitasRes as List);
        _distribusiKelas = distribusiData;

        _hadirSemester = hadirSem;
        _terlambatSemester = terlambatSem;
        _absenSemester = absenSem;
        _totalHariSemester = hariUnik.length;

        _alerts = anomalyAlerts;

        _lastUpdated = DateTime.now();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat dashboard: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _fetchDashboardData(showLoadingOverlay: false),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;

                    // Responsive breakpoints
                    final bool isMobile = w < 700;
                    final bool isTablet = w >= 700 && w < 1100;

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(isMobile ? 14 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppHeader(
                            lastUpdated: _lastUpdated,
                            errorMessage: _errorMessage,
                            onRefresh: () => _fetchDashboardData(
                              showLoadingOverlay: false,
                            ),
                          ),
                          const SizedBox(height: 16),

                          const SectionTitle(
                            title: 'Ringkasan Hari Ini',
                            subtitle: 'Konsisten dengan siswa aktif dan status absensi.',
                          ),
                          const SizedBox(height: 12),

                          QuickStatsResponsive(
                            isMobile: isMobile,
                            isTablet: isTablet,
                            totalSiswa: _totalSiswaAktif,
                            hadirHariIni: _hadirHariIni,
                            terlambatHariIni: _terlambatHariIni,
                            absenHariIni: _absenHariIni,
                          ),

                          const SizedBox(height: 18),

                          const SectionTitle(
                            title: 'Rekapan Semester',
                            subtitle: 'Menghitung total potensi kehadiran berdasarkan hari unik yang memiliki data.',
                          ),
                          const SizedBox(height: 12),

                          DetailedStatsResponsive(
                            isMobile: isMobile,
                            totalSiswa: _totalSiswaAktif,
                            hadirSemester: _hadirSemester,
                            terlambatSemester: _terlambatSemester,
                            absenSemester: _absenSemester,
                            totalHariSemester: _totalHariSemester,
                          ),

                          const SizedBox(height: 18),

                          const SectionTitle(
                            title: 'Visualisasi',
                            subtitle: 'Tren dan distribusi untuk membantu keputusan.',
                          ),
                          const SizedBox(height: 12),

                          ChartsSectionResponsive(
                            isMobile: isMobile,
                            distribusiKelas: _distribusiKelas,
                          ),

                          const SizedBox(height: 18),

                          const SectionTitle(
                            title: 'Monitoring',
                            subtitle: 'Peringatan sistem dan aktivitas terbaru.',
                          ),
                          const SizedBox(height: 12),

                          BottomSectionResponsive(
                            isMobile: isMobile,
                            alerts: _alerts,
                            activities: _aktivitasTerbaru,
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
