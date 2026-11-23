import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin_mts/web_admin/presentation/widgets/admin_access_gate.dart';

void main() {
  testWidgets(
    'admin pages are never constructed while pending, denied, or offline',
    (tester) async {
      var created = 0;
      var access = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAccessGate(
            checkAdmin: () => access.future,
            onSignOut: () async {},
            builder: (_) {
              created++;
              return const Text('Panel');
            },
          ),
        ),
      );
      expect(created, 0);
      access.complete(false);
      await tester.pumpAndSettle();
      expect(created, 0);
      expect(find.text('Akses admin diperlukan'), findsOneWidget);
      access = Completer<bool>();
      await tester.tap(find.text('Coba lagi'));
      await tester.pump();
      access.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(created, 0);
      expect(find.text('Akses belum dapat diverifikasi'), findsOneWidget);
      access = Completer<bool>();
      await tester.tap(find.text('Coba lagi'));
      await tester.pump();
      access.complete(true);
      await tester.pumpAndSettle();
      expect(created, 1);
      expect(find.text('Panel'), findsOneWidget);
    },
  );
}
