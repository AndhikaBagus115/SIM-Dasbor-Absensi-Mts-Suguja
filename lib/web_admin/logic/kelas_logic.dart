import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repositories/kelas_repository.dart';
import '../data/repositories/guru_repository.dart';

class PageKelasLogic extends ChangeNotifier {
  final SupabaseClient _supabase;
  final KelasRepository kelasRepository;
  final GuruRepository guruRepository;

  PageKelasLogic({
    SupabaseClient? client,
    KelasRepository? kelasRepo,
    GuruRepository? guruRepo,
  })  : _supabase = client ?? Supabase.instance.client,
        kelasRepository = kelasRepo ?? KelasRepositoryImpl(client ?? Supabase.instance.client),
        guruRepository = guruRepo ?? GuruRepositoryImpl(client ?? Supabase.instance.client);

  // 1. State
  bool _isLoading = true;
  List<Map<String, dynamic>> _kelasData = [];
  List<Map<String, dynamic>> _guruData = [];

  // 2. Getter
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get kelasData => _kelasData;
  List<Map<String, dynamic>> get guruData => _guruData;

  // 3. Metode Logika

  /// Mengambil data kelas dan guru secara PARALLEL (Lebih Cepat)
  Future<void> fetchData() async {
    _setLoading(true);
    try {
      // OPTIMASI: Gunakan Future.wait agar request berjalan bersamaan
      final results = await Future.wait([
        // [0] Fetch Guru
        _supabase
            .from('guru')
            .select('id, nama')
            .order('nama', ascending: true),

        // [1] Fetch Kelas (Join Guru)
        _supabase
            .from('kelas')
            .select('*, guru(nama)')
            .order('nama_kelas', ascending: true),
      ]);

      // Parsing hasil
      _guruData = List<Map<String, dynamic>>.from(results[0] as List);

      final rawKelas = results[1] as List;
      _kelasData = rawKelas.map((data) => _formatKelasData(data)).toList();

      // debugPrint('Data loaded: ${_kelasData.length} Kelas, ${_guruData.length} Guru');
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Memperbarui data kelas
  Future<String?> updateKelas(
    Map<String, dynamic> oldData,
    String namaKelas,
    String jamMasuk,
    String jamPulang,
    String? waliGuruId,
  ) async {
    try {
      final response = await _supabase
          .from('kelas')
          .update({
            'nama_kelas': namaKelas,
            'jam_masuk': jamMasuk,
            'jam_pulang': jamPulang,
            'wali_kelas': waliGuruId,
          })
          .eq('id', oldData['id'])
          .select('*, guru(nama)'); // Minta data terbaru

      if ((response as List).isEmpty) {
        return 'Gagal memperbarui, data tidak ditemukan.';
      }

      // Update State Lokal (Tanpa Fetch Ulang)
      final updatedKelas = _formatKelasData(response.first);
      final index = _kelasData.indexWhere((k) => k['id'] == updatedKelas['id']);

      if (index != -1) {
        _kelasData[index] = updatedKelas;
        _sortKelasData(); // Sort ulang biar rapi
        notifyListeners();
      }

      return null; // Sukses
    } catch (e) {
      debugPrint('Error update: $e');
      return 'Gagal update: ${e.toString()}';
    }
  }

  /// Menambahkan kelas baru
  Future<String?> createKelas(
    String nama,
    String jamMasuk,
    String jamPulang,
    String? waliId,
  ) async {
    try {
      final response = await _supabase
          .from('kelas')
          .insert({
            'nama_kelas': nama,
            'jam_masuk': jamMasuk,
            'jam_pulang': jamPulang,
            'wali_kelas': waliId,
          })
          .select('*, guru(nama)'); // Penting: Select join guru

      if ((response as List).isEmpty) {
        return 'Gagal menambah data.';
      }

      // Tambah ke State Lokal
      final newKelas = _formatKelasData(response.first);
      _kelasData.add(newKelas);
      _sortKelasData();

      notifyListeners();
      return null; // Sukses
    } catch (e) {
      debugPrint('Error create: $e');
      return 'Terjadi kesalahan: ${e.toString()}';
    }
  }

  // --- Helpers ---

  /// Helper untuk memformat data relasi (Flattening)
  /// Mengubah {guru: {nama: 'Budi'}} menjadi {wali_nama: 'Budi'}
  Map<String, dynamic> _formatKelasData(dynamic rawData) {
    // PENTING: Buat Map baru agar tidak memutasi data asli secara referensi
    final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

    final guruObj = data['guru'] as Map<String, dynamic>?;
    data['wali_nama'] = guruObj?['nama'] ?? '-';

    // Hapus nested object biar bersih (opsional)
    data.remove('guru');

    return data;
  }

  /// Helper untuk sort manual list lokal
  void _sortKelasData() {
    _kelasData.sort(
      (a, b) =>
          (a['nama_kelas'] ?? '').toString().compareTo(b['nama_kelas'] ?? ''),
    );
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
