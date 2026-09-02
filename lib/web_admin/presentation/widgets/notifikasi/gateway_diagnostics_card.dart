import 'package:flutter/material.dart';

class GatewayDiagnosticsCard extends StatelessWidget {
  final TextEditingController pushTitleController;
  final TextEditingController pushMessageController;
  final TextEditingController phoneController;
  final bool isLoading;
  final VoidCallback onTestOneSignalConnection;
  final VoidCallback onSendTestBroadcastPush;
  final VoidCallback onTestWahaConnection;

  const GatewayDiagnosticsCard({
    super.key,
    required this.pushTitleController,
    required this.pushMessageController,
    required this.phoneController,
    required this.isLoading,
    required this.onTestOneSignalConnection,
    required this.onSendTestBroadcastPush,
    required this.onTestWahaConnection,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TabBar(
                labelColor: Color(0xFF1E293B),
                unselectedLabelColor: Color(0xFF94A3B8),
                indicatorColor: Color(0xFF4F46E5),
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: Icon(Icons.phone_iphone_rounded, size: 18),
                    text: 'Uji OneSignal Push',
                  ),
                  Tab(
                    icon: Icon(Icons.chat_rounded, size: 18),
                    text: 'Uji WhatsApp Direct',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: TabBarView(
                  children: [
                    // Tab 1: OneSignal Push Test
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: pushTitleController,
                                decoration: const InputDecoration(
                                  labelText: 'Judul Push',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : onTestOneSignalConnection,
                              icon: const Icon(Icons.sync_rounded, size: 16),
                              label: const Text('Cek API'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE54B4D),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: pushMessageController,
                          decoration: const InputDecoration(
                            labelText: 'Pesan Push Notification',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                isLoading ? null : onSendTestBroadcastPush,
                            icon: const Icon(Icons.cell_tower_rounded,
                                size: 18),
                            label: const Text(
                                'Kirim Test Push Broadcast (Semua User App)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE54B4D),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Tab 2: WhatsApp Test
                    Column(
                      children: [
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor WhatsApp Tujuan',
                            hintText: '08123456789 atau 628123456789',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Mengirim pesan test verifikasi server WAHA gateway langsung ke nomor WhatsApp di atas.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : onTestWahaConnection,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('Kirim Test Pesan WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExecutionLogCard extends StatelessWidget {
  final String logOutput;
  final VoidCallback onClearLogs;
  final double height;

  const ExecutionLogCard({
    super.key,
    required this.logOutput,
    required this.onClearLogs,
    this.height = 500,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.terminal_rounded,
                      color: Colors.greenAccent, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Live Execution Log',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: onClearLogs,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: 'Bersihkan log',
                ),
              ],
            ),
            const Divider(height: 16),
            SizedBox(
              height: height,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    logOutput.isEmpty
                        ? 'Menunggu aksi pengiriman notifikasi / pengumuman...\nSemua respons WhatsApp & OneSignal akan dicatat secara langsung di sini.'
                        : logOutput,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.5,
                      color: logOutput.isEmpty
                          ? Colors.grey
                          : const Color(0xFF4ADE80),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OneSignalInfoCard extends StatelessWidget {
  const OneSignalInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.hub_outlined, color: Color(0xFFE54B4D), size: 18),
                SizedBox(width: 8),
                Text(
                  'Aturan ID OneSignal Mobile',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 18),
            _buildInfoBullet('Target Semua',
                'Segment: "Total Subscriptions" (Semua HP Terdaftar)'),
            const SizedBox(height: 6),
            _buildInfoBullet('Target Siswa',
                'External User ID = String id siswa (contoh: "94")'),
            const SizedBox(height: 6),
            _buildInfoBullet('Target Kelas',
                'External User ID = Array id siswa sekelas (contoh: ["94", "95"])'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBullet(String label, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

