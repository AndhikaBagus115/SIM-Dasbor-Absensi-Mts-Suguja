import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin_mts/web_admin/core/services/onesignal_service.dart';

void main() {
  test(
    'a created notification with invalid targets remains a partial result',
    () {
      final result = OneSignalPushResult.fromApi({
        'id': 'message-123',
        'errors': {
          'invalid_aliases': {
            'external_id': ['missing-user'],
          },
        },
      });
      expect(result.success, isTrue);
      expect(result.partial, isTrue);
      expect(result.message, contains('Sebagian'));
    },
  );
  test(
    'accepted HTTP response without message ID is not a created notification',
    () {
      for (final id in [null, '', ' ']) {
        final result = OneSignalPushResult.fromApi({
          'id': id,
          'errors': ['No subscribers'],
        });
        expect(result.success, isFalse);
        expect(result.notificationId, isNull);
      }
    },
  );
  test('message ID is enough for creation; recipients field may be absent', () {
    final result = OneSignalPushResult.fromApi({'id': 'message-123'});
    expect(result.success, isTrue);
    expect(result.notificationId, 'message-123');
    expect(result.message, contains('diterima layanan'));
  });
}
