import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants.dart';
import 'core/theme.dart';

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
        backgroundColor: AppColors.error,
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

  void _showForgotPasswordDialog() {
    final initialEmail =
        _emailController.text.trim().replaceAll('@gmail.com', '');
    final resetEmailController =
        TextEditingController(text: initialEmail);
    final resetFormKey = GlobalKey<FormState>();
    bool isResetting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lupa Password Admin?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'Reset Kata Sandi Akun',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
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
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: resetEmailController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: AppStyles.inputDecoration(
                      'Nama Email Admin',
                      Icons.email_outlined,
                    ).copyWith(
                      hintText: 'email',
                      suffixText: '@gmail.com',
                      suffixStyle: const TextStyle(
                        color: AppColors.primary,
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
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed:
                  isResetting ? null : () => Navigator.pop(dialogCtx),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
                          redirectTo:
                              kIsWeb ? Uri.base.origin : null,
                        );

                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);

                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          builder: (successCtx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green
                                        .withValues(alpha: 0.1),
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
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.pop(successCtx),
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
                      'Kirim Link Reset',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeEmailDialog() {
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
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: AppColors.primary,
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
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'Verifikasi akun & ubah alamat email',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
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
                        color: AppColors.textDark,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Email Lama (Tanpa suffix permanen @gmail.com)
                    TextFormField(
                      controller: oldEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: AppStyles.inputDecoration(
                        'Email Saat Ini (Lengkap)',
                        Icons.email_outlined,
                      ).copyWith(
                        hintText: 'admin@contoh.com',
                      ),
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
                      decoration: AppStyles.inputDecoration(
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
                          onPressed: () => setDialogState(() =>
                              obscureCurrentPassword =
                                  !obscureCurrentPassword),
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
                      decoration: AppStyles.inputDecoration(
                        'Nama Email Baru',
                        Icons.alternate_email_rounded,
                      ).copyWith(
                        hintText: 'email_baru',
                        suffixText: '@gmail.com',
                        suffixStyle: const TextStyle(
                          color: AppColors.primary,
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
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
                        final authRes = await tempClient.auth.signInWithPassword(
                          email: oldFullEmail,
                          password: password,
                        );

                        if (authRes.user == null) {
                          throw const AuthException(
                              'Verifikasi gagal, email atau password salah.');
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green
                                        .withValues(alpha: 0.1),
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
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(successCtx);
                                  // Update input email di form login dengan nama email baru
                                  _emailController.text = rawNew.replaceAll('@gmail.com', '');
                                  _passwordController.clear();
                                },
                                child: const Text('Mengerti & Kembali ke Login'),
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
                      'Verifikasi & Ganti Email',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        alignment:
            Alignment.topCenter, // Pastikan alignment stack ke tengah atas
        children: [
          // 1. Background Header Biru (Layer Paling Bawah)
          _buildTopBackground(),

          // 2. Logo & Teks (Layer Tengah - Ditaruh DI ATAS Background)
          _buildHeaderBranding(),

          // 3. Form Card (Layer Paling Atas - Scrollable)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // PENTING: Spacer ini menggantikan tempat Logo yang dipindah ke atas
                  // Agar Card Login tidak menutupi Logo/Header
                  const SizedBox(height: 220),

                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: size.width < 600 ? 400 : 450,
                    ),
                    child: Card(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Selamat Datang',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Silahkan login untuk mengakses panel admin',
                                style: TextStyle(color: AppColors.textGrey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 30),

                              // Input Email dengan akhiran permanen @gmail.com
                              TextFormField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                decoration: AppStyles.inputDecoration(
                                  'Nama Email',
                                  Icons.email_outlined,
                                ).copyWith(
                                  hintText: 'email',
                                  suffixText: '@gmail.com',
                                  suffixStyle: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                onFieldSubmitted: (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_passwordFocus),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Nama email wajib diisi';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Input Password
                              TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                decoration:
                                    AppStyles.inputDecoration(
                                      'Password',
                                      Icons.lock_outline,
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                      ),
                                    ),
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleLogin(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password wajib diisi';
                                  }
                                  if (value.length < 5) {
                                    return 'Password minimal 5 karakter';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),

                              // Forgot Password & Change Email Links
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton.icon(
                                    onPressed: _showChangeEmailDialog,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(
                                      Icons.alternate_email_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    label: const Text(
                                      'Ganti Email?',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Lupa Password?',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Tombol Login
                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  style: AppStyles.buttonStyle,
                                  onPressed: _isLoading ? null : _handleLogin,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : const Text('MASUK'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBackground() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 200, // Sedikit dipertinggi agar muat logo + teks
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(100),
          ),
        ),
      ),
    );
  }

  // UBAH INI JADI POSITIONED
  Widget _buildHeaderBranding() {
    return Positioned(
      top: 30, // Jarak dari atas layar
      left: 0,
      right: 0,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8), // Padding diperkecil sedikit
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            // Pastikan aset logo ada
            child: Image.asset('assets/Logo MTS.png', height: 80, width: 80),
          ),
          const SizedBox(height: 12),
          Text(
            AppConstants.schoolName,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors
                  .white, // Warna Putih agar kontras dengan Background Biru
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.black26,
                ),
              ],
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
