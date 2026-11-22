import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';

class AttendanceEditDialog extends StatefulWidget {
  const AttendanceEditDialog({
    super.key,
    required this.record,
    required this.onSave,
    required this.loadAudit,
    this.statusOptions,
  });
  final Map<String, dynamic> record;
  final Future<void> Function(
    String status,
    String? masuk,
    String? pulang,
    String? keterangan,
    String reason,
  )
  onSave;
  final Future<List<Map<String, dynamic>>> Function() loadAudit;
  final List<String>? statusOptions;
  @override
  State<AttendanceEditDialog> createState() => _AttendanceEditDialogState();
}

class _AttendanceEditDialogState extends State<AttendanceEditDialog> {
  final _form = GlobalKey<FormState>();
  late final _masuk = TextEditingController(
    text: widget.record['waktu_masuk'] as String? ?? '',
  );
  late final _pulang = TextEditingController(
    text: widget.record['waktu_pulang'] as String? ?? '',
  );
  late final _keterangan = TextEditingController(
    text: widget.record['keterangan'] as String? ?? '',
  );
  final _reason = TextEditingController();
  late String _status = widget.record['status'] as String? ?? 'alfa';
  bool _busy = false;
  String? _error;
  bool get _absent => ['izin', 'sakit', 'alfa', 'alpa'].contains(_status);

  @override
  void dispose() {
    _masuk.dispose();
    _pulang.dispose();
    _keterangan.dispose();
    _reason.dispose();
    super.dispose();
  }

  String? _timeError(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Waktu wajib diisi.' : null;
    }
    return RegExp(
          r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d(\.\d{1,6})?)?$',
        ).hasMatch(value.trim())
        ? null
        : 'Gunakan HH:mm atau HH:mm:ss.';
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _status,
        _absent ? null : _value(_masuk),
        _absent ? null : _value(_pulang),
        _value(_keterangan),
        _reason.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _value(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  Future<void> _showAudit() async {
    final history = widget.loadAudit();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Riwayat perubahan · 100 terbaru'),
        content: SizedBox(
          width: 560,
          height: 360,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: history,
            builder: (_, snapshot) {
              if (snapshot.hasError) {
                return Text('Gagal memuat riwayat: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Text('Belum ada koreksi yang tercatat.');
              }
              return ListView(
                children: snapshot.data!.map((row) {
                  final before = row['before_data'] as Map? ?? {};
                  final after = row['after_data'] as Map? ?? {};
                  final date = DateTime.tryParse(
                    row['created_at']?.toString() ?? '',
                  );
                  return ExpansionTile(
                    title: Text(row['reason']?.toString() ?? '-'),
                    subtitle: Text(
                      '${row['actor_name'] ?? '-'} · ${date == null ? '-' : DateFormat('dd MMM yyyy HH:mm').format(date.toLocal())}',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Status: ${before['status'] ?? '-'} → ${after['status'] ?? '-'}\nMasuk: ${before['waktu_masuk'] ?? '-'} → ${after['waktu_masuk'] ?? '-'}\nPulang: ${before['waktu_pulang'] ?? '-'} → ${after['waktu_pulang'] ?? '-'}\nKeterangan: ${before['keterangan'] ?? '-'} → ${after['keterangan'] ?? '-'}',
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        'Koreksi presensi · ${widget.record['siswa']?['nama'] ?? 'Siswa'}',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final status
                        in widget.statusOptions ??
                            AttendanceStatus.values
                                .map((entry) => entry.value)
                                .toList())
                      DropdownMenuItem(
                        value: status,
                        child: Text(
                          AttendanceStatus.values
                                  .where((entry) => entry.value == status)
                                  .firstOrNull
                                  ?.displayName ??
                              status,
                        ),
                      ),
                    if (!(widget.statusOptions ??
                            AttendanceStatus.values
                                .map((entry) => entry.value)
                                .toList())
                        .contains(_status))
                      DropdownMenuItem(value: _status, child: Text(_status)),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _status = value!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _masuk,
                  enabled: !_busy && !_absent,
                  decoration: const InputDecoration(
                    labelText: 'Waktu masuk (HH:mm)',
                  ),
                  validator: (value) => _absent
                      ? null
                      : _timeError(
                          value,
                          required: [
                            'hadir',
                            'terlambat',
                            'pulang',
                          ].contains(_status),
                        ),
                ),
                TextFormField(
                  controller: _pulang,
                  enabled: !_busy && !_absent,
                  decoration: const InputDecoration(
                    labelText: 'Waktu pulang (HH:mm)',
                  ),
                  validator: (value) => _absent
                      ? null
                      : _timeError(value, required: _status == 'pulang'),
                ),
                TextFormField(
                  controller: _keterangan,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan presensi',
                  ),
                  maxLines: 2,
                ),
                TextFormField(
                  controller: _reason,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Alasan koreksi (wajib)',
                  ),
                  maxLines: 2,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Alasan koreksi wajib diisi.'
                      : null,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _showAudit,
          child: const Text('Riwayat perubahan'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Menyimpan...' : 'Simpan koreksi'),
        ),
      ],
    ),
  );
}
