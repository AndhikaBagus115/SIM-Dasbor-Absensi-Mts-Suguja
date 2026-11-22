import 'package:flutter/material.dart';
import '../../core/services/report_export_service.dart';
import '../../core/utils/report_file_saver.dart';

class ReportExportButton extends StatefulWidget {
  const ReportExportButton({super.key, required this.load});
  final Future<TabularReport> Function() load;
  @override
  State<ReportExportButton> createState() => _ReportExportButtonState();
}

class _ReportExportButtonState extends State<ReportExportButton> {
  bool _busy = false;
  Future<void> _export(ReportFormat format) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final report = await widget.load();
      final bytes = ReportExportService.encode(report, format);
      final saved = await saveReportFile(
        bytes,
        '${report.filename}.${format.name}',
      );
      if (mounted && saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${report.rows.length} baris diekspor.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ekspor gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<ReportFormat>(
    enabled: !_busy,
    onSelected: _export,
    tooltip: 'Ekspor seluruh data sesuai filter',
    itemBuilder: (_) => const [
      PopupMenuItem(value: ReportFormat.xlsx, child: Text('Excel (.xlsx)')),
      PopupMenuItem(value: ReportFormat.csv, child: Text('CSV (.csv)')),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined, size: 20),
          const SizedBox(width: 8),
          Text(_busy ? 'Menyiapkan laporan...' : 'Ekspor'),
        ],
      ),
    ),
  );
}
