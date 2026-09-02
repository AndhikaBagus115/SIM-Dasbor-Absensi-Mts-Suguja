import 'package:flutter/material.dart';
import '../../../core/services/notification_service.dart';

class PresensiSimulationCard extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController phoneController;
  final TextEditingController customNoteController;
  final Map<String, dynamic>? selectedStudent;
  final List<Map<String, dynamic>> searchResults;
  final bool isSearching;
  final ValueChanged<String> onSearchStudents;
  final ValueChanged<Map<String, dynamic>> onSelectStudent;
  final VoidCallback onClearStudent;
  final NotificationChannel selectedChannel;
  final ValueChanged<NotificationChannel> onChannelChanged;
  final NotificationType selectedType;
  final ValueChanged<NotificationType> onTypeChanged;
  final String selectedAbsentReason;
  final ValueChanged<String> onAbsentReasonChanged;
  final bool isLoading;
  final VoidCallback onSendPresensiTest;
  final String schoolName;

  const PresensiSimulationCard({
    super.key,
    required this.searchController,
    required this.phoneController,
    required this.customNoteController,
    required this.selectedStudent,
    required this.searchResults,
    required this.isSearching,
    required this.onSearchStudents,
    required this.onSelectStudent,
    required this.onClearStudent,
    required this.selectedChannel,
    required this.onChannelChanged,
    required this.selectedType,
    required this.onTypeChanged,
    required this.selectedAbsentReason,
    required this.onAbsentReasonChanged,
    required this.isLoading,
    required this.onSendPresensiTest,
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
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Cari Nama atau NIS Siswa',
                hintText: 'Ketik minimal 1 huruf untuk mencari...',
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
                if (selectedStudent != null) onClearStudent();
                onSearchStudents(value);
              },
              enabled: selectedStudent == null,
            ),

            if (searchResults.isNotEmpty)
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
                  itemCount: searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = searchResults[index];
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
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        'NIS: ${student['nis'] ?? '-'} • Kelas: ${student['kelas']?['nama_kelas'] ?? '-'} • ID: ${student['id']}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: hasPhone
                          ? const Icon(Icons.check_circle,
                              size: 16, color: Color(0xFF16A34A))
                          : const Text(
                              'Tanpa No WA',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFFDC2626)),
                            ),
                      onTap: () => onSelectStudent(student),
                    );
                  },
                ),
              ),

            if (selectedStudent != null) ...[
              const SizedBox(height: 12),
              _buildSelectedStudentBanner(),
            ],

            const SizedBox(height: 16),

            // Channel Selector
            const Text(
              'Jalur Pengiriman Notifikasi:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPresensiChannelOption(
                    channel: NotificationChannel.both,
                    icon: Icons.all_inclusive_rounded,
                    title: 'Keduanya (Ganda)',
                    subtitle: 'WA + Push App',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPresensiChannelOption(
                    channel: NotificationChannel.whatsapp,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'WhatsApp Saja',
                    subtitle: 'Via WA Gateway',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPresensiChannelOption(
                    channel: NotificationChannel.onesignal,
                    icon: Icons.notifications_active_rounded,
                    title: 'Push Notif Saja',
                    subtitle: 'Via OneSignal',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Presensi Type Selector
            const Text(
              'Status Presensi Siswa:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeChip(
                  NotificationType.present,
                  Icons.check_circle_outline,
                  const Color(0xFF16A34A),
                  'Hadir Tepat Waktu',
                ),
                _buildTypeChip(
                  NotificationType.late,
                  Icons.alarm_rounded,
                  const Color(0xFFD97706),
                  'Terlambat Masuk',
                ),
                _buildTypeChip(
                  NotificationType.pulang,
                  Icons.directions_walk_rounded,
                  const Color(0xFF0284C7),
                  'Presensi Pulang',
                ),
                _buildTypeChip(
                  NotificationType.absent,
                  Icons.cancel_outlined,
                  const Color(0xFFDC2626),
                  'Tidak Hadir / Izin / Sakit',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Dynamic Reason & Message Section
            if (selectedType == NotificationType.absent)
              _buildAbsentCustomMessageSection()
            else
              _buildGenericCustomMessageSection(),

            const SizedBox(height: 16),

            // Message Preview Box
            _buildMessagePreviewBox(),

            const SizedBox(height: 20),

            // Send Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: isLoading
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
                  isLoading
                      ? 'Mengirim Notifikasi...'
                      : 'Kirim Notifikasi Presensi Sekarang',
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
                onPressed: isLoading ? null : onSendPresensiTest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedStudentBanner() {
    final s = selectedStudent!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_rounded,
                  color: Color(0xFF4F46E5), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${s['nama']} (NIS: ${s['nis'] ?? '-'})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3730A3),
                  ),
                ),
              ),
              Text(
                'Kelas: ${s['kelas']?['nama_kelas'] ?? '-'}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4338CA)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.phone_android_rounded,
                  size: 13, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                'No WA Ortu: ${s['orang_tua_nomor'] ?? "(Tidak Terdaftar)"}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
              ),
              const Spacer(),
              Text(
                'External ID: ${s['id']}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresensiChannelOption({
    required NotificationChannel channel,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = selectedChannel == channel;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChannelChanged(channel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 15,
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    NotificationType type,
    IconData icon,
    Color color,
    String label,
  ) {
    final isSelected = selectedType == type;
    return ChoiceChip(
      avatar: Icon(icon,
          size: 15, color: isSelected ? Colors.white : color),
      label: Text(label),
      selected: isSelected,
      selectedColor: color,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : const Color(0xFF334155),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(
          color: isSelected ? color : Colors.grey.shade300, width: 1),
      onSelected: (_) => onTypeChanged(type),
    );
  }

  Widget _buildAbsentCustomMessageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alasan / Kategori Ketidakhadiran:',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildAbsentReasonChip('Alpa (Tanpa Keterangan)',
                Icons.warning_amber_rounded, const Color(0xFFDC2626)),
            _buildAbsentReasonChip(
                'Sakit', Icons.medical_services_outlined, const Color(0xFFD97706)),
            _buildAbsentReasonChip(
                'Izin Resmi', Icons.article_outlined, const Color(0xFF2563EB)),
            _buildAbsentReasonChip(
                'Membolos Jam Tertentu', Icons.run_circle_outlined, const Color(0xFF9333EA)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: customNoteController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Catatan / Alasan Khusus dari Wali Kelas (Opsional)',
            hintText:
                'Contoh: Diharapkan orang tua menghubungi wali kelas terkait ketidakhadiran...',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAbsentReasonChip(String reason, IconData icon, Color color) {
    final isSelected = selectedAbsentReason == reason;
    return ChoiceChip(
      avatar: Icon(icon,
          size: 13, color: isSelected ? Colors.white : color),
      label: Text(reason, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      selectedColor: color,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : const Color(0xFF334155),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(
          color: isSelected ? color : Colors.grey.shade300, width: 1),
      onSelected: (_) => onAbsentReasonChanged(reason),
    );
  }

  Widget _buildGenericCustomMessageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pesan Tambahan (Opsional):',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildPresensiTemplateChip(
                'Tiba di sekolah tepat waktu dan telah masuk kelas.'),
            _buildPresensiTemplateChip(
                'Telah selesai mengikuti KBM dan meninggalkan sekolah.'),
            _buildPresensiTemplateChip(
                'Terlambat 15 menit, telah diberikan pembinaan.'),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: customNoteController,
          decoration: InputDecoration(
            labelText: 'Catatan Khusus Presensi',
            hintText: 'Tulis pesan tambahan jika diperlukan...',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresensiTemplateChip(String text) {
    return ActionChip(
      label: Text(
        text.length > 35 ? '${text.substring(0, 35)}...' : text,
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide(color: Colors.grey.shade300),
      onPressed: () => customNoteController.text = text,
    );
  }

  Widget _buildMessagePreviewBox() {
    final sNama = selectedStudent?['nama'] ?? 'Ahmad Fadhil';
    final sNis = selectedStudent?['nis'] ?? '2026001';
    final sKelas = selectedStudent?['kelas']?['nama_kelas'] ?? '8A';
    final note = customNoteController.text.trim();

    String statusText = 'Hadir';
    if (selectedType == NotificationType.late) {
      statusText = 'Terlambat';
    } else if (selectedType == NotificationType.pulang) {
      statusText = 'Pulang Sekolah';
    } else if (selectedType == NotificationType.absent) {
      statusText = 'Tidak Hadir ($selectedAbsentReason)';
    }

    final mockPushTitle = 'Informasi Presensi - $sNama';
    final mockPushBody =
        'Status: $statusText di $schoolName.${note.isNotEmpty ? " Catatan: $note" : ""}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF334155),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.remove_red_eye_outlined,
                    color: Color(0xFF94A3B8), size: 14),
                SizedBox(width: 6),
                Text(
                  'Pratinjau Pesan Presensi',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Push Mock
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Push Notifikasi:',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4F46E5)),
                        ),
                        const SizedBox(height: 4),
                        Text(mockPushTitle,
                            style: const TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(mockPushBody,
                            style: const TextStyle(
                                fontSize: 10.5, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // WhatsApp Mock
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7FCE8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Format WhatsApp:',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📢 *PEMBERITAHUAN PRESENSI*\nNama: *$sNama*\nNIS: $sNis (Kelas: $sKelas)\nStatus: *$statusText*\n${note.isNotEmpty ? "Catatan: $note" : ""}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            color: Color(0xFF064E3B),
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
