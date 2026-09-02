import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin_mts/web_admin/presentation/widgets/notifikasi/gateway_diagnostics_card.dart';
import 'package:web_admin_mts/web_admin/presentation/widgets/notifikasi/notifikasi_dialogs.dart';

void main() {
  group('TargetBadge Widget Tests', () {
    testWidgets('Renders Semua Wali Murid badge correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TargetBadge(targetTipe: 'semua'),
          ),
        ),
      );

      expect(find.text('Semua Wali Murid'), findsOneWidget);
      expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    });

    testWidgets('Renders Per Kelas badge correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TargetBadge(targetTipe: 'kelas', targetNama: 'Kelas 8A'),
          ),
        ),
      );

      expect(find.text('Kelas 8A'), findsOneWidget);
      expect(find.byIcon(Icons.class_outlined), findsOneWidget);
    });

    testWidgets('Renders Siswa badge correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TargetBadge(targetTipe: 'siswa', targetNama: 'Ahmad Fadhil'),
          ),
        ),
      );

      expect(find.text('Ahmad Fadhil'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    });
  });

  group('OneSignalInfoCard Widget Tests', () {
    testWidgets('Renders OneSignal info guidelines card', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OneSignalInfoCard(),
          ),
        ),
      );

      expect(find.text('Aturan ID OneSignal Mobile'), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });
  });
}
