import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin_mts/web_admin/login.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'InstrumentSans': 'assets/fonts/InstrumentSans.ttf',
      'InstrumentSerif': 'assets/fonts/InstrumentSerif-Regular.ttf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });

  Future<void> open(
    WidgetTester tester,
    Size size, {
    double scale = 1,
    double keyboard = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(1440, 960),
    const Size(768, 1024),
    const Size(390, 844),
  ]) {
    testWidgets('login and account actions remain usable at ${size.width}px', (
      tester,
    ) async {
      await open(tester, size);
      expect(tester.takeException(), isNull);
      final submit = find.byKey(const ValueKey('login-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Email admin wajib diisi'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Lupa kata sandi?'));
      await tester.tap(find.text('Lupa kata sandi?'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Kirim tautan pemulihan'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ganti email'));
      await tester.tap(find.text('Ganti email'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Verifikasi dan ganti email'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'email domain, keyboard focus, and password visibility preserve input',
    (tester) async {
      await open(tester, const Size(1440, 960));
      final email = find.byKey(const ValueKey('login-email'));
      final password = find.byKey(const ValueKey('login-password'));
      await tester.enterText(email, 'admin@sekolah.test');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      final passwordField = find.descendant(
        of: password,
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(passwordField).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(password, 'contoh-rahasia');
      expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
      await tester.tap(find.byTooltip('Tampilkan kata sandi'));
      await tester.pump();
      expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
      expect(
        tester.widget<TextField>(passwordField).controller!.text,
        'contoh-rahasia',
      );
      final emailField = find.descendant(
        of: email,
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(emailField).decoration!.suffixIcon,
        isNull,
      );
    },
  );

  testWidgets(
    'large text and a short keyboard viewport can scroll to the form actions',
    (tester) async {
      await open(tester, const Size(320, 700), scale: 1.6, keyboard: 260);
      final submit = find.byKey(const ValueKey('login-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Email admin wajib diisi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
