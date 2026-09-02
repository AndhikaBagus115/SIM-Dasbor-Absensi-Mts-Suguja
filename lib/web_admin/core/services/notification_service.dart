import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';
import 'logging_service.dart';
import 'onesignal_service.dart';

/// Notification Channel Mode
enum NotificationChannel {
  whatsapp('WhatsApp'),
  onesignal('Push Notifikasi (Aplikasi)'),
  both('Keduanya (WA + Push)');

  final String displayName;
  const NotificationChannel(this.displayName);
}

/// Type of notification to send
enum NotificationType {
  absent('Siswa Tidak Hadir'),
  late('Siswa Terlambat'),
  present('Siswa Hadir'),
  pulang('Siswa Pulang');

  final String displayName;
  const NotificationType(this.displayName);
}

/// WAHA (WhatsApp HTTP API) Configuration
class WahaConfig {
  /// Base URL for WAHA API (retrieved dynamically from environment)
  static String get baseUrl => AppConstants.wahaBaseUrl;

  /// Session name for WAHA
  static String get session => AppConstants.wahaSession;

  /// Endpoint for sending text messages
  static const String sendTextEndpoint = '/api/sendText';

  /// API Key for WAHA authentication (retrieved dynamically from environment)
  static String get apiKey => AppConstants.wahaApiKey;
}

/// Model for parent notification
class ParentNotification {
  final int id;
  final int siswaId;
  final String parentPhoneNumber;
  final String studentName;
  final NotificationType type;
  final NotificationChannel channel;
  final DateTime notificationDate;
  final String? message;
  final bool isSent;
  final DateTime? sentAt;
  final String? errorMessage;

  ParentNotification({
    required this.id,
    required this.siswaId,
    required this.parentPhoneNumber,
    required this.studentName,
    required this.type,
    this.channel = NotificationChannel.whatsapp,
    required this.notificationDate,
    this.message,
    required this.isSent,
    this.sentAt,
    this.errorMessage,
  });

  factory ParentNotification.fromJson(Map<String, dynamic> json) {
    return ParentNotification(
      id: json['id'] as int,
      siswaId: json['siswa_id'] as int,
      parentPhoneNumber: json['parent_phone_number'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      type: NotificationType.values.firstWhere(
        (t) => t.name == (json['type'] as String?),
        orElse: () => NotificationType.present,
      ),
      channel: NotificationChannel.values.firstWhere(
        (c) => c.name == (json['channel'] as String?),
        orElse: () => NotificationChannel.whatsapp,
      ),
      notificationDate: json['notification_date'] != null
          ? DateTime.parse(json['notification_date'] as String)
          : DateTime.now(),
      message: json['message'] as String?,
      isSent: json['is_sent'] as bool? ?? false,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'siswa_id': siswaId,
    'parent_phone_number': parentPhoneNumber,
    'student_name': studentName,
    'type': type.name,
    'channel': channel.name,
    'notification_date': notificationDate.toIso8601String(),
    'message': message,
    'is_sent': isSent,
    'sent_at': sentAt?.toIso8601String(),
    'error_message': errorMessage,
  };
}

/// Service for sending notifications to parents (Orang Tua) after student attendance
/// Supports WhatsApp (via WAHA) and In-App Push Notifications (via OneSignal)
class NotificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // WHATSAPP HELPERS
  // ============================================================

  /// Format phone number for WhatsApp (WAHA format)
  /// Converts Indonesian phone numbers to WhatsApp chatId format
  /// Example: 08123456789 -> 628123456789@c.us
  static String _formatPhoneNumberForWhatsApp(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    } else if (cleaned.startsWith('8')) {
      cleaned = '62$cleaned';
    } else if (!cleaned.startsWith('62')) {
      cleaned = '62$cleaned';
    }

    return '$cleaned@c.us';
  }

  /// Send WhatsApp message via WAHA API
  static Future<bool> _sendWhatsAppMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final chatId = _formatPhoneNumberForWhatsApp(phoneNumber);
      final url = Uri.parse('${WahaConfig.baseUrl}${WahaConfig.sendTextEndpoint}');

      log.info(
        'Sending WhatsApp message to: $chatId',
        tag: 'NotificationService',
      );

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (WahaConfig.apiKey.isNotEmpty) {
        headers['X-Api-Key'] = WahaConfig.apiKey;
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'chatId': chatId,
          'text': message,
          'session': WahaConfig.session,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        log.info(
          'WhatsApp message sent successfully to: $chatId',
          tag: 'NotificationService',
        );
        return true;
      } else {
        log.error(
          'Failed to send WhatsApp message. Status: ${response.statusCode}, Body: ${response.body}',
          tag: 'NotificationService',
        );
        return false;
      }
    } catch (e, stackTrace) {
      log.error(
        'Error sending WhatsApp message',
        error: e,
        stackTrace: stackTrace,
        tag: 'NotificationService',
      );
      return false;
    }
  }

  /// Public method to send a direct WhatsApp message
  static Future<bool> sendDirectWhatsApp({
    required String phoneNumber,
    required String message,
  }) async {
    return _sendWhatsAppMessage(
      phoneNumber: phoneNumber,
      message: message,
    );
  }

  // ============================================================
  // UNIFIED SENDING METHODS (MULTI-CHANNEL)
  // ============================================================

  /// Send notification to parent via selected channel (WhatsApp, OneSignal Push, or Both)
  static Future<bool> sendNotificationToParent({
    required String parentPhoneNumber,
    required String studentName,
    required NotificationType type,
    required String schoolName,
    int? siswaId,
    String? nis,
    String? customMessage,
    String? alasan,
    String? waktuPulang,
    NotificationChannel channel = NotificationChannel.whatsapp,
  }) async {
    bool waSuccess = false;
    bool pushSuccess = false;

    // 1. Send via WhatsApp if selected
    if (channel == NotificationChannel.whatsapp || channel == NotificationChannel.both) {
      if (parentPhoneNumber.isNotEmpty) {
        final message = _buildNotificationMessage(
          studentName: studentName,
          type: type,
          schoolName: schoolName,
          waktuPulang: waktuPulang,
          customMessage: customMessage,
          alasan: alasan,
        );

        waSuccess = await _sendWhatsAppMessage(
          phoneNumber: parentPhoneNumber,
          message: message,
        );
      } else {
        log.warning(
          'No phone number available for WhatsApp notification ($studentName)',
          tag: 'NotificationService',
        );
      }
    }

    // 2. Send via OneSignal Push Notification if selected
    if (channel == NotificationChannel.onesignal || channel == NotificationChannel.both) {
      final pushTitle = _buildPushTitle(
        type: type,
        studentName: studentName,
        alasan: alasan,
      );
      final pushBody = _buildPushBody(
        studentName: studentName,
        type: type,
        schoolName: schoolName,
        waktuPulang: waktuPulang,
        customMessage: customMessage,
        alasan: alasan,
      );

      if (siswaId != null) {
        final pushResult = await OneSignalService.sendPushToSiswa(
          siswaId: siswaId,
          nis: nis,
          title: pushTitle,
          message: pushBody,
          data: {
            'type': type.name,
            'school_name': schoolName,
            'student_name': studentName,
            if (customMessage != null) 'custom_message': customMessage,
            if (alasan != null) 'alasan': alasan,
          },
        );
        pushSuccess = pushResult.success;
      } else {
        // Broadcast push if no specific siswaId is provided
        final pushResult = await OneSignalService.sendBroadcastPush(
          title: pushTitle,
          message: pushBody,
          data: {
            'type': type.name,
            'school_name': schoolName,
            'student_name': studentName,
            if (customMessage != null) 'custom_message': customMessage,
            if (alasan != null) 'alasan': alasan,
          },
        );
        pushSuccess = pushResult.success;
      }
    }

    // Return overall success based on requested channel
    switch (channel) {
      case NotificationChannel.whatsapp:
        return waSuccess;
      case NotificationChannel.onesignal:
        return pushSuccess;
      case NotificationChannel.both:
        // Returns true if at least one channel succeeded
        return waSuccess || pushSuccess;
    }
  }

  /// Send notification when student goes home (pulang)
  static Future<bool> sendPulangNotification({
    required String parentPhoneNumber,
    required String studentName,
    required String schoolName,
    required String waktuPulang,
    int? siswaId,
    String? nis,
    String? customMessage,
    NotificationChannel channel = NotificationChannel.whatsapp,
  }) async {
    return sendNotificationToParent(
      parentPhoneNumber: parentPhoneNumber,
      studentName: studentName,
      type: NotificationType.pulang,
      schoolName: schoolName,
      waktuPulang: waktuPulang,
      siswaId: siswaId,
      nis: nis,
      customMessage: customMessage,
      channel: channel,
    );
  }

  // ============================================================
  // DATABASE INTEGRATION METHODS
  // ============================================================

  /// Get student data from database
  static Future<Map<String, dynamic>?> _getStudentWithParentPhone(int siswaId) async {
    try {
      final response = await _supabase
          .from('siswa')
          .select('id, nis, nama, orang_tua_nama, orang_tua_nomor, kelas(nama_kelas)')
          .eq('id', siswaId)
          .single();

      return response;
    } catch (e, stackTrace) {
      log.error(
        'Failed to get student data for id: $siswaId',
        error: e,
        stackTrace: stackTrace,
        tag: 'NotificationService',
      );
      return null;
    }
  }

  /// Send notification by student ID (fetches phone & NIS from database)
  static Future<bool> sendNotificationBySiswaId({
    required int siswaId,
    required NotificationType type,
    required String schoolName,
    String? customMessage,
    String? alasan,
    String? waktuPulang,
    NotificationChannel channel = NotificationChannel.whatsapp,
  }) async {
    try {
      final studentData = await _getStudentWithParentPhone(siswaId);

      if (studentData == null) {
        log.error(
          'Student not found for id: $siswaId',
          tag: 'NotificationService',
        );
        return false;
      }

      final parentPhone = studentData['orang_tua_nomor'] as String? ?? '';
      final studentName = studentData['nama'] as String? ?? 'Siswa';
      final nis = studentData['nis'] as String?;

      if (channel == NotificationChannel.whatsapp && parentPhone.isEmpty) {
        log.warning(
          'Parent phone number not found for student: $studentName (ID: $siswaId)',
          tag: 'NotificationService',
        );
        return false;
      }

      return sendNotificationToParent(
        parentPhoneNumber: parentPhone,
        studentName: studentName,
        type: type,
        schoolName: schoolName,
        siswaId: siswaId,
        nis: nis,
        customMessage: customMessage,
        alasan: alasan,
        waktuPulang: waktuPulang,
        channel: channel,
      );
    } catch (e, stackTrace) {
      log.error(
        'Failed to send notification by siswa ID',
        error: e,
        stackTrace: stackTrace,
        tag: 'NotificationService',
      );
      return false;
    }
  }

  /// Send attendance notification (hadir/masuk) by student ID
  static Future<bool> sendHadirNotification({
    required int siswaId,
    required String schoolName,
    String? customMessage,
    NotificationChannel channel = NotificationChannel.whatsapp,
  }) async {
    return sendNotificationBySiswaId(
      siswaId: siswaId,
      type: NotificationType.present,
      schoolName: schoolName,
      customMessage: customMessage,
      channel: channel,
    );
  }

  /// Send absent notification by student ID
  static Future<bool> sendAbsentNotification({
    required int siswaId,
    required String schoolName,
    String? customMessage,
    String? alasan,
    NotificationChannel channel = NotificationChannel.whatsapp,
  }) async {
    return sendNotificationBySiswaId(
      siswaId: siswaId,
      type: NotificationType.absent,
      schoolName: schoolName,
      customMessage: customMessage,
      alasan: alasan,
      channel: channel,
    );
  }

  /// Send late notification by student ID
  static Future<bool> sendLateNotification({
    required int siswaId,
    required String schoolName,
    String? customMessage,
    NotificationChannel channel = NotificationChannel.whatsapp,
  }) async {
    return sendNotificationBySiswaId(
      siswaId: siswaId,
      type: NotificationType.late,
      schoolName: schoolName,
      customMessage: customMessage,
      channel: channel,
    );
  }

  /// Send pulang notification by student ID
  static Future<bool> sendPulangNotificationBySiswaId({
    required int siswaId,
    required String schoolName,
    String? customMessage,
    String? waktuPulang,
    NotificationChannel channel = NotificationChannel.whatsapp,
  }) async {
    return sendNotificationBySiswaId(
      siswaId: siswaId,
      type: NotificationType.pulang,
      schoolName: schoolName,
      customMessage: customMessage,
      waktuPulang: waktuPulang,
      channel: channel,
    );
  }

  /// Send notifications for all absent students today
  static Future<void> sendNotificationsForAbsentStudentsToday({
    required String schoolName,
    NotificationChannel channel = NotificationChannel.onesignal,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final absentRecords = await _supabase
          .from('absensi')
          .select('siswa_id, siswa(id, nis, nama, orang_tua_nomor)')
          .eq('tanggal', today)
          .eq('status', 'alpa');

      log.info(
        'Found ${(absentRecords as List).length} absent students today. Sending via ${channel.displayName}',
        tag: 'NotificationService',
      );

      for (final record in absentRecords) {
        final siswa = record['siswa'];
        if (siswa == null) continue;

        final parentPhone = siswa['orang_tua_nomor'] as String? ?? '';
        final studentName = siswa['nama'] as String? ?? 'Siswa';
        final siswaId = siswa['id'] as int?;
        final nis = siswa['nis'] as String?;

        await sendNotificationToParent(
          parentPhoneNumber: parentPhone,
          studentName: studentName,
          type: NotificationType.absent,
          schoolName: schoolName,
          siswaId: siswaId,
          nis: nis,
          channel: channel,
        );

        // Add small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 250));
      }

      log.info(
        'Completed sending notifications for absent students',
        tag: 'NotificationService',
      );
    } catch (e, stackTrace) {
      log.error(
        'Error sending notifications for absent students',
        error: e,
        stackTrace: stackTrace,
        tag: 'NotificationService',
      );
    }
  }

  /// Send batch notifications for daily attendance
  static Future<void> sendDailyAttendanceNotifications({
    required List<Map<String, dynamic>> absentStudents,
    required List<Map<String, dynamic>> lateStudents,
    required String schoolName,
    NotificationChannel channel = NotificationChannel.onesignal,
  }) async {
    try {
      log.info(
        'Starting batch notification send (${channel.displayName}): ${absentStudents.length} absent, ${lateStudents.length} late',
        tag: 'NotificationService',
      );

      // Absent students
      for (final student in absentStudents) {
        await sendNotificationToParent(
          parentPhoneNumber: student['parent_phone'] as String? ?? '',
          studentName: student['student_name'] as String,
          type: NotificationType.absent,
          schoolName: schoolName,
          siswaId: student['siswa_id'] as int?,
          nis: student['nis'] as String?,
          channel: channel,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Late students
      for (final student in lateStudents) {
        await sendNotificationToParent(
          parentPhoneNumber: student['parent_phone'] as String? ?? '',
          studentName: student['student_name'] as String,
          type: NotificationType.late,
          schoolName: schoolName,
          siswaId: student['siswa_id'] as int?,
          nis: student['nis'] as String?,
          channel: channel,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      log.info(
        'Batch notifications completed',
        tag: 'NotificationService',
      );
    } catch (e, stackTrace) {
      log.error(
        'Error sending batch notifications',
        error: e,
        stackTrace: stackTrace,
        tag: 'NotificationService',
      );
    }
  }

  // ============================================================
  // TEST METHODS
  // ============================================================

  /// Test WAHA connection by sending a test message
  static Future<bool> testWahaConnection({
    required String testPhoneNumber,
  }) async {
    log.info(
      'Testing WAHA connection to: $testPhoneNumber',
      tag: 'NotificationService',
    );

    return _sendWhatsAppMessage(
      phoneNumber: testPhoneNumber,
      message: '''*TEST KONEKSI WAHA*

Ini adalah pesan test dari Sistem Absensi MTs.
Jika Anda menerima pesan ini, berarti integrasi WhatsApp Gateway (WAHA) berhasil!

Waktu: ${DateTime.now().toString().split('.')[0]}''',
    );
  }

  /// Test OneSignal connection
  static Future<Map<String, dynamic>> testOneSignalConnection() async {
    return OneSignalService.testConnection();
  }

  /// Test sending notification by siswa ID from database
  static Future<Map<String, dynamic>> testNotificationBySiswaId({
    required int siswaId,
    required String schoolName,
    NotificationType type = NotificationType.present,
    NotificationChannel channel = NotificationChannel.both,
    String? customMessage,
    String? alasan,
    String? waktuPulang,
  }) async {
    final result = <String, dynamic>{
      'success': false,
      'siswaId': siswaId,
      'studentName': null,
      'parentPhone': null,
      'channel': channel.displayName,
      'message': '',
      'waSuccess': false,
      'pushSuccess': false,
      'details': <String>[],
    };

    try {
      // 1. Fetch student data
      final studentData = await _getStudentWithParentPhone(siswaId);

      if (studentData == null) {
        result['message'] = 'Siswa dengan ID $siswaId tidak ditemukan di database';
        log.error(result['message'] as String, tag: 'NotificationService');
        return result;
      }

      result['studentName'] = studentData['nama'];
      result['parentPhone'] = studentData['orang_tua_nomor'];
      final parentPhone = studentData['orang_tua_nomor'] as String? ?? '';
      final studentName = studentData['nama'] as String? ?? 'Siswa';
      final nis = studentData['nis'] as String?;

      final logDetails = <String>[];

      // 2. Dispatch based on channel
      if (channel == NotificationChannel.whatsapp || channel == NotificationChannel.both) {
        if (parentPhone.isNotEmpty) {
          final message = _buildNotificationMessage(
            studentName: studentName,
            type: type,
            schoolName: schoolName,
            customMessage: customMessage,
            alasan: alasan,
            waktuPulang: waktuPulang,
          );
          final waOk = await _sendWhatsAppMessage(
            phoneNumber: parentPhone,
            message: message,
          );
          result['waSuccess'] = waOk;
          logDetails.add(waOk ? 'WhatsApp: Terkirim ke $parentPhone' : 'WhatsApp: Gagal kirim');
        } else {
          logDetails.add('WhatsApp: Nomor orang tua kosong');
        }
      }

      if (channel == NotificationChannel.onesignal || channel == NotificationChannel.both) {
        final pushTitle = _buildPushTitle(
          type: type,
          studentName: studentName,
          alasan: alasan,
        );
        final pushBody = _buildPushBody(
          studentName: studentName,
          type: type,
          schoolName: schoolName,
          waktuPulang: waktuPulang,
          customMessage: customMessage,
          alasan: alasan,
        );

        final pushRes = await OneSignalService.sendPushToSiswa(
          siswaId: siswaId,
          nis: nis,
          title: pushTitle,
          message: pushBody,
          data: {
            'type': type.name,
            'school_name': schoolName,
            'student_name': studentName,
            if (customMessage != null) 'custom_message': customMessage,
            if (alasan != null) 'alasan': alasan,
          },
        );

        result['pushSuccess'] = pushRes.success;
        logDetails.add('OneSignal: ${pushRes.message}');
      }

      result['details'] = logDetails;

      final isOverallSuccess = (channel == NotificationChannel.whatsapp && result['waSuccess'] == true) ||
          (channel == NotificationChannel.onesignal && result['pushSuccess'] == true) ||
          (channel == NotificationChannel.both &&
              (result['waSuccess'] == true || result['pushSuccess'] == true));

      result['success'] = isOverallSuccess;
      result['message'] = logDetails.join(' | ');

      return result;
    } catch (e, stackTrace) {
      result['message'] = 'Error: $e';
      log.error(
        'Test notification failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'NotificationService',
      );
      return result;
    }
  }

  /// Get all students with parent phone numbers (for testing/debugging)
  static Future<List<Map<String, dynamic>>> getStudentsWithPhoneNumbers({
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('siswa')
          .select('id, nis, nama, orang_tua_nama, orang_tua_nomor, status')
          .not('orang_tua_nomor', 'is', null)
          .neq('orang_tua_nomor', '')
          .eq('status', 'aktif')
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      log.error('Failed to get students with phone numbers: $e', tag: 'NotificationService');
      return [];
    }
  }

  // ============================================================
  // PUBLIC PREVIEW FORMATTING HELPERS
  // ============================================================

  /// Format preview message for WhatsApp
  static String formatWhatsAppPreview({
    required String studentName,
    required NotificationType type,
    required String schoolName,
    String? customMessage,
    String? alasan,
    String? waktuPulang,
  }) {
    return _buildNotificationMessage(
      studentName: studentName,
      type: type,
      schoolName: schoolName,
      customMessage: customMessage,
      alasan: alasan,
      waktuPulang: waktuPulang,
    );
  }

  /// Format preview body for OneSignal Push Notification
  static String formatPushPreview({
    required String studentName,
    required NotificationType type,
    required String schoolName,
    String? customMessage,
    String? alasan,
    String? waktuPulang,
  }) {
    return _buildPushBody(
      studentName: studentName,
      type: type,
      schoolName: schoolName,
      customMessage: customMessage,
      alasan: alasan,
      waktuPulang: waktuPulang,
    );
  }

  /// Format preview title for OneSignal Push Notification
  static String formatPushTitlePreview({
    required String studentName,
    required NotificationType type,
    String? alasan,
  }) {
    return _buildPushTitle(
      type: type,
      studentName: studentName,
      alasan: alasan,
    );
  }

  // ============================================================
  // MESSAGE FORMATTING HELPERS
  // ============================================================

  /// Build headline/title for Push Notification
  static String _buildPushTitle({
    required NotificationType type,
    required String studentName,
    String? alasan,
  }) {
    switch (type) {
      case NotificationType.present:
        return 'Presensi Masuk: $studentName';
      case NotificationType.late:
        return 'Siswa Terlambat: $studentName';
      case NotificationType.absent:
        if (alasan != null && alasan.trim().isNotEmpty) {
          return 'Siswa Tidak Hadir ($alasan): $studentName';
        }
        return 'Siswa Tidak Hadir: $studentName';
      case NotificationType.pulang:
        return 'Presensi Pulang: $studentName';
    }
  }

  /// Build concise body for smartphone Push Notification
  static String _buildPushBody({
    required String studentName,
    required NotificationType type,
    required String schoolName,
    String? waktuPulang,
    String? customMessage,
    String? alasan,
  }) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final hasCustom = customMessage != null && customMessage.trim().isNotEmpty;
    final extraNote = hasCustom ? ' Pesan: $customMessage' : '';

    switch (type) {
      case NotificationType.present:
        return '$studentName telah tercatat HADIR di $schoolName pada $timeStr ($dateStr).$extraNote';
      case NotificationType.late:
        return '$studentName tercatat TERLAMBAT di $schoolName pada $timeStr ($dateStr).$extraNote';
      case NotificationType.absent:
        final statusLabel = (alasan != null && alasan.trim().isNotEmpty)
            ? 'TIDAK HADIR ($alasan)'
            : 'TIDAK HADIR (Alpa)';
        return '$studentName $statusLabel di $schoolName pada hari ini ($dateStr).$extraNote';
      case NotificationType.pulang:
        return '$studentName telah PULANG dari sekolah pada ${waktuPulang ?? timeStr} ($dateStr).$extraNote';
    }
  }

  /// Build formatted WhatsApp text message
  static String _buildNotificationMessage({
    required String studentName,
    required NotificationType type,
    required String schoolName,
    String? waktuPulang,
    String? customMessage,
    String? alasan,
  }) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final hasCustom = customMessage != null && customMessage.trim().isNotEmpty;

    switch (type) {
      case NotificationType.absent:
        String statusLabel = 'Tidak Hadir (Alpa)';
        if (alasan != null && alasan.trim().isNotEmpty) {
          if (alasan.toLowerCase().contains('tidak hadir')) {
            statusLabel = alasan;
          } else {
            statusLabel = 'Tidak Hadir ($alasan)';
          }
        }

        final pesanSection = hasCustom
            ? '''

*Pesan untuk Orang Tua:*
$customMessage'''
            : '''

Apabila ada surat izin/keterangan sakit, mohon segera konfirmasi ke pihak sekolah.''';

        return '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

*INFORMASI KETIDAKHADIRAN SISWA*

Nama Siswa: *$studentName*
Status: *$statusLabel*
Sekolah: $schoolName
Tanggal: $dateStr
Waktu Laporan: $timeStr$pesanSection

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Otomatis dari Sistem Absensi ${schoolName}_''';

      case NotificationType.late:
        final pesanSection = hasCustom
            ? '''

*Pesan untuk Orang Tua:*
$customMessage'''
            : '''

Mohon perhatian Bapak/Ibu untuk kedisiplinan waktu keberangkatan siswa.''';

        return '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

*INFORMASI KETERLAMBATAN SISWA*

Nama Siswa: *$studentName*
Status: *Terlambat*
Sekolah: $schoolName
Tanggal: $dateStr
Waktu Masuk: $timeStr$pesanSection

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Otomatis dari Sistem Absensi ${schoolName}_''';

      case NotificationType.present:
        final pesanSection = hasCustom
            ? '''

*Pesan untuk Orang Tua:*
$customMessage'''
            : '''

Terima kasih atas kerja samanya.''';

        return '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

*INFORMASI KEHADIRAN SISWA*

Nama Siswa: *$studentName*
Status: *Hadir Tepat Waktu*
Sekolah: $schoolName
Tanggal: $dateStr
Waktu Hadir: $timeStr$pesanSection

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Otomatis dari Sistem Absensi ${schoolName}_''';

      case NotificationType.pulang:
        final pesanSection = hasCustom
            ? '''

*Pesan untuk Orang Tua:*
$customMessage'''
            : '''

Siswa telah selesai mengikuti KBM dan meninggalkan sekolah.''';

        return '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

*INFORMASI KEPULANGAN SISWA*

Nama Siswa: *$studentName*
Status: *Sudah Pulang*
Sekolah: $schoolName
Tanggal: $dateStr
Waktu Pulang: ${waktuPulang ?? timeStr}$pesanSection

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Otomatis dari Sistem Absensi ${schoolName}_''';
    }
  }
}
