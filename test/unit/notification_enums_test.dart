import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin_mts/web_admin/core/services/notification_service.dart';

void main() {
  group('NotificationChannel Tests', () {
    test('NotificationChannel has appropriate display names', () {
      expect(NotificationChannel.whatsapp.displayName, 'WhatsApp');
      expect(NotificationChannel.onesignal.displayName, 'Push Notifikasi (Aplikasi)');
      expect(NotificationChannel.both.displayName, 'Keduanya (WA + Push)');
    });
  });

  group('NotificationType Tests', () {
    test('NotificationType display names match Indonesian localization', () {
      expect(NotificationType.present.displayName, 'Siswa Hadir');
      expect(NotificationType.late.displayName, 'Siswa Terlambat');
      expect(NotificationType.absent.displayName, 'Siswa Tidak Hadir');
      expect(NotificationType.pulang.displayName, 'Siswa Pulang');
    });
  });
}
