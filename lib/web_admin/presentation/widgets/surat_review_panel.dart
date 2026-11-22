import 'package:flutter/material.dart';

class SuratReviewPanel extends StatefulWidget {
  const SuratReviewPanel({
    super.key,
    required this.surat,
    required this.onReview,
  });
  final Map<String, dynamic> surat;
  final Future<Map<String, dynamic>> Function(bool approve, String note)
  onReview;
  @override
  State<SuratReviewPanel> createState() => _SuratReviewPanelState();
}

class _SuratReviewPanelState extends State<SuratReviewPanel> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _review(bool approve) async {
    if (_busy) return;
    if (!approve && _note.text.trim().isEmpty) {
      setState(() => _error = 'Alasan penolakan wajib diisi.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.onReview(approve, _note.text.trim());
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _result ?? widget.surat;
    final status = record['status']?.toString() ?? 'menunggu';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status verifikasi: $status',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (status == 'menunggu') ...[
            const SizedBox(height: 8),
            const Text(
              'Persetujuan menyinkronkan presensi sesuai jenis dan rentang tanggal surat. Presensi hadir harus ditinjau terlebih dahulu.',
            ),
            TextField(
              controller: _note,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Catatan admin / alasan penolakan',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _review(true),
                  child: Text(_busy ? 'Memproses...' : 'Setujui surat'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _review(false),
                  child: const Text('Tolak surat'),
                ),
              ],
            ),
          ] else if (record['catatan_guru'] != null)
            Text('Catatan: ${record['catatan_guru']}'),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
