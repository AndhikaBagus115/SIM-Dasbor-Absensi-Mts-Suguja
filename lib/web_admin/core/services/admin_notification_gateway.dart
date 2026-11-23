import 'package:supabase_flutter/supabase_flutter.dart';

/// The client never receives provider credentials, endpoints, or raw errors.
class AdminNotificationGateway {
  static bool onesignalConfigured = false;
  static bool whatsappConfigured = false;
  static int _generation = 0;

  static void clear() {
    _generation++;
    onesignalConfigured = false;
    whatsappConfigured = false;
  }

  static Future<Map<String, dynamic>> call(Map<String, dynamic> body) async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw StateError('Login admin diperlukan.');
    }
    try {
      final result = await client.functions
          .invoke('admin-notifications', body: body)
          .timeout(const Duration(seconds: 15));
      if (result.status != 200 || result.data is! Map) {
        throw StateError('Gateway notifikasi tidak tersedia.');
      }
      return Map<String, dynamic>.from(result.data as Map);
    } on FunctionException {
      throw StateError(
        'Gateway menolak permintaan. Periksa sesi admin dan aktivasi server.',
      );
    }
  }

  static Future<void> refreshStatus() async {
    final generation = _generation;
    final status = await call({'action': 'status'});
    if (generation != _generation) return;
    onesignalConfigured = status['onesignal'] == true;
    whatsappConfigured = status['whatsapp'] == true;
  }
}
