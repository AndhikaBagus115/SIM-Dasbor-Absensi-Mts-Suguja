import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants.dart';
import 'presentation/widgets/auth/academic_login_shell.dart';
import 'presentation/widgets/auth/login_design.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Focus Nodes
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: LoginDesign.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    // Validasi Form
    if (!_formKey.currentState!.validate()) return;

    // Tutup Keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final rawEmail = _emailController.text.trim();
      final email = rawEmail.endsWith('@gmail.com')
          ? rawEmail
          : (rawEmail.contains('@') ? rawEmail : '$rawEmail@gmail.com');
      final password = _passwordController.text.trim();

      // Eksekusi Login ke Supabase
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const AuthException('Login gagal, user tidak ditemukan.');
      }

      // Catatan: Jika sukses, AuthGate di main.dart akan otomatis mengarahkan ke Dashboard
    } on AuthException catch (e) {
      // Handle error spesifik Supabase
      String msg = 'Terjadi kesalahan saat login.';
      if (e.message.contains('Invalid login credentials')) {
        msg = 'Email atau password salah.';
      } else if (e.message.contains('Email not confirmed')) {
        msg = 'Email belum dikonfirmasi.';
      }
      _showErrorSnackBar(msg);
    } catch (e) {
      _showErrorSnackBar('Gagal terhubung ke server.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog(BuildContext presentationContext) {
    final initialEmail = _emailController.text.trim().replaceAll(
      '@gmail.com',
      '',
    );
    final resetEmailController = TextEditingController(text: initialEmail);
    final resetFormKey = GlobalKey<FormState>();
    bool isResetting = false;

    showDialog(
      context: presentationContext,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LoginDesign.forest.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: LoginDesign.forest,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lupa kata sandi?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: LoginDesign.forestDark,
                      ),
                    ),
                    Text(
                      'Reset Kata Sandi Akun',
                      style: TextStyle(fontSize: 12, color: LoginDesign.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: resetFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan nama email admin terdaftar. Kami akan mengirimkan tautan untuk mengatur ulang kata sandi Anda.',
                    style: TextStyle(
                      fontSize: 13,
                      color: LoginDesign.ink,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: resetEmailController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        LoginDesign.accountField(
                          'Nama Email Admin',
                          Icons.email_outlined,
                        ).copyWith(
                          hintText: 'email',
                          suffixText: '@gmail.com',
                          suffixStyle: const TextStyle(
                            color: LoginDesign.forest,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nama email wajib diisi';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          actions: [
            TextButton(
              onPressed: isResetting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LoginDesign.forest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: isResetting
                  ? null
                  : () async {
                      if (!resetFormKey.currentState!.validate()) return;
                      setDialogState(() => isResetting = true);

                      final rawEmail = resetEmailController.text.trim();
                      final email = rawEmail.endsWith('@gmail.com')
                          ? rawEmail
                          : (rawEmail.contains('@')
                                ? rawEmail
                                : '$rawEmail@gmail.com');
                      try {
                        await Supabase.instance.client.auth
                            .resetPasswordForEmail(
                              email,
                              redirectTo: kIsWeb ? Uri.base.origin : null,
                            );

                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);

                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          builder: (successCtx) => AlertDialog(
                            scrollable: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mark_email_read_rounded,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Email Terkirim',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              'Tautan untuk mereset kata sandi telah dikirim ke $email.\n\nSilakan periksa kotak masuk (Inbox) atau folder Spam pada email Anda untuk melanjutkan.',
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: LoginDesign.forest,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(successCtx),
                                child: const Text('Mengerti'),
                              ),
                            ],
                          ),
                        );
                      } on AuthException catch (e) {
                        setDialogState(() => isResetting = false);
                        _showErrorSnackBar(
                          'Gagal mengirim reset password: ${e.message}',
                        );
                      } catch (e) {
                        setDialogState(() => isResetting = false);
                        _showErrorSnackBar(
                          'Terjadi kesalahan saat memproses permintaan.',
                        );
                      }
                    },
              child: isResetting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Kirim tautan pemulihan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeEmailDialog(BuildContext presentationContext) {
    final typedEmail = _emailController.text.trim();
    final initialOldEmail = typedEmail.isEmpty
        ? ''
        : (typedEmail.contains('@') ? typedEmail : '$typedEmail@gmail.com');
    final oldEmailController = TextEditingController(text: initialOldEmail);
    final passwordController = TextEditingController();
    final newEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool isSubmitting = false;
    bool obscureCurrentPassword = true;

    showDialog(
      context: presentationContext,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LoginDesign.forest.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: LoginDesign.forest,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ganti Email Admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: LoginDesign.forestDark,
                      ),
                    ),
                    Text(
                      'Verifikasi akun & ubah alamat email',
                      style: TextStyle(fontSize: 12, color: LoginDesign.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masukkan email lengkap saat ini, password verifikasi, dan nama email baru Anda.',
                      style: TextStyle(
                        fontSize: 13,
                        color: LoginDesign.ink,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Email Lama (Tanpa suffix permanen @gmail.com)
                    TextFormField(
                      controller: oldEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: LoginDesign.accountField(
                        'Email Saat Ini (Lengkap)',
                        Icons.email_outlined,
                      ).copyWith(hintText: 'admin@contoh.com'),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Email saat ini wajib diisi';
                        }
                        if (!val.contains('@')) {
                          return 'Format email tidak valid (harus menyertakan @)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 2. Password Saat Ini (Verifikasi Keamanan)
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscureCurrentPassword,
                      decoration:
                          LoginDesign.accountField(
                            'Password Akun Admin',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureCurrentPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () => setDialogState(
                                () => obscureCurrentPassword =
                                    !obscureCurrentPassword,
                              ),
                            ),
                          ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Password wajib diisi untuk verifikasi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 3. Email Baru (dengan suffix @gmail.com)
                    TextFormField(
                      controller: newEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          LoginDesign.accountField(
                            'Nama Email Baru',
                            Icons.alternate_email_rounded,
                          ).copyWith(
                            hintText: 'email_baru',
                            suffixText: '@gmail.com',
                            suffixStyle: const TextStyle(
                              color: LoginDesign.forest,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nama email baru wajib diisi';
                        }
                        final rawOld = oldEmailController.text.trim();
                        final rawNew = val.trim();
                        final newFull = rawNew.endsWith('@gmail.com')
                            ? rawNew
                            : '$rawNew@gmail.com';
                        if (rawOld.toLowerCase() == newFull.toLowerCase()) {
                          return 'Email baru tidak boleh sama dengan email saat ini';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Info Box Verifikasi
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Colors.blue.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tautan verifikasi akan dikirimkan ke email baru untuk mengonfirmasi perubahan sebelum aktif. Setelah verifikasi, silakan login dengan email baru.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LoginDesign.forest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);

                      final oldFullEmail = oldEmailController.text.trim();
                      final password = passwordController.text.trim();

                      final rawNew = newEmailController.text.trim();
                      final newFullEmail = rawNew.endsWith('@gmail.com')
                          ? rawNew
                          : (rawNew.contains('@')
                                ? rawNew
                                : '$rawNew@gmail.com');

                      // Gunakan isolated SupabaseClient agar tidak mengubah session global AuthGate (tidak langsung masuk ke dashboard)
                      final tempClient = SupabaseClient(
                        AppConstants.supabaseUrl,
                        AppConstants.supabaseAnonKey,
                      );

                      try {
                        // 1. Verifikasi kredensial saat ini dengan login pada client terisolasi
                        final authRes = await tempClient.auth
                            .signInWithPassword(
                              email: oldFullEmail,
                              password: password,
                            );

                        if (authRes.user == null) {
                          throw const AuthException(
                            'Verifikasi gagal, email atau password salah.',
                          );
                        }

                        // 2. Ajukan penggantian email ke Supabase
                        await tempClient.auth.updateUser(
                          UserAttributes(email: newFullEmail),
                        );

                        // 3. Sign out dari client terisolasi
                        await tempClient.auth.signOut();

                        // 4. Pastikan juga sesi global utama tetap signed out
                        await Supabase.instance.client.auth.signOut();

                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);

                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          builder: (successCtx) => AlertDialog(
                            scrollable: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mark_email_read_rounded,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Verifikasi Terkirim',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              'Permintaan ganti email dari $oldFullEmail ke $newFullEmail berhasil diajukan.\n\nSilakan buka kotak masuk (Inbox) atau folder Spam pada email $newFullEmail untuk mengonfirmasi perubahan.\n\nSetelah dikonfirmasi, silakan login kembali menggunakan alamat email baru Anda.',
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: LoginDesign.forest,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(successCtx);
                                  // Update input email di form login dengan nama email baru
                                  _emailController.text = rawNew.replaceAll(
                                    '@gmail.com',
                                    '',
                                  );
                                  _passwordController.clear();
                                },
                                child: const Text('Kembali ke login'),
                              ),
                            ],
                          ),
                        );
                      } on AuthException catch (e) {
                        setDialogState(() => isSubmitting = false);
                        String msg = 'Gagal mengganti email: ${e.message}';
                        if (e.message.contains('Invalid login credentials')) {
                          msg =
                              'Email lama atau password admin yang dimasukkan salah.';
                        }
                        _showErrorSnackBar(msg);
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        _showErrorSnackBar(
                          'Terjadi kesalahan saat memproses permintaan: $e',
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Verifikasi dan ganti email',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: LoginDesign.theme(Theme.of(context)),
    child: Builder(
      builder: (context) => AcademicLoginShell(form: _buildLoginForm(context)),
    ),
  );

  Widget _buildLoginForm(BuildContext context) => AutofillGroup(
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'Masuk ke panel admin',
              style: TextStyle(
                fontFamily: LoginDesign.sans,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                height: 1.2,
                letterSpacing: -0.6,
                color: LoginDesign.ink,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Gunakan akun yang terdaftar untuk melanjutkan.',
            style: TextStyle(
              fontFamily: LoginDesign.sans,
              fontSize: 14,
              height: 1.6,
              color: LoginDesign.muted,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Email admin',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: LoginDesign.ink,
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _emailController,
            builder: (context, value, _) => Semantics(
              label: 'Email admin',
              child: TextFormField(
                key: const ValueKey('login-email'),
                controller: _emailController,
                focusNode: _emailFocus,
                enabled: !_isLoading,
                style: const TextStyle(
                  fontFamily: LoginDesign.sans,
                  fontSize: 14,
                  color: LoginDesign.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'nama.email',
                  suffixIcon: value.text.contains('@')
                      ? null
                      : const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              '@gmail.com',
                              style: TextStyle(
                                fontFamily: LoginDesign.sans,
                                fontSize: 14,
                                color: LoginDesign.muted,
                              ),
                            ),
                          ),
                        ),
                  suffixIconConstraints: const BoxConstraints(minHeight: 48),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                autocorrect: false,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Email admin wajib diisi'
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Kata sandi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: LoginDesign.ink,
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => _showForgotPasswordDialog(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  alignment: Alignment.centerRight,
                ),
                child: const Text('Lupa kata sandi?'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Semantics(
            label: 'Kata sandi',
            child: TextFormField(
              key: const ValueKey('login-password'),
              controller: _passwordController,
              focusNode: _passwordFocus,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              style: const TextStyle(
                fontFamily: LoginDesign.sans,
                fontSize: 14,
                color: LoginDesign.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Masukkan kata sandi',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Tampilkan kata sandi'
                      : 'Sembunyikan kata sandi',
                  onPressed: _isLoading
                      ? null
                      : () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: LoginDesign.muted,
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              enableSuggestions: false,
              autocorrect: false,
              onFieldSubmitted: (_) => _handleLogin(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kata sandi wajib diisi';
                }
                if (value.length < 5) return 'Kata sandi minimal 5 karakter';
                return null;
              },
            ),
          ),
          const SizedBox(height: 26),
          ElevatedButton(
            key: const ValueKey('login-submit'),
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              textStyle: const TextStyle(
                fontFamily: LoginDesign.sans,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: LoginDesign.forest,
              disabledBackgroundColor: LoginDesign.paper,
              disabledForegroundColor: LoginDesign.ink,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: LoginDesign.forest,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(_isLoading ? 'Sedang masuk...' : 'Masuk ke panel'),
                if (!_isLoading) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: LoginDesign.muted,
              ),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Akses khusus administrator madrasah.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: LoginDesign.sans,
                    fontSize: 12,
                    color: LoginDesign.muted,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              const Text(
                'Perlu memperbarui akun?',
                style: TextStyle(
                  fontFamily: LoginDesign.sans,
                  fontSize: 13,
                  color: LoginDesign.muted,
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => _showChangeEmailDialog(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text('Ganti email'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
