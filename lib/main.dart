import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'web_admin/core/constants.dart';
import 'web_admin/core/services/master_data_cache_service.dart';
import 'web_admin/core/services/admin_notification_gateway.dart';
import 'web_admin/presentation/widgets/admin_access_gate.dart';
import 'web_admin/data/repositories/absensi_repository.dart';
import 'web_admin/data/repositories/guru_repository.dart';
import 'web_admin/data/repositories/kelas_repository.dart';
import 'web_admin/data/repositories/siswa_repository.dart';
import 'web_admin/data/repositories/surat_repository.dart';

import 'web_admin/login.dart';
import 'web_admin/dashboard.dart';
import 'web_admin/sidebar.dart';
import 'web_admin/data/data_kelas.dart';
import 'web_admin/data/data_guru.dart';
import 'web_admin/data/data_siswa.dart';
import 'web_admin/data/data_absensi.dart';
import 'web_admin/data/data_surat.dart';
import 'web_admin/data/data_notifikasi_test.dart';
import 'web_admin/data/data_profil.dart';
import 'web_admin/presentation/pages/password_recovery_screen.dart';

final supabase = Supabase.instance.client;

// Preserve pages on profile updates; refresh authorization when the token changes.
// A raw JWT must never appear in a widget key's diagnostic string.
class _AdminSessionKey extends LocalKey {
  final String userId;
  final String _token;
  const _AdminSessionKey(this.userId, this._token);
  @override
  bool operator ==(Object other) =>
      other is _AdminSessionKey &&
      userId == other.userId &&
      _token == other._token;
  @override
  int get hashCode => Object.hash(userId, _token);
  @override
  String toString() => 'AdminSession($userId)';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional runtime public configuration; compile-time public values also work.
  try {
    final raw = await rootBundle.loadString('assets/public_config.json');
    AppConstants.loadPublicConfig(jsonDecode(raw) as Map<String, dynamic>);
  } on FlutterError {
    // File is optional when the two public dart-defines are supplied.
  }

  // 1. Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // 2. Setup Desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await _setupDesktopWindow();
  }

  runApp(const MyApp());
}

Future<void> _setupDesktopWindow() async {
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    // Menggunakan variabel nama sekolah
    title: 'Absensi ${AppConstants.schoolName}',
    center: true,
    minimumSize: Size(1100, 650),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await Future.delayed(const Duration(milliseconds: 150));
    await windowManager.maximize();

    final isMax = await windowManager.isMaximized();
    if (!isMax) {
      await windowManager.maximize();
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin MTs Suguja',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      home: const AuthGate(),
    );
  }
}

class AdminRepositoryScope extends StatelessWidget {
  final Widget child;
  const AdminRepositoryScope({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SiswaRepository>(create: (_) => SiswaRepositoryImpl(supabase)),
        Provider<GuruRepository>(create: (_) => GuruRepositoryImpl(supabase)),
        Provider<KelasRepository>(create: (_) => KelasRepositoryImpl(supabase)),
        Provider<AbsensiRepository>(
          create: (_) => AbsensiRepositoryImpl(supabase),
        ),
        Provider<SuratRepository>(create: (_) => SuratRepositoryImpl(supabase)),
      ],

      child: child,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late bool _isPasswordRecovery;
  StreamSubscription<AuthState>? _authSubscription;
  String? _userId;

  @override
  void initState() {
    super.initState();
    // Deteksi instan jika halaman dibuka dari URL reset password (?code=... atau type=recovery)
    final uri = Uri.base;
    _isPasswordRecovery =
        (kIsWeb && uri.queryParameters.containsKey('code')) ||
        (kIsWeb && uri.queryParameters['type'] == 'recovery') ||
        (kIsWeb && uri.fragment.contains('type=recovery'));

    _userId = supabase.auth.currentUser?.id;
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final nextUser = data.session?.user.id;
      if (nextUser != _userId || data.event == AuthChangeEvent.signedOut) {
        MasterDataCacheService.instance.invalidateAll();
        AdminNotificationGateway.clear();
        _userId = nextUser;
      }
      if (mounted &&
          (data.event == AuthChangeEvent.signedOut ||
              data.event == AuthChangeEvent.signedIn ||
              data.event == AuthChangeEvent.tokenRefreshed)) {
        // Dialog routes live above the dashboard subtree; remove their old data too.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      if (data.event == AuthChangeEvent.signedOut && mounted) {
        setState(() => _isPasswordRecovery = false);
      }
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          setState(() {
            _isPasswordRecovery = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPasswordRecovery) {
      return PasswordRecoveryScreen(
        onSuccess: () {
          if (mounted) {
            setState(() {
              _isPasswordRecovery = false;
            });
          }
        },
      );
    }

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        supabase.auth.currentSession,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.data?.session;
        return session != null
            ? AdminAccessGate(
                key: _AdminSessionKey(session.user.id, session.accessToken),
                checkAdmin: () async {
                  final allowed =
                      await supabase
                          .rpc('is_attendance_admin')
                          .timeout(const Duration(seconds: 12)) ==
                      true;
                  if (allowed) {
                    try {
                      await AdminNotificationGateway.refreshStatus();
                    } catch (_) {
                      /* Status may be offline. */
                    }
                  }
                  return allowed;
                },
                onSignOut: () => supabase.auth.signOut(),
                builder: (_) => AdminRepositoryScope(
                  key: ValueKey(session.user.id),
                  child: const AdminDashboardPage(),
                ),
              )
            : const LoginScreen();
      },
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  String? _selectedKelasId;

  void _onMenuSelected(int index) async {
    if (index == 8) {
      await supabase.auth.signOut();
      return;
    }
    setState(() {
      _selectedIndex = index;
      if (index != 4) {
        _selectedKelasId = null;
      }
    });
  }

  void _navigateToSiswaPerKelas(String kelasId) {
    setState(() {
      _selectedKelasId = kelasId;
      _selectedIndex = 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const DashboardScreen(),
      const PageAbsensi(schoolName: AppConstants.schoolName),
      const PageGuru(schoolName: AppConstants.schoolName),
      PageKelas(
        schoolName: AppConstants.schoolName,
        onViewSiswa: _navigateToSiswaPerKelas,
      ),
      DataSiswaPage(
        schoolName: AppConstants.schoolName,
        initialKelasId: _selectedKelasId,
      ),
      const DataSuratPage(schoolName: AppConstants.schoolName),
      const NotifikasiTestPage(schoolName: AppConstants.schoolName),
      ProfilAdminPage(schoolName: AppConstants.schoolName),
    ];

    final int safeIndex = (_selectedIndex < pages.length && _selectedIndex >= 0)
        ? _selectedIndex
        : 0;

    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _selectedIndex,
            onMenuSelected: _onMenuSelected,
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFf5f7fa),
              child: IndexedStack(index: safeIndex, children: pages),
            ),
          ),
        ],
      ),
    );
  }
}
