import 'admin_notification_gateway.dart';

/// Response structure from OneSignal Push API
class OneSignalPushResult {
  factory OneSignalPushResult.fromApi(Map<String, dynamic> body) {
    final id = (body['id'] as String?)?.trim();
    final created = id != null && id.isNotEmpty;
    final errors = body['errors'];
    final warnings = errors is List
        ? errors.isNotEmpty
        : errors is Map
        ? errors.isNotEmpty
        : errors != null && errors.toString().isNotEmpty;
    return OneSignalPushResult(
      success: created,
      partial: created && warnings,
      notificationId: created ? id : null,
      recipients: (body['recipients'] as num?)?.toInt() ?? 0,
      message: created && warnings
          ? 'Sebagian target belum diterima: $errors (ID: $id).'
          : created
          ? 'Permintaan notifikasi diterima layanan (ID: $id).'
          : 'Notifikasi tidak dibuat: ${body['errors'] ?? 'tidak ada penerima aktif'}.',
      rawResponse: body,
    );
  }

  final bool success;
  final bool partial;
  final String? notificationId;
  final int recipients;
  final String message;
  final Map<String, dynamic>? rawResponse;

  OneSignalPushResult({
    required this.success,
    this.partial = false,
    this.notificationId,
    this.recipients = 0,
    required this.message,
    this.rawResponse,
  });

  @override
  String toString() =>
      'OneSignalPushResult(success: $success, id: $notificationId, recipients: $recipients, message: $message)';
}

/// Notifications are authorized and addressed by the server.
class OneSignalService {
  static bool get isConfigured => AdminNotificationGateway.onesignalConfigured;

  static Future<bool> verifyConnection() async {
    await AdminNotificationGateway.refreshStatus();
    if (!isConfigured) return false;
    final result = await AdminNotificationGateway.call({'action': 'verify'});
    return result['success'] == true;
  }

  static Future<OneSignalPushResult> _send({
    required String title,
    required String message,
    required Map<String, dynamic> target,
    Map<String, dynamic>? data,
  }) async {
    try {
      final result = await AdminNotificationGateway.call({
        'action': 'push',
        'title': title,
        'message': message,
        'target': target,
        if (data != null) 'data': data,
      });
      return OneSignalPushResult(
        success:
            result['success'] == true &&
            (result['id'] as String? ?? '').trim().isNotEmpty,
        partial: result['partial'] == true,
        notificationId: result['id'] as String?,
        recipients: (result['recipients'] as num?)?.toInt() ?? 0,
        message:
            result['message'] as String? ?? 'Respons gateway tidak lengkap.',
      );
    } catch (_) {
      return OneSignalPushResult(
        success: false,
        message: 'Pengiriman gagal. Periksa sesi admin dan gateway server.',
      );
    }
  }

  static Future<OneSignalPushResult> sendPushToSiswa({
    required int siswaId,
    String? nis,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) => _send(
    title: title,
    message: message,
    target: {'type': 'siswa', 'id': siswaId},
    data: data,
  );

  static Future<OneSignalPushResult> sendBroadcastPush({
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) => _send(
    title: title,
    message: message,
    target: {'type': 'semua'},
    data: data,
  );

  static Future<OneSignalPushResult> sendPengumumanPush({
    required String judul,
    required String isi,
    required String targetTipe,
    int? siswaId,
    int? kelasId,
    List<String>? studentExternalIds,
  }) => _send(
    title: judul,
    message: isi,
    target: {
      'type': targetTipe,
      if (targetTipe == 'siswa') 'id': siswaId,
      if (targetTipe == 'kelas') 'id': kelasId,
    },
    data: {'type': 'pengumuman'},
  );

  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final ok = await verifyConnection();
      return {
        'success': ok,
        'message': ok
            ? 'Koneksi OneSignal server valid.'
            : 'OneSignal server belum siap atau verifikasi gagal.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Gateway server tidak tersedia.'};
    }
  }
}
