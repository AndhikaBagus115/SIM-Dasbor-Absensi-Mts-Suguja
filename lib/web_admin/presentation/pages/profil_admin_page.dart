import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

class ProfilAdminPage extends StatefulWidget {
  final String schoolName;

  const ProfilAdminPage({
    super.key,
    required this.schoolName,
  });

  @override
  State<ProfilAdminPage> createState() => _ProfilAdminPageState();
}

class _ProfilAdminPageState extends State<ProfilAdminPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _currentUser;
  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isUpdatingPassword = false;

  // Form Keys
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  // Profile Controllers
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _jabatanController = TextEditingController();

  // Password Controllers
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jabatanController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _loadAdminData() {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata ?? {};
      _currentUser = user;
      _emailController.text = user.email ?? '';
      _namaController.text = metadata['name'] ??
          metadata['full_name'] ??
          metadata['display_name'] ??
          'Administrator';
      _phoneController.text = metadata['phone'] ??
          metadata['phone_number'] ??
          user.phone ??
          '';
      _jabatanController.text = metadata['jabatan'] ??
          metadata['role_title'] ??
          'Administrator SIM Absensi';
    }
    setState(() => _isLoading = false);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleSaveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSavingProfile = true);
    try {
      final updatedData = {
        'name': _namaController.text.trim(),
        'full_name': _namaController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'jabatan': _jabatanController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final res = await _supabase.auth.updateUser(
        UserAttributes(data: updatedData),
      );

      if (res.user != null) {
        setState(() {
          _currentUser = res.user;
        });
        _showSnackBar('Profil admin berhasil diperbarui.');
      }
    } on AuthException catch (e) {
      _showSnackBar('Gagal memperbarui profil: ${e.message}', isError: true);
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  void _showChangeEmailDialog() {
    final currentEmail = _currentUser?.email ?? '';
    final newEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

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
                      'Ubah alamat email login akun',
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Email Saat Ini
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Email Saat Ini:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                currentEmail,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Input Email Baru
                  TextFormField(
                    controller: newEmailController,
                    autofocus: true,
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
                      final raw = val.trim();
                      final fullEmail = raw.endsWith('@gmail.com')
                          ? raw
                          : (raw.contains('@') ? raw : '$raw@gmail.com');
                      if (fullEmail.toLowerCase() ==
                          currentEmail.toLowerCase()) {
                        return 'Email baru tidak boleh sama dengan email saat ini';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Info Verifikasi
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tautan verifikasi akan dikirimkan ke email baru untuk mengonfirmasi perubahan alamat email sebelum aktif.',
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

                      final raw = newEmailController.text.trim();
                      final fullEmail = raw.endsWith('@gmail.com')
                          ? raw
                          : (raw.contains('@') ? raw : '$raw@gmail.com');

                      try {
                        await _supabase.auth.updateUser(
                          UserAttributes(email: fullEmail),
                        );

                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);

                        if (!context.mounted) return;
                        _loadAdminData();

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
                              'Permintaan pembaruan email ke $fullEmail telah diproses.\n\nSilakan periksa kotak masuk (Inbox) atau folder Spam pada email $fullEmail untuk mengonfirmasi penggantian email.',
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
                        setDialogState(() => isSubmitting = false);
                        _showSnackBar(
                          'Gagal mengganti email: ${e.message}',
                          isError: true,
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        _showSnackBar('Terjadi kesalahan: $e', isError: true);
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
                      'Simpan & Kirim Verifikasi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass != confirmPass) {
      _showSnackBar('Konfirmasi password tidak cocok.', isError: true);
      return;
    }

    setState(() => _isUpdatingPassword = true);
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPass),
      );

      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnackBar('Kata sandi berhasil diperbarui dengan aman.');
    } on AuthException catch (e) {
      _showSnackBar('Gagal memperbarui password: ${e.message}', isError: true);
    } catch (e) {
      _showSnackBar('Terjadi kesalahan saat ganti password: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }



  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            const Text(
              'Konfirmasi Keluar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari panel admin?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _supabase.auth.signOut();
            },
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(dt)} WIB';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Banner Profil
                  _buildHeaderBanner(),

                  const SizedBox(height: 24),

                  // 2. Grid / Column of Sections
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Account Details & Edit Profile
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _buildAccountOverviewCard(),
                              const SizedBox(height: 20),
                              _buildEditProfileCard(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Right Column: Security & System Info & Danger Zone
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              _buildSecurityCard(),
                              const SizedBox(height: 20),
                              _buildSystemInfoCard(),
                              const SizedBox(height: 20),
                              _buildDangerZoneCard(),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildAccountOverviewCard(),
                        const SizedBox(height: 20),
                        _buildEditProfileCard(),
                        const SizedBox(height: 20),
                        _buildSecurityCard(),
                        const SizedBox(height: 20),
                        _buildSystemInfoCard(),
                        const SizedBox(height: 20),
                        _buildDangerZoneCard(),
                      ],
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // 1. HERO HEADER BANNER
  // ==========================================
  Widget _buildHeaderBanner() {
    final metadata = _currentUser?.userMetadata ?? {};
    final displayName = metadata['name'] ??
        metadata['full_name'] ??
        metadata['display_name'] ??
        'Administrator';
    final jabatan = metadata['jabatan'] ??
        metadata['role_title'] ??
        'Administrator SIM Absensi';
    final email = _currentUser?.email ?? 'admin@mts-suguja.sch.id';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative circle
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 80,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with Glow & Online Status
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: Image.asset(
                          'assets/Logo MTS.png',
                          width: 55,
                          height: 55,
                          errorBuilder: (ctx, err, stack) => const Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 45,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 20),

                // Name & Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Super Admin',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        jabatan,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              email,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Refresh Button
                IconButton(
                  tooltip: 'Muat Ulang Profil',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadAdminData,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. ACCOUNT OVERVIEW CARD
  // ==========================================
  Widget _buildAccountOverviewCard() {
    final user = _currentUser;
    final uid = user?.id ?? '-';
    final createdAt = _formatDateTime(user?.createdAt);
    final lastSignIn = _formatDateTime(user?.lastSignInAt);
    final isEmailConfirmed = user?.emailConfirmedAt != null;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Informasi Akun Admin',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Item 1: UID
            _buildDetailRow(
              icon: Icons.fingerprint_rounded,
              label: 'User ID (UID)',
              value: uid,
              isCopyable: true,
            ),
            const SizedBox(height: 14),

            // Item 2: Email & Verification Status & Ganti Email
            _buildDetailRow(
              icon: Icons.alternate_email_rounded,
              label: 'Email Terdaftar',
              value: user?.email ?? '-',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isEmailConfirmed
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isEmailConfirmed
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Text(
                  isEmailConfirmed ? 'Terverifikasi' : 'Belum Verifikasi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isEmailConfirmed
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Item 3: Created At
            _buildDetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Akun Dibuat',
              value: createdAt,
            ),
            const SizedBox(height: 14),

            // Item 4: Last Sign In
            _buildDetailRow(
              icon: Icons.access_time_rounded,
              label: 'Sesi Masuk Terakhir',
              value: lastSignIn,
            ),
            const SizedBox(height: 14),

            // Item 5: Auth Provider
            _buildDetailRow(
              icon: Icons.security_rounded,
              label: 'Metode Autentikasi',
              value: 'Supabase Cloud Auth (Email / Password)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isCopyable = false,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (isCopyable) ...[
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  color: AppColors.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Salin UID',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    _showSnackBar('UID disalin ke clipboard');
                  },
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. EDIT PROFILE CARD
  // ==========================================
  Widget _buildEditProfileCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _profileFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.teal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Perbarui Data Profil',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Ubah informasi nama tampilan dan identitas admin.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Input Nama Lengkap
              TextFormField(
                controller: _namaController,
                decoration: AppStyles.inputDecoration(
                  'Nama Lengkap Admin',
                  Icons.person_outline,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama lengkap tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Input Email (Read Only dengan Tombol Ganti Email)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: AppStyles.inputDecoration(
                        'Alamat Email Admin',
                        Icons.email_outlined,
                      ).copyWith(
                        fillColor: Colors.grey.shade100,
                        helperText:
                            'Alamat email terhubung ke Supabase Auth.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: _showChangeEmailDialog,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text(
                        'Ganti Email',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Input No HP / WhatsApp
              TextFormField(
                controller: _phoneController,
                decoration: AppStyles.inputDecoration(
                  'Nomor WhatsApp / HP',
                  Icons.phone_outlined,
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Input Jabatan / Posisi
              TextFormField(
                controller: _jabatanController,
                decoration: AppStyles.inputDecoration(
                  'Jabatan / Unit Kerja',
                  Icons.work_outline_rounded,
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isSavingProfile ? null : _handleSaveProfile,
                    icon: _isSavingProfile
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      _isSavingProfile
                          ? 'Menyimpan...'
                          : 'Simpan Perubahan Data',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 4. SECURITY / PASSWORD CARD
  // ==========================================
  Widget _buildSecurityCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _passwordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: Colors.orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Keamanan & Ganti Password',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Perbarui kata sandi akun admin secara berkala.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Input Password Baru
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: AppStyles.inputDecoration(
                  'Password Baru',
                  Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(
                      () => _obscureNewPassword = !_obscureNewPassword,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Password baru wajib diisi';
                  }
                  if (val.length < 6) {
                    return 'Password minimal 6 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Input Konfirmasi Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: AppStyles.inputDecoration(
                  'Konfirmasi Password Baru',
                  Icons.lock_clock_outlined,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(
                      () =>
                          _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Konfirmasi password wajib diisi';
                  }
                  if (val != _newPasswordController.text) {
                    return 'Konfirmasi password tidak cocok';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Checklist Requirement Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Colors.blue.shade800,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Password minimal 6 karakter. Disarankan menggunakan kombinasi huruf, angka, dan simbol.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Update Password
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed:
                      _isUpdatingPassword ? null : _handleUpdatePassword,
                  icon: _isUpdatingPassword
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.key_rounded, size: 18),
                  label: Text(
                    _isUpdatingPassword
                        ? 'Memperbarui...'
                        : 'Perbarui Kata Sandi',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 5. SYSTEM & SCHOOL INFO CARD
  // ==========================================
  Widget _buildSystemInfoCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.purple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Informasi Madrasah & Sistem',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 14),

            _buildSystemRow(
              'Instansi',
              widget.schoolName,
              icon: Icons.account_balance_outlined,
            ),
            const SizedBox(height: 12),
            _buildSystemRow(
              'Status Database',
              'Terhubung (Supabase)',
              statusColor: Colors.green,
              icon: Icons.storage_rounded,
            ),
            const SizedBox(height: 12),
            _buildSystemRow(
              'WAHA WhatsApp',
              AppConstants.isWahaConfigured ? 'Aktif' : 'Belum Dikonfigurasi',
              statusColor:
                  AppConstants.isWahaConfigured ? Colors.green : Colors.orange,
              icon: Icons.chat_rounded,
            ),
            const SizedBox(height: 12),
            _buildSystemRow(
              'OneSignal Push',
              AppConstants.isOneSignalConfigured
                  ? 'Aktif'
                  : 'Belum Dikonfigurasi',
              statusColor: AppConstants.isOneSignalConfigured
                  ? Colors.green
                  : Colors.orange,
              icon: Icons.notifications_active_rounded,
            ),
            const SizedBox(height: 12),
            _buildSystemRow(
              'Environment',
              AppConstants.appEnvironment.toUpperCase(),
              icon: Icons.computer_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemRow(
    String label,
    String value, {
    Color? statusColor,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (statusColor != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: statusColor ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 6. DANGER ZONE & SESSION ACTIONS CARD
  // ==========================================
  Widget _buildDangerZoneCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade100),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppColors.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Aksi Akun & Sesi',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 14),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Keluar dari Sesi Admin',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
