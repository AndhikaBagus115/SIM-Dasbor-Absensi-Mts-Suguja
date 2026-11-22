import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin_mts/web_admin/presentation/widgets/surat_review_panel.dart';

void main() {
  testWidgets('rejection requires a reason and failures preserve the note', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuratReviewPanel(
            surat: const {'status': 'menunggu'},
            onReview: (approve, note) async {
              calls++;
              expect(approve, isFalse);
              expect(note, 'Dokumen tidak sesuai');
              throw StateError('server unavailable');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tolak surat'));
    await tester.pump();
    expect(calls, 0);
    expect(find.text('Alasan penolakan wajib diisi.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Dokumen tidak sesuai');
    await tester.tap(find.text('Tolak surat'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Dokumen tidak sesuai'), findsOneWidget);
    expect(find.textContaining('server unavailable'), findsOneWidget);
  });

  testWidgets('successful approval becomes a terminal reviewed state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuratReviewPanel(
            surat: const {'status': 'menunggu'},
            onReview: (approve, note) async => {'status': 'disetujui'},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Setujui surat'));
    await tester.pumpAndSettle();
    expect(find.text('Status verifikasi: disetujui'), findsOneWidget);
    expect(find.text('Setujui surat'), findsNothing);
    expect(find.text('Tolak surat'), findsNothing);
  });

}
