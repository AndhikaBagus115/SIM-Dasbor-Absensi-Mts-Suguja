import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Does not construct any admin page until the server grants access.
class AdminAccessGate extends StatefulWidget {
  final Future<bool> Function() checkAdmin;
  final Future<void> Function() onSignOut;
  final WidgetBuilder builder;
  const AdminAccessGate({
    super.key,
    required this.checkAdmin,
    required this.onSignOut,
    required this.builder,
  });
  @override
  State<AdminAccessGate> createState() => _AdminAccessGateState();
}

class _AdminAccessGateState extends State<AdminAccessGate> {
  late Future<bool> _access;
  @override
  void initState() {
    super.initState();
    _access = widget.checkAdmin();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _access,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.data == true && !snapshot.hasError) {
        return widget.builder(context);
      }
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 44),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.hasError
                        ? 'Akses belum dapat diverifikasi'
                        : 'Akses admin diperlukan',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.hasError
                        ? 'Periksa koneksi dan aktivasi layanan, lalu coba lagi.'
                        : 'Akun ini belum memiliki izin untuk membuka panel admin.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                        ),
                        onPressed: () => setState(() {
                          _access = widget.checkAdmin();
                        }),
                        child: const Text('Coba lagi'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: widget.onSignOut,
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
