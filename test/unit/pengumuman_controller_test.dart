import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin_mts/web_admin/logic/pengumuman_controller.dart';

void main() {
  test(
    'partial recipient delivery retains the form even with one selected channel',
    () async {
      final result = await PengumumanSender(save: (_) async {}).send(
        record: {},
        channels: {'WhatsApp': () async => DeliveryOutcome.partial},
      );
      expect(result.success, isFalse);
      expect(result.partial, isTrue);
      expect(result.message, contains('sebagian'));
    },
  );
  test(
    'sending refreshes membership and does not reuse a stale displayed list',
    () async {
      final controller = ClassRecipientController(
        loadStudents: (_, force) async => force
            ? [
                {'id': 2},
              ]
            : [
                {'id': 1},
              ],
      );
      addTearDown(controller.dispose);
      await controller.selectClass(1);
      expect(controller.students.single['id'], 1);
      expect((await controller.snapshotForSend(1)).single['id'], 2);
    },
  );
  test(
    'failed refresh blocks sending rather than falling back to displayed recipients',
    () async {
      final controller = ClassRecipientController(
        loadStudents: (_, force) async {
          if (force) throw StateError('offline');
          return [
            {'id': 1},
          ];
        },
      );
      addTearDown(controller.dispose);
      await controller.selectClass(1);
      await expectLater(controller.snapshotForSend(1), throwsStateError);
      expect(controller.isReady, isFalse);
      expect(controller.students, isEmpty);
    },
  );
  test('late class A response cannot overwrite selected class B', () async {
    final a = Completer<StudentRows>();
    final b = Completer<StudentRows>();
    final controller = ClassRecipientController(
      loadStudents: (id, _) => id == 1 ? a.future : b.future,
    );
    addTearDown(controller.dispose);
    final first = controller.selectClass(1);
    final second = controller.selectClass(2);
    expect(controller.isReady, isFalse);
    b.complete([
      {'id': 22},
    ]);
    await second;
    a.complete([
      {'id': 11},
    ]);
    await first;
    expect(controller.kelasId, 2);
    expect(controller.students.single['id'], 22);
    expect(controller.isReady, isTrue);
  });

  test('deselecting class invalidates outstanding loads', () async {
    final pending = Completer<StudentRows>();
    final controller = ClassRecipientController(
      loadStudents: (_, _) => pending.future,
    );
    addTearDown(controller.dispose);
    final loading = controller.selectClass(1);
    await controller.selectClass(null);
    pending.complete([
      {'id': 11},
    ]);
    await loading;
    expect(controller.students, isEmpty);
    expect(controller.isReady, isFalse);
    expect(controller.isLoading, isFalse);
  });

  test('failed and empty class loads never become ready', () async {
    final controller = ClassRecipientController(
      loadStudents: (id, _) async {
        if (id == 1) throw StateError('offline');
        return [];
      },
    );
    addTearDown(controller.dispose);
    await controller.selectClass(1);
    expect(controller.error, isNotNull);
    expect(controller.isReady, isFalse);
    await controller.selectClass(2);
    expect(controller.error, isNull);
    expect(controller.isReady, isFalse);
  });

  test('storage failure prevents dispatch and reports failure', () async {
    var sends = 0;
    final result =
        await PengumumanSender(
          save: (_) async => throw StateError('denied'),
        ).send(
          record: {},
          channels: {
            'Push': () async {
              sends++;
              return DeliveryOutcome.accepted;
            },
          },
        );
    expect(sends, 0);
    expect(result.saved, isFalse);
    expect(result.success, isFalse);
  });

  test('channel exception does not suppress the other channel', () async {
    final result = await PengumumanSender(save: (_) async {}).send(
      record: {},
      channels: {
        'Push': () async => throw StateError('offline'),
        'WhatsApp': () async => DeliveryOutcome.accepted,
      },
    );
    expect(result.saved, isTrue);
    expect(result.success, isFalse);
    expect(result.partial, isTrue);
    expect(result.channels, {
      'Push': DeliveryOutcome.failed,
      'WhatsApp': DeliveryOutcome.accepted,
    });
  });

  test('success requires every requested channel', () async {
    final sender = PengumumanSender(save: (_) async {});
    final failed = await sender.send(
      record: {},
      channels: {'Push': () async => DeliveryOutcome.failed},
    );
    final success = await sender.send(
      record: {},
      channels: {'Push': () async => DeliveryOutcome.accepted},
    );
    expect(failed.success, isFalse);
    expect(failed.partial, isFalse);
    expect(success.success, isTrue);
    expect((await sender.send(record: {}, channels: {})).success, isFalse);
  });
}
