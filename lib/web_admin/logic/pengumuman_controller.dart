import 'package:flutter/foundation.dart';

typedef StudentRows = List<Map<String, dynamic>>;

/// Owns the selected class and ignores responses from an earlier selection.
class ClassRecipientController extends ChangeNotifier {
  ClassRecipientController({required this.loadStudents});

  final Future<StudentRows> Function(int kelasId, bool forceRefresh)
  loadStudents;
  int? kelasId;
  bool isLoading = false;
  String? error;
  StudentRows students = const [];
  int _request = 0;
  bool _disposed = false;

  bool get isReady =>
      kelasId != null && !isLoading && error == null && students.isNotEmpty;

  Future<StudentRows> snapshotForSend(int expectedClass) async {
    if (!isReady || kelasId != expectedClass) {
      throw StateError('Daftar penerima belum siap.');
    }
    await selectClass(expectedClass, forceRefresh: true);
    if (kelasId != expectedClass || !isReady) {
      throw StateError(
        error ?? 'Daftar penerima berubah atau kosong. Muat ulang kelas.',
      );
    }
    return students;
  }

  Future<void> selectClass(int? id, {bool forceRefresh = false}) async {
    final request = ++_request;
    kelasId = id;
    students = const [];
    error = null;
    isLoading = id != null;
    notifyListeners();
    if (id == null) return;
    try {
      final rows = await loadStudents(id, forceRefresh);
      if (_disposed || request != _request) return;
      students = List.unmodifiable(
        rows.map((row) => Map<String, dynamic>.unmodifiable(row)),
      );
    } catch (e) {
      if (_disposed || request != _request) return;
      error = 'Gagal memuat penerima: $e';
    } finally {
      if (!_disposed && request == _request) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}

enum DeliveryOutcome { accepted, partial, failed }

class PengumumanSendResult {
  PengumumanSendResult({
    required this.saved,
    this.storageError,
    Map<String, DeliveryOutcome> channels = const {},
    Map<String, String> errors = const {},
  }) : channels = Map.unmodifiable(channels),
       errors = Map.unmodifiable(errors);

  final bool saved;
  final String? storageError;
  final Map<String, DeliveryOutcome> channels;
  final Map<String, String> errors;
  bool get success =>
      saved &&
      channels.isNotEmpty &&
      channels.values.every((outcome) => outcome == DeliveryOutcome.accepted);
  bool get partial =>
      channels.values.any((outcome) => outcome != DeliveryOutcome.failed) &&
      !success;
  String get message {
    if (!saved) return storageError ?? 'Pengumuman belum tersimpan.';
    final details = channels.entries
        .map(
          (entry) =>
              '${entry.key}: ${switch (entry.value) {
                DeliveryOutcome.accepted => 'diterima layanan',
                DeliveryOutcome.partial => 'sebagian diterima',
                DeliveryOutcome.failed => 'gagal',
              }}',
        )
        .join(' · ');
    return '${success
        ? 'Pengumuman tersimpan.'
        : partial
        ? 'Pengiriman sebagian berhasil; input dipertahankan.'
        : 'Pengiriman gagal; input dipertahankan.'} $details';
  }
}

/// Saves before dispatch, and records every selected channel independently.
class PengumumanSender {
  PengumumanSender({required this.save});
  final Future<void> Function(Map<String, dynamic>) save;

  Future<PengumumanSendResult> send({
    required Map<String, dynamic> record,
    required Map<String, Future<DeliveryOutcome> Function()> channels,
  }) async {
    if (channels.isEmpty) {
      return PengumumanSendResult(
        saved: false,
        storageError: 'Pilih kanal pengiriman yang tersedia.',
      );
    }
    try {
      await save(Map<String, dynamic>.unmodifiable(record));
    } catch (e) {
      return PengumumanSendResult(
        saved: false,
        storageError: 'Gagal menyimpan pengumuman. Belum ada pesan dikirim: $e',
      );
    }
    final results = <String, DeliveryOutcome>{};
    final errors = <String, String>{};
    for (final channel in channels.entries) {
      try {
        results[channel.key] = await channel.value();
      } catch (e) {
        results[channel.key] = DeliveryOutcome.failed;
        errors[channel.key] = e.toString();
      }
    }
    return PengumumanSendResult(saved: true, channels: results, errors: errors);
  }
}
