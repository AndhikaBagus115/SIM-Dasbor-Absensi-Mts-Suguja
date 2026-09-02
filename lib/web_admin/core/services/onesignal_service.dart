import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'logging_service.dart';

/// Response structure from OneSignal Push API
class OneSignalPushResult {
  final bool success;
  final String? notificationId;
  final int recipients;
  final String message;
  final Map<String, dynamic>? rawResponse;

  OneSignalPushResult({
    required this.success,
    this.notificationId,
    this.recipients = 0,
    required this.message,
    this.rawResponse,
  });

  @override
  String toString() =>
      'OneSignalPushResult(success: $success, id: $notificationId, recipients: $recipients, message: $message)';
}

/// Service for sending Push Notifications to mobile apps via OneSignal REST API
class OneSignalService {
  static const String _baseUrl = 'https://onesignal.com/api/v1';

  static String get appId => AppConstants.onesignalAppId;
  static String get restApiKey => AppConstants.onesignalRestApiKey;

  /// Check if OneSignal configuration is complete
  static bool get isConfigured =>
      appId.trim().isNotEmpty && restApiKey.trim().isNotEmpty;

  /// Verify connection to OneSignal REST API
  static Future<bool> verifyConnection() async {
    if (!isConfigured) return false;
    try {
      final url = Uri.parse('$_baseUrl/apps/$appId');
      final resp = await http.get(
        url,
        headers: {
          'Authorization': 'Key $restApiKey',
        },
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send push notification via OneSignal REST API
  /// 
  /// [title] Notification headline/title
  /// [message] Notification body text
  /// [targetExternalUserIds] List of external user IDs (e.g. `["siswa_12", "12", "NIS123"]`)
  /// [targetSegments] List of target segments (e.g. `["Total Subscriptions"]`)
  /// [additionalData] Custom payload map passed to the client app
  /// [subtitle] Optional subtitle
  static Future<OneSignalPushResult> sendPushNotification({
    required String title,
    required String message,
    List<String>? targetExternalUserIds,
    List<String>? targetSegments,
    Map<String, dynamic>? additionalData,
    String? subtitle,
  }) async {
    if (!isConfigured) {
      log.warning(
        'OneSignal is not configured. Please set ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY in .env',
        tag: 'OneSignalService',
      );
      return OneSignalPushResult(
        success: false,
        message:
            'OneSignal belum dikonfigurasi. Isi ONESIGNAL_APP_ID dan ONESIGNAL_REST_API_KEY di file .env',
      );
    }

    try {
      final url = Uri.parse('$_baseUrl/notifications');

      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Key $restApiKey',
      };

      final payload = <String, dynamic>{
        'app_id': appId,
        'headings': {'en': title, 'id': title},
        'contents': {'en': message, 'id': message},
        'target_channel': 'push',
      };

      if (subtitle != null && subtitle.isNotEmpty) {
        payload['subtitle'] = {'en': subtitle, 'id': subtitle};
      }

      if (additionalData != null && additionalData.isNotEmpty) {
        payload['data'] = additionalData;
      }

      // Targeting Logic
      if (targetExternalUserIds != null && targetExternalUserIds.isNotEmpty) {
        // OneSignal v5 format & legacy backward compatibility
        payload['include_aliases'] = {
          'external_id': targetExternalUserIds,
        };
        payload['include_external_user_ids'] = targetExternalUserIds;
        payload['channel_for_external_user_ids'] = 'push';
      } else if (targetSegments != null && targetSegments.isNotEmpty) {
        payload['included_segments'] = targetSegments;
      } else {
        // Default fallback to all subscribed users
        payload['included_segments'] = ['Total Subscriptions'];
      }

      log.info(
        'Sending OneSignal push notification: Title="$title", Target=${targetExternalUserIds ?? targetSegments ?? "All"}',
        tag: 'OneSignalService',
      );

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final notificationId = responseBody['id'] as String?;
        final recipients = (responseBody['recipients'] as num?)?.toInt() ?? 0;
        final errors = responseBody['errors'];

        if (errors != null && (errors is List && errors.isNotEmpty || errors is Map)) {
          log.warning(
            'OneSignal returned partial errors: $errors',
            tag: 'OneSignalService',
          );
        }

        log.info(
          'OneSignal push sent successfully (ID: $notificationId, recipients: $recipients)',
          tag: 'OneSignalService',
        );

        return OneSignalPushResult(
          success: true,
          notificationId: notificationId,
          recipients: recipients,
          message: recipients > 0
              ? 'Push notification berhasil dikirim ke $recipients perangkat'
              : 'Push notification terkirim (ID: $notificationId)',
          rawResponse: responseBody,
        );
      } else {
        final errors = responseBody['errors'];
        final errorMsg = errors != null
            ? errors.toString()
            : 'HTTP Error ${response.statusCode}: ${response.body}';

        log.error(
          'Failed to send OneSignal push. Status: ${response.statusCode}, Body: ${response.body}',
          tag: 'OneSignalService',
        );

        return OneSignalPushResult(
          success: false,
          message: 'Gagal kirim OneSignal ($errorMsg)',
          rawResponse: responseBody,
        );
      }
    } catch (e, stackTrace) {
      log.error(
        'Exception sending OneSignal push notification',
        error: e,
        stackTrace: stackTrace,
        tag: 'OneSignalService',
      );
      return OneSignalPushResult(
        success: false,
        message: 'Terjadi kesalahan sistem saat kirim push: $e',
      );
    }
  }

  /// Send push notification targeted specifically to a student's parents
  /// Targets multiple aliases: `siswa_{id}`, `{id}`, and `{nis}` if available
  static Future<OneSignalPushResult> sendPushToSiswa({
    required int siswaId,
    String? nis,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final targets = <String>[
      'siswa_$siswaId',
      '$siswaId',
    ];

    if (nis != null && nis.trim().isNotEmpty) {
      targets.add('nis_${nis.trim()}');
      targets.add(nis.trim());
    }

    final payloadData = {
      'siswa_id': siswaId,
      if (nis != null) 'nis': nis,
      'timestamp': DateTime.now().toIso8601String(),
      ...?data,
    };

    return sendPushNotification(
      title: title,
      message: message,
      targetExternalUserIds: targets,
      additionalData: payloadData,
    );
  }

  /// Send broadcast push notification to all subscribed mobile app users
  static Future<OneSignalPushResult> sendBroadcastPush({
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    return sendPushNotification(
      title: title,
      message: message,
      targetSegments: ['Total Subscriptions'],
      additionalData: data,
    );
  }

  /// Send Pengumuman Push Notification strictly conforming to mobile app external_id rules
  ///
  /// Target = semua: uses `included_segments: ["Total Subscriptions"]`, data: `{"type": "pengumuman"}`
  /// Target = siswa: uses `include_aliases: {"external_id": ["94"]}`, data: `{"type": "pengumuman", "siswa_id": 94}`
  /// Target = kelas: uses `include_aliases: {"external_id": ["94", "95", ...]}`, data: `{"type": "pengumuman", "kelas_id": 1}`
  static Future<OneSignalPushResult> sendPengumumanPush({
    required String judul,
    required String isi,
    required String targetTipe, // 'semua' | 'kelas' | 'siswa'
    int? siswaId,
    int? kelasId,
    List<String>? studentExternalIds,
  }) async {
    if (!isConfigured) {
      log.warning(
        'OneSignal is not configured. Please set ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY in .env',
        tag: 'OneSignalService',
      );
      return OneSignalPushResult(
        success: false,
        message:
            'OneSignal belum dikonfigurasi. Isi ONESIGNAL_APP_ID dan ONESIGNAL_REST_API_KEY di file .env',
      );
    }

    try {
      final url = Uri.parse('$_baseUrl/notifications');

      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Key $restApiKey',
      };

      final payload = <String, dynamic>{
        'app_id': appId,
        'headings': {'en': judul},
        'contents': {'en': isi},
        'target_channel': 'push',
      };

      if (targetTipe == 'semua') {
        payload['included_segments'] = ['Total Subscriptions'];
        payload['data'] = {'type': 'pengumuman'};
      } else if (targetTipe == 'siswa') {
        final idStr = siswaId != null
            ? '$siswaId'
            : (studentExternalIds != null && studentExternalIds.isNotEmpty
                ? studentExternalIds.first
                : '');
        payload['target_channel'] = 'push';
        payload['include_aliases'] = {
          'external_id': [idStr],
        };
        payload['include_external_user_ids'] = [idStr];
        payload['channel_for_external_user_ids'] = 'push';
        payload['data'] = {
          'type': 'pengumuman',
          if (siswaId != null) 'siswa_id': siswaId,
        };
      } else if (targetTipe == 'kelas') {
        final extIds = studentExternalIds ?? [];
        payload['target_channel'] = 'push';
        payload['include_aliases'] = {
          'external_id': extIds,
        };
        payload['include_external_user_ids'] = extIds;
        payload['channel_for_external_user_ids'] = 'push';
        payload['data'] = {
          'type': 'pengumuman',
          if (kelasId != null) 'kelas_id': kelasId,
        };
      }

      log.info(
        'Sending OneSignal Pengumuman: Target=$targetTipe, Title="$judul"',
        tag: 'OneSignalService',
      );

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final notificationId = responseBody['id'] as String?;
        final recipients = (responseBody['recipients'] as num?)?.toInt() ?? 0;
        final errors = responseBody['errors'];

        if (errors != null) {
          log.warning(
            'OneSignal returned warning/errors: $errors',
            tag: 'OneSignalService',
          );
        }

        return OneSignalPushResult(
          success: true,
          notificationId: notificationId,
          recipients: recipients,
          message: recipients > 0
              ? 'Push notification berhasil dikirim ke $recipients perangkat'
              : 'Push notification berhasil dikirim (ID: $notificationId)',
          rawResponse: responseBody,
        );
      } else {
        final errors = responseBody['errors'];
        final errorMsg = errors != null
            ? errors.toString()
            : 'HTTP Error ${response.statusCode}: ${response.body}';

        log.error(
          'Failed to send OneSignal Pengumuman. Status: ${response.statusCode}, Body: ${response.body}',
          tag: 'OneSignalService',
        );

        return OneSignalPushResult(
          success: false,
          message: 'Gagal kirim OneSignal: $errorMsg',
          rawResponse: responseBody,
        );
      }
    } catch (e, stackTrace) {
      log.error(
        'Exception sending OneSignal Pengumuman',
        error: e,
        stackTrace: stackTrace,
        tag: 'OneSignalService',
      );
      return OneSignalPushResult(
        success: false,
        message: 'Terjadi kesalahan sistem saat kirim pengumuman: $e',
      );
    }
  }

  /// Test connection with OneSignal REST API by verifying App ID and REST Key
  /// Uses the notifications endpoint which has full CORS support on Web
  static Future<Map<String, dynamic>> testConnection() async {
    if (!isConfigured) {
      return {
        'success': false,
        'message':
            'OneSignal belum dikonfigurasi. Isi ONESIGNAL_APP_ID dan ONESIGNAL_REST_API_KEY di file .env',
      };
    }

    try {
      final url = Uri.parse('$_baseUrl/notifications');
      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Key $restApiKey',
      };

      // Lightweight probe request
      final payload = {
        'app_id': appId,
        'include_aliases': {
          'external_id': ['_connection_probe_test_'],
        },
        'target_channel': 'push',
        'headings': {'en': 'Probe Connection'},
        'contents': {'en': 'Verifying OneSignal API Key Connection'},
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': '[SUKSES] Koneksi OneSignal REST API Berhasil! Kredensial Valid & Siap Digunakan.',
          'data': data,
        };
      } else {
        final errors = data['errors'] ?? response.body;
        return {
          'success': false,
          'message': 'Gagal validasi OneSignal ($errors)',
          'data': data,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error koneksi ke OneSignal API: $e',
      };
    }
  }
}
