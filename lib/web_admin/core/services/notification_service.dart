import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';
import 'logging_service.dart';

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
    'notification_date': notificationDate.toIso8601String(),
    'message': message,
    'is_sent': isSent,
    'sent_at': sentAt?.toIso8601String(),
    'error_message': errorMessage,
  };
}

/// Service for sending notifications to parents (Orang Tua) after student attendance
class NotificationService {
  /// Format phone number for WhatsApp (WAHA format)
  /// Converts Indonesian phone numbers to WhatsApp chatId format
  /// Example: 08123456789 -> 628123456789@c.us
  static String _formatPhoneNumberForWhatsApp(String phoneNumber) {
    // Remove all non-numeric characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle Indonesian phone numbers
    if (cleaned.startsWith('0')) {
      // Replace leading 0 with 62 (Indonesia country code)
      cleaned = '62${cleaned.substring(1)}';
    } else if (cleaned.startsWith('8')) {
      // Add 62 prefix if starting with 8
      cleaned = '62$cleaned';
    } else if (!cleaned.startsWith('62')) {
      // Add 62 if no country code
      cleaned = '62$cleaned';
    }
    
    // Return in WAHA chatId format
    return '$cleaned@c.us';
  }

  /// Send WhatsApp message via WAHA API
  /// Returns true if message was sent successfully
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

      // Build headers with API Key authentication
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      // Add API Key if configured
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

  /// Send notification to parent via WhatsApp using WAHA API
  /// 
  /// Returns true if notification was sent successfully
  static Future<bool> sendNotificationToParent({
    required String parentPhoneNumber,
    required String studentName,
    required NotificationType type,
    required String schoolName,
    String? customMessage,
    String? waktuPulang,
  }) async {
    try {
      log.info(
        'Sending notification to parent: $parentPhoneNumber for student: $studentName (${type.displayName})',
        tag: 'NotificationService',
      );

      // Build WhatsApp message
      final message = customMessage ?? _buildNotificationMessage(
        studentName: studentName,
        type: type,
        schoolName: schoolName,
        waktuPulang: waktuPulang,
      );

      log.info(
        'Notification message: $message',
        tag: 'NotificationService',
      );

      // Send via WAHA WhatsApp API
      final success = await _sendWhatsAppMessage(
        phoneNumber: parentPhoneNumber,
        message: message,
      );
      
      if (success) {
        log.info(
          'Notification sent successfully to: $parentPhoneNumber',
          tag: 'NotificationService',
        );
      }

      return success;
    } catch (e, stackTrace) {
      log.error(
        'Failed to send notification to parent',
        error: e,
        stackTrace: stackTrace,
        tag: 'NotificationService',
      );
      return false;
    }
  }

  /// Send notification when student goes home (pulang)
  static Future<bool> sendPulangNotification({
    required String parentPhoneNumber,
    required String studentName,
    required String schoolName,
    required String waktuPulang,
  }) async {
    return sendNotificationToParent(
      parentPhoneNumber: parentPhoneNumber,
      studentName: studentName,
      type: NotificationType.pulang,
      schoolName: schoolName,
      waktuPulang: waktuPulang,
    );
  }

  // ============================================================
  // DATABASE INTEGRATION METHODS
  // ============================================================

  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get student data with parent phone number from database
  /// Returns student info including parent phone number
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

  /// Send notification to parent by student ID (fetches phone from database)
  /// This is the main method to use when you have a siswa_id
  static Future<bool> sendNotificationBySiswaId({
    required int siswaId,
    required NotificationType type,
    required String schoolName,
    String? waktuPulang,
  }) async {
    try {
      // Fetch student data from database
      final studentData = await _getStudentWithParentPhone(siswaId);
      
      if (studentData == null) {
        log.error(
          'Student not found for id: $siswaId',
          tag: 'NotificationService',
        );
        return false;
      }

      final parentPhone = studentData['orang_tua_nomor'] as String?;
      final studentName = studentData['nama'] as String? ?? 'Siswa';

      if (parentPhone == null || parentPhone.isEmpty) {
        log.warning(
          'Parent phone number not found for student: $studentName (ID: $siswaId)',
          tag: 'NotificationService',
        );
        return false;
      }

      // Send notification
      return sendNotificationToParent(
        parentPhoneNumber: parentPhone,
        studentName: studentName,
        type: type,
        schoolName: schoolName,
        waktuPulang: waktuPulang,
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
  }) async {
    return sendNotificationBySiswaId(
      siswaId: siswaId,
      type: NotificationType.present,
      schoolName: schoolName,
    );
  }

  /// Send absent notification by student ID
  static Future<bool> sendAbsentNotification({
    required int siswaId,
    required String schoolName,
  }) async {
    return sendNotificationBySiswaId(
      siswaId: siswaId,
      type: NotificationType.absent,
      schoolName: schoolName,
    );
  }

  /// Send late notification by student ID
  static Future<bool> sendLateNotification({
    required int siswaId,
    required String schoolName,
  }) async {
    return sendNotificationBySiswaId(
      siswaId: siswaId,
      type: NotificationType.late,
      schoolName: schoolName,
    );
  }

  /// Send pulang/going home notification by student ID
  static Future<bool> sendPulangNotificationBySiswaId({
    required int siswaId,
    required String schoolName,
    String? waktuPulang,
  }) async {
    return sendNotificationBySiswaId(
      siswaId: siswaId,
      type: NotificationType.pulang,
      schoolName: schoolName,
      waktuPulang: waktuPulang,
    );
  }

  /// Send notifications for all absent students today
  /// Fetches absent students from database and sends notifications
  static Future<void> sendNotificationsForAbsentStudentsToday({
    required String schoolName,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Get all absent students today
      final absentRecords = await _supabase
          .from('absensi')
          .select('siswa_id, siswa(id, nama, orang_tua_nomor)')
          .eq('tanggal', today)
          .eq('status', 'alpa');

      log.info(
        'Found ${(absentRecords as List).length} absent students today',
        tag: 'NotificationService',
      );

      for (final record in absentRecords) {
        final siswa = record['siswa'];
        if (siswa == null) continue;

        final parentPhone = siswa['orang_tua_nomor'] as String?;
        final studentName = siswa['nama'] as String? ?? 'Siswa';

        if (parentPhone != null && parentPhone.isNotEmpty) {
          await sendNotificationToParent(
            parentPhoneNumber: parentPhone,
            studentName: studentName,
            type: NotificationType.absent,
            schoolName: schoolName,
          );
          
          // Add small delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 300));
        }
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

  // ============================================================
  // TEST METHODS
  // ============================================================

  /// Test WAHA connection by sending a test message
  /// Use this to verify the WAHA API is working
  static Future<bool> testWahaConnection({
    required String testPhoneNumber,
  }) async {
    log.info(
      'Testing WAHA connection to: $testPhoneNumber',
      tag: 'NotificationService',
    );

    return _sendWhatsAppMessage(
      phoneNumber: testPhoneNumber,
      message: '''🧪 *TEST KONEKSI WAHA*

Ini adalah pesan test dari Sistem Absensi.
Jika Anda menerima pesan ini, berarti koneksi WAHA berhasil!

Waktu: ${DateTime.now().toString()}''',
    );
  }

  /// Test sending notification by siswa ID from database
  /// Use this to test the full flow: DB -> WAHA -> WhatsApp
  static Future<Map<String, dynamic>> testNotificationBySiswaId({
    required int siswaId,
    required String schoolName,
    NotificationType type = NotificationType.present,
  }) async {
    final result = <String, dynamic>{
      'success': false,
      'siswaId': siswaId,
      'studentName': null,
      'parentPhone': null,
      'message': '',
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

      final parentPhone = studentData['orang_tua_nomor'] as String?;
      
      if (parentPhone == null || parentPhone.isEmpty) {
        result['message'] = 'Nomor orang tua kosong untuk siswa: ${studentData['nama']}';
        log.warning(result['message'] as String, tag: 'NotificationService');
        return result;
      }

      // 2. Send notification
      final success = await sendNotificationToParent(
        parentPhoneNumber: parentPhone,
        studentName: studentData['nama'] as String? ?? 'Siswa',
        type: type,
        schoolName: schoolName,
      );

      result['success'] = success;
      result['message'] = success 
          ? 'Notifikasi berhasil dikirim ke $parentPhone'
          : 'Gagal mengirim notifikasi ke $parentPhone';

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

  /// Send batch notifications for daily attendance
  static Future<void> sendDailyAttendanceNotifications({
    required List<Map<String, dynamic>> absentStudents,
    required List<Map<String, dynamic>> lateStudents,
    required String schoolName,
  }) async {
    try {
      log.info(
        'Starting batch notification send: ${absentStudents.length} absent, ${lateStudents.length} late',
        tag: 'NotificationService',
      );

      // Send notifications for absent students
      for (final student in absentStudents) {
        await sendNotificationToParent(
          parentPhoneNumber: student['parent_phone'] as String,
          studentName: student['student_name'] as String,
          type: NotificationType.absent,
          schoolName: schoolName,
        );
      }

      // Send notifications for late students
      for (final student in lateStudents) {
        await sendNotificationToParent(
          parentPhoneNumber: student['parent_phone'] as String,
          studentName: student['student_name'] as String,
          type: NotificationType.late,
          schoolName: schoolName,
        );
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

  /// Build notification message
  static String _buildNotificationMessage({
    required String studentName,
    required NotificationType type,
    required String schoolName,
    String? waktuPulang,
  }) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = 
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    switch (type) {
      case NotificationType.absent:
        return '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

📋 *INFORMASI KETIDAKHADIRAN SISWA*

👤 Nama Siswa: *$studentName*
📊 Status: ❌ *Tidak Hadir*
🏫 Sekolah: $schoolName
📅 Tanggal: $dateStr
🕐 Waktu Laporan: $timeStr

Apabila ada pertanyaan, silakan hubungi pihak sekolah.

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Otomatis dari Sistem Absensi_''';

      case NotificationType.late:
        return '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

📋 *INFORMASI KETERLAMBATAN SISWA*

👤 Nama Siswa: *$studentName*
📊 Status: ⏰ *Terlambat*
🏫 Sekolah: $schoolName
📅 Tanggal: $dateStr
🕐 Waktu Laporan: $timeStr

Mohon perhatiannya untuk kedisiplinan waktu.

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Otomatis dari Sistem Absensi_''';

      case NotificationType.present:
        return '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

📋 *INFORMASI KEHADIRAN SISWA*

👤 Nama Siswa: *$studentName*
📊 Status: ✅ *Hadir*
🏫 Sekolah: $schoolName
📅 Tanggal: $dateStr
🕐 Waktu Hadir: $timeStr

Terima kasih.

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Otomatis dari Sistem Absensi_''';

      case NotificationType.pulang:
        return '''Assalamu'alaikum Warahmatullahi Wabarakatuh,

📋 *INFORMASI KEPULANGAN SISWA*

👤 Nama Siswa: *$studentName*
📊 Status: 🏠 *Sudah Pulang*
🏫 Sekolah: $schoolName
📅 Tanggal: $dateStr
🕐 Waktu Pulang: ${waktuPulang ?? timeStr}

Siswa telah meninggalkan sekolah dengan selamat.

Wassalamu'alaikum Warahmatullahi Wabarakatuh
_Otomatis dari Sistem Absensi_''';
    }
  }
}
