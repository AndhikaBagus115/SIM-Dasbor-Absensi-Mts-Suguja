import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuratDeletionRepository {
  final SupabaseClient client;
  SuratDeletionRepository(this.client);
  static String newBatchId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<int> enqueue(List<int> ids, {required String batchId}) async {
    final result = await client.rpc(
      'enqueue_surat_deletion',
      params: {'p_batch_id': batchId, 'p_ids': ids},
    );
    return (result['deleted'] as num).toInt();
  }

  Future<Map<String, dynamic>> retryCleanup() async {
    final result = await client.functions.invoke(
      'cleanup-surat',
      body: {'action': 'retry'},
    );
    if (result.status != 200 || result.data is! Map) {
      throw StateError('Pembersihan belum selesai.');
    }
    return Map<String, dynamic>.from(result.data as Map);
  }
}
