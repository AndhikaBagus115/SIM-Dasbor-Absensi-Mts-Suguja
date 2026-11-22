import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin_mts/web_admin/core/services/notification_service.dart';
import 'package:web_admin_mts/web_admin/presentation/widgets/notifikasi/pengumuman_form_card.dart';

void main() {
  testWidgets(
    'class send button waits for a nonempty completed recipient list',
    (tester) async {
      final title = TextEditingController(text: 'Judul');
      final body = TextEditingController(text: 'Isi');
      final search = TextEditingController();
      addTearDown(() {
        title.dispose();
        body.dispose();
        search.dispose();
      });
      Future<void> render(
        bool loading,
        List<Map<String, dynamic>> students,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PengumumanFormCard(
                  judulController: title,
                  isiController: body,
                  searchController: search,
                  targetTipe: 'kelas',
                  onTargetTipeChanged: (_) {},
                  selectedKelasId: 1,
                  selectedKelasNama: '7A',
                  daftarKelas: const [
                    {'id': 1, 'nama_kelas': '7A'},
                  ],
                  isLoadingKelas: false,
                  onKelasChanged: (_) {},
                  kelasSiswaList: students,
                  isLoadingKelasSiswa: loading,
                  selectedStudent: null,
                  searchResults: const [],
                  isSearching: false,
                  onSearchStudents: (_) {},
                  onSelectStudent: (_) {},
                  onClearStudent: () {},
                  selectedChannel: NotificationChannel.onesignal,
                  onChannelChanged: (_) {},
                  isSending: false,
                  onSendPengumuman: () {},
                  schoolName: 'Sekolah fixture',
                ),
              ),
            ),
          ),
        );
      }

      ElevatedButton sendButton() => tester.widget<ElevatedButton>(
        find
            .ancestor(
              of: find.text('Kirim Pengumuman Sekarang'),
              matching: find.byWidgetPredicate(
                (widget) => widget is ElevatedButton,
              ),
            )
            .first,
      );
      await render(true, [
        {'id': 1},
      ]);
      expect(sendButton().onPressed, isNull);
      await render(false, []);
      expect(sendButton().onPressed, isNull);
      await render(false, [
        {'id': 1},
      ]);
      expect(sendButton().onPressed, isNotNull);
    },
  );
}
