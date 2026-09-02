import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/pengumuman_model.dart';
import 'notifikasi_dialogs.dart';

class RiwayatPengumumanCard extends StatelessWidget {
  final List<Pengumuman> riwayatList;
  final String searchQuery;
  final TextEditingController searchController;
  final bool isLoading;
  final bool isTableMissing;
  final VoidCallback onRefresh;
  final ValueChanged<Pengumuman> onShowDetail;
  final ValueChanged<Pengumuman> onDelete;
  final VoidCallback onShowSqlDialog;

  const RiwayatPengumumanCard({
    super.key,
    required this.riwayatList,
    required this.searchQuery,
    required this.searchController,
    required this.isLoading,
    required this.isTableMissing,
    required this.onRefresh,
    required this.onShowDetail,
    required this.onDelete,
    required this.onShowSqlDialog,
  });

  @override
  Widget build(BuildContext context) {
    final filteredList = searchQuery.isEmpty
        ? riwayatList
        : riwayatList.where((p) {
            final q = searchQuery.toLowerCase();
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
            // Header Bar Riwayat
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF0D9488),
                    size: 20,
                  ),
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${riwayatList.length} Total',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Daftar pengumuman yang tersimpan di Supabase',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Segarkan Data',
                  onPressed: onRefresh,
                ),
              ],
            ),

            if (isTableMissing) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tabel `pengumuman` belum dibuat di Supabase. Klik tombol di kanan untuk melihat skrip SQL pembuatan tabel.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.code, size: 14),
                      label: const Text('Lihat SQL',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: onShowSqlDialog,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Search Bar Riwayat
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari judul, isi, atau target pengumuman...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: searchController.clear,
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),

            const SizedBox(height: 14),

            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredList.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      searchQuery.isEmpty
                          ? 'Belum ada riwayat pengumuman'
                          : 'Tidak ada pengumuman yang cocok dengan "$searchQuery"',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
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
                              'Waktu Kirim',
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

                    // Table Body Rows
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
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B)),
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
                                child: TargetBadge(
                                  targetTipe: item.targetTipe,
                                  targetNama: item.targetNama,
                                ),
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
                                          size: 11,
                                          color: Color(0xFF475569)),
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
                                    onPressed: () => onShowDetail(item),
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
                                    onPressed: () => onDelete(item),
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
}
