import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/notification_service.dart';

class NotifikasiTestPage extends StatefulWidget {
  final String schoolName;

  const NotifikasiTestPage({super.key, required this.schoolName});

  @override
  State<NotifikasiTestPage> createState() => _NotifikasiTestPageState();
}

class _NotifikasiTestPageState extends State<NotifikasiTestPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedStudent;
  String _logOutput = '';
  NotificationType _selectedType = NotificationType.present;

  @override
  void dispose() {
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    setState(() {
      _logOutput = '[$timestamp] $message\n$_logOutput';
    });
  }

  Future<void> _searchStudents(String query) async {
    if (query.isEmpty) {
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
          .select('id, nis, nama, orang_tua_nama, orang_tua_nomor, status, kelas(nama_kelas)')
          .or('nama.ilike.%$query%,nis.ilike.%$query%')
          .eq('status', 'aktif')
          .limit(10);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
        _isSearching = false;
      });
    } catch (e) {
      _addLog('Error searching: $e');
      setState(() => _isSearching = false);
    }
  }

  void _selectStudent(Map<String, dynamic> student) {
    setState(() {
      _selectedStudent = student;
      _searchController.text = student['nama'] ?? '';
      _searchResults = [];
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStudent = null;
      _searchController.clear();
      _searchResults = [];
    });
  }

  Future<void> _testWahaConnection() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackbar('Masukkan nomor telepon terlebih dahulu', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    _addLog('Testing WAHA connection to: $phone');

    try {
      final success = await NotificationService.testWahaConnection(
        testPhoneNumber: phone,
      );

      _addLog(success
          ? '✅ BERHASIL kirim pesan test ke $phone'
          : '❌ GAGAL kirim pesan test ke $phone');

      _showSnackbar(
        success ? 'Pesan test berhasil dikirim!' : 'Gagal mengirim pesan test',
        isError: !success,
      );
    } catch (e) {
      _addLog('❌ Error: $e');
      _showSnackbar('Error: $e', isError: true);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _sendNotificationToSelectedStudent() async {
    if (_selectedStudent == null) {
      _showSnackbar('Pilih siswa terlebih dahulu', isError: true);
      return;
    }

    final siswaId = _selectedStudent!['id'] as int;
    final nama = _selectedStudent!['nama'] as String? ?? 'Siswa';
    final parentPhone = _selectedStudent!['orang_tua_nomor'] as String?;

    if (parentPhone == null || parentPhone.isEmpty) {
      _showSnackbar('Siswa ini tidak memiliki nomor orang tua', isError: true);
      _addLog('❌ Siswa $nama tidak memiliki nomor orang tua');
      return;
    }

    setState(() => _isLoading = true);
    _addLog('Sending ${_selectedType.displayName} notification to: $nama');
    _addLog('Target phone: $parentPhone');

    try {
      final result = await NotificationService.testNotificationBySiswaId(
        siswaId: siswaId,
        schoolName: widget.schoolName,
        type: _selectedType,
      );

      _addLog('Nama Siswa: ${result['studentName'] ?? 'N/A'}');
      _addLog('No. Ortu: ${result['parentPhone'] ?? 'N/A'}');
      _addLog(result['success'] == true
          ? '✅ ${result['message']}'
          : '❌ ${result['message']}');

      _showSnackbar(
        result['message'] as String,
        isError: result['success'] != true,
      );
    } catch (e) {
      _addLog('❌ Error: $e');
      _showSnackbar('Error: $e', isError: true);
    }

    setState(() => _isLoading = false);
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildDirectTestCard(),
                          const SizedBox(height: 16),
                          _buildSearchSiswaCard(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildLogCard(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[700]!, Colors.green[500]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test Notifikasi WhatsApp',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Kirim notifikasi ke orang tua siswa via WhatsApp',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDirectTestCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Test Langsung ke Nomor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Nomor WhatsApp',
                hintText: '08123456789',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _testWahaConnection,
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Kirim Pesan Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSiswaCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_search, color: Colors.purple[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Cari Siswa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari Nama / NIS Siswa',
                hintText: 'Ketik nama atau NIS...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _selectedStudent != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSelection,
                      )
                    : _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                if (_selectedStudent != null) {
                  _clearSelection();
                }
                _searchStudents(value);
              },
              enabled: _selectedStudent == null,
            ),
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
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
                        backgroundColor:
                            hasPhone ? Colors.green[100] : Colors.red[100],
                        child: Icon(
                          hasPhone ? Icons.check : Icons.warning,
                          size: 16,
                          color:
                              hasPhone ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                      title: Text(
                        student['nama'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'NIS: ${student['nis'] ?? '-'} • ${student['kelas']?['nama_kelas'] ?? '-'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: hasPhone
                          ? Text(
                              student['orang_tua_nomor'],
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green[700],
                              ),
                            )
                          : Text(
                              'No HP',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red[400],
                              ),
                            ),
                      onTap: () => _selectStudent(student),
                    );
                  },
                ),
              ),
            if (_selectedStudent != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, size: 18, color: Colors.purple[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedStudent!['nama'] ?? '-',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[800],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _clearSelection,
                          icon: Icon(Icons.close,
                              size: 18, color: Colors.purple[700]),
                          tooltip: 'Hapus pilihan',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('NIS: ${_selectedStudent!['nis'] ?? '-'}'),
                    Text('Kelas: ${_selectedStudent!['kelas']?['nama_kelas'] ?? '-'}'),
                    Text('Nama Ortu: ${_selectedStudent!['orang_tua_nama'] ?? '-'}'),
                    Row(
                      children: [
                        const Text('No. Ortu: '),
                        Text(
                          _selectedStudent!['orang_tua_nomor'] ?? 'Tidak ada',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _selectedStudent!['orang_tua_nomor'] != null
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<NotificationType>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                labelText: 'Tipe Notifikasi',
                prefixIcon: const Icon(Icons.category, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: NotificationType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _selectedStudent == null
                    ? null
                    : _sendNotificationToSelectedStudent,
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Kirim Notifikasi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal, color: Colors.grey[700], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Log Output',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _logOutput = ''),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _logOutput.isEmpty ? 'Log akan muncul di sini...' : _logOutput,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: _logOutput.isEmpty ? Colors.grey : Colors.green[400],
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
