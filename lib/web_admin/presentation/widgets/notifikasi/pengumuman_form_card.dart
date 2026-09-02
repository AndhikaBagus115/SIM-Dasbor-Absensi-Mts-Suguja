import 'package:flutter/material.dart';
import '../../../core/services/notification_service.dart';

class PengumumanFormCard extends StatelessWidget {
  final TextEditingController judulController;
  final TextEditingController isiController;
  final TextEditingController searchController;
  final String targetTipe;
  final ValueChanged<String> onTargetTipeChanged;
  final int? selectedKelasId;
  final String? selectedKelasNama;
  final List<Map<String, dynamic>> daftarKelas;
  final bool isLoadingKelas;
  final ValueChanged<int?> onKelasChanged;
  final List<Map<String, dynamic>> kelasSiswaList;
  final bool isLoadingKelasSiswa;
  final Map<String, dynamic>? selectedStudent;
  final List<Map<String, dynamic>> searchResults;
  final bool isSearching;
  final ValueChanged<String> onSearchStudents;
  final ValueChanged<Map<String, dynamic>> onSelectStudent;
  final VoidCallback onClearStudent;
  final NotificationChannel selectedChannel;
  final ValueChanged<NotificationChannel> onChannelChanged;
  final bool isSending;
  final VoidCallback onSendPengumuman;
  final String schoolName;

  const PengumumanFormCard({
    super.key,
    required this.judulController,
    required this.isiController,
    required this.searchController,
    required this.targetTipe,
    required this.onTargetTipeChanged,
    required this.selectedKelasId,
    required this.selectedKelasNama,
    required this.daftarKelas,
    required this.isLoadingKelas,
    required this.onKelasChanged,
    required this.kelasSiswaList,
    required this.isLoadingKelasSiswa,
    required this.selectedStudent,
    required this.searchResults,
    required this.isSearching,
    required this.onSearchStudents,
    required this.onSelectStudent,
    required this.onClearStudent,
    required this.selectedChannel,
    required this.onChannelChanged,
    required this.isSending,
    required this.onSendPengumuman,
    required this.schoolName,
  });

  @override
  Widget build(BuildContext context) {
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
                  child: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF4F46E5),
                    size: 20,
                  ),
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

            // Target Specific Detail Container
            if (targetTipe == 'semua') ...[
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
            ] else if (targetTipe == 'kelas') ...[
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
                    isLoadingKelas
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<int>(
                            initialValue: selectedKelasId,
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
                            items: daftarKelas.map((k) {
                              return DropdownMenuItem<int>(
                                value: k['id'] as int,
                                child: Text(k['nama_kelas'] ?? "-"),
                              );
                            }).toList(),
                            onChanged: onKelasChanged,
                          ),
                    if (selectedKelasId != null) ...[
                      const SizedBox(height: 10),
                      isLoadingKelasSiswa
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
                                  'Total ${kelasSiswaList.length} siswa di $selectedKelasNama (External IDs: [${kelasSiswaList.map((e) => e['id']).take(4).join(', ')}${kelasSiswaList.length > 4 ? "..." : ""}])',
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
            ] else if (targetTipe == 'siswa') ...[
              // Search Box Siswa
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Cari Nama atau NIS Siswa',
                  hintText: 'Ketik nama siswa untuk memilih...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: selectedStudent != null
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: onClearStudent,
                        )
                      : isSearching
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
                  if (selectedStudent != null) onClearStudent();
                  onSearchStudents(value);
                },
                enabled: selectedStudent == null,
              ),

              if (searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final s = searchResults[index];
                      final kelasNama = s['kelas']?['nama_kelas'] ?? '-';
                      return ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFFFEF3C7),
                          child: Icon(Icons.person,
                              size: 16, color: Color(0xFFD97706)),
                        ),
                        title: Text(
                          s['nama'] ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text(
                          'NIS: ${s['nis'] ?? '-'} • Kelas: $kelasNama • ID: ${s['id']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => onSelectStudent(s),
                      );
                    },
                  ),
                ),

              if (selectedStudent != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
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
                          'Target: ${selectedStudent!['nama']} (NIS: ${selectedStudent!['nis'] ?? '-'}, ID: ${selectedStudent!['id']}, WA Ortu: ${selectedStudent!['orang_tua_nomor'] ?? "-"})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        color: const Color(0xFF92400E),
                        onPressed: onClearStudent,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 18),

            // 2. Channel Selector
            const Text(
              '2. Jalur Pengiriman Notifikasi:',
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
                    icon: Icons.notifications_active_rounded,
                    title: 'Push Notifikasi Saja',
                    subtitle: 'Hanya via OneSignal App',
                    color: const Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPengumumanChannelOption(
                    channel: NotificationChannel.whatsapp,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'WhatsApp Saja',
                    subtitle: 'Hanya via WA Gateway',
                    color: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPengumumanChannelOption(
                    channel: NotificationChannel.both,
                    icon: Icons.all_inclusive_rounded,
                    title: 'Keduanya (Push + WA)',
                    subtitle: 'Jalur ganda maksimal',
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 3. Form Input Judul & Isi
            const Text(
              '3. Konten Pengumuman:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),

            // Quick Title Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildQuickTitleChip('Pengumuman Libur Sekolah'),
                _buildQuickTitleChip('Jadwal Ujian Semester'),
                _buildQuickTitleChip('Rapat Wali Murid'),
                _buildQuickTitleChip('Kegiatan Ekstrakurikuler'),
                _buildQuickTitleChip('Pembayaran SPP Bulanan'),
              ],
            ),
            const SizedBox(height: 8),

            TextField(
              controller: judulController,
              decoration: InputDecoration(
                labelText: 'Judul Pengumuman *',
                hintText: 'Contoh: Pemberitahuan Libur Awal Ramadhan 1447 H',
                prefixIcon: const Icon(Icons.title_rounded),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Quick Isi Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildQuickIsiChip(
                    'Diberitahukan kepada seluruh wali murid bahwa pembelajaran diliburkan mulai tanggal ... hingga ...'),
                _buildQuickIsiChip(
                    'Mohon kehadiran Bapak/Ibu wali murid pada pertemuan yang akan diselenggarakan pada hari Sabtu di aula sekolah.'),
                _buildQuickIsiChip(
                    'Diharapkan siswa mempersiapkan diri untuk mengikuti Ujian Akhir Semester dengan jadwal terlampir.'),
              ],
            ),
            const SizedBox(height: 8),

            TextField(
              controller: isiController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Isi Pesan Pengumuman *',
                hintText:
                    'Tuliskan isi pengumuman lengkap yang akan dibaca oleh wali murid...',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 50),
                  child: Icon(Icons.notes_rounded),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Live Preview Box
            _buildPengumumanLivePreviewBox(),

            const SizedBox(height: 20),

            // Tombol Kirim
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  isSending
                      ? 'Mengirim Pengumuman...'
                      : 'Kirim Pengumuman Sekarang',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: isSending ? null : onSendPengumuman,
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
    final isSelected = targetTipe == tipe;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onTargetTipeChanged(tipe),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
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
    required Color color,
  }) {
    final isSelected = selectedChannel == channel;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChannelChanged(channel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTitleChip(String title) {
    return ActionChip(
      avatar: const Icon(Icons.label_outline_rounded,
          size: 13, color: Color(0xFF4F46E5)),
      label: Text(title, style: const TextStyle(fontSize: 11)),
      backgroundColor: const Color(0xFFEEF2FF),
      side: BorderSide(color: const Color(0xFFC7D2FE).withValues(alpha: 0.8)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: () => judulController.text = title,
    );
  }

  Widget _buildQuickIsiChip(String text) {
    return ActionChip(
      avatar: const Icon(Icons.format_quote_rounded,
          size: 13, color: Color(0xFF0D9488)),
      label: Text(
        text.length > 40 ? '${text.substring(0, 40)}...' : text,
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: const Color(0xFFF0FDFA),
      side: BorderSide(color: const Color(0xFF99F6E4).withValues(alpha: 0.8)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: () => isiController.text = text,
    );
  }

  Widget _buildPengumumanLivePreviewBox() {
    final judul = judulController.text.trim().isEmpty
        ? '[Judul Pengumuman]'
        : judulController.text.trim();
    final isi = isiController.text.trim().isEmpty
        ? 'Isi pengumuman resmi dari madrasah akan muncul di sini...'
        : isiController.text.trim();

    String targetText = 'Semua Wali Murid';
    if (targetTipe == 'kelas') {
      targetText = selectedKelasNama ?? 'Kelas (Belum Dipilih)';
    } else if (targetTipe == 'siswa') {
      targetText = selectedStudent != null
          ? '${selectedStudent!['nama']} (${selectedStudent!['nis'] ?? "-"})'
          : 'Siswa (Belum Dipilih)';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.preview_rounded,
                    color: Color(0xFF94A3B8), size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Pratinjau Pengumuman (Live Preview)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Target: $targetText',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Push Notification Mock
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.school,
                                  color: Colors.white, size: 12),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                schoolName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            const Text(
                              'Baru saja',
                              style:
                                  TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          judul,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isi,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // WhatsApp Mock
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7FCE8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.chat,
                                color: Color(0xFF059669), size: 13),
                            SizedBox(width: 6),
                            Text(
                              'Format WhatsApp',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '📢 *PENGUMUMAN RESMI SEKOLAH*\n*$schoolName*\n\n*Judul:* *$judul*\n\n$isi',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Color(0xFF064E3B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
