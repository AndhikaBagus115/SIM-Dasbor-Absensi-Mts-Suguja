import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../data/models/pengumuman_model.dart';

/// Badge widget to display announcement target (Semua / Kelas / Siswa)
class TargetBadge extends StatelessWidget {
  final String targetTipe;
  final String? targetNama;

  const TargetBadge({
    super.key,
    required this.targetTipe,
    this.targetNama,
  });

  @override
  Widget build(BuildContext context) {
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
        label = targetNama != null && targetNama!.isNotEmpty
            ? targetNama!
            : 'Kelas';
        break;
      case 'siswa':
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFB45309);
        icon = Icons.person_outline_rounded;
        label = targetNama != null && targetNama!.isNotEmpty
            ? targetNama!
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
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog to view full details of an announcement
class DetailPengumumanDialog extends StatelessWidget {
  final Pengumuman pengumuman;

  const DetailPengumumanDialog({
    super.key,
    required this.pengumuman,
  });

  static void show(BuildContext context, Pengumuman p) {
    showDialog(
      context: context,
      builder: (ctx) => DetailPengumumanDialog(pengumuman: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pengumuman;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Color(0xFF4F46E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p.judul,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Target Penerima: ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  TargetBadge(
                    targetTipe: p.targetTipe,
                    targetNama: p.targetNama,
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Isi Pengumuman Lengkap:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

/// Dialog to show SQL creation script if pengumuman table is missing
class SqlSchemaDialog extends StatelessWidget {
  const SqlSchemaDialog({super.key});

  static const String sqlText = '''CREATE TABLE IF NOT EXISTS public.pengumuman (
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

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const SqlSchemaDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SelectableText(
                sqlText,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFE2E8F0),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Salin SQL'),
          onPressed: () {
            Clipboard.setData(const ClipboardData(text: sqlText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Skrip SQL berhasil disalin ke clipboard!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
