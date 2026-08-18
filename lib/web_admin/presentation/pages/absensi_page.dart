import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../logic/absensi_controller.dart';

class PageAbsensi extends StatelessWidget {
  final String schoolName;

  const PageAbsensi({super.key, required this.schoolName});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AbsensiController(schoolName: schoolName),
      child: Consumer<AbsensiController>(
        builder: (context, controller, _) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: controller.fetchData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AbsensiHeader(schoolName: controller.schoolName),
                      const SizedBox(height: 24),
                      _buildFilterSection(context, controller),
                      const SizedBox(height: 24),
                      controller.isLoading
                          ? const SizedBox(
                              height: 300,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _AbsensiContent(controller: controller),
                    ],
                  ),
                ),
              ),
            ),
            floatingActionButton: FloatingActionButton(
              backgroundColor: Colors.blue.shade700,
              onPressed: () async {
                await controller.fetchData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data diperbarui')),
                  );
                }
              },
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterSection(
    BuildContext context,
    AbsensiController controller,
  ) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ModeButton(
                  title: "Absensi Harian",
                  isActive: !controller.isRekapMode,
                  onTap: () => controller.toggleMode(false),
                  activeColor: Colors.blue.shade50,
                  activeTextColor: Colors.blue.shade800,
                ),
              ),
              Expanded(
                child: _ModeButton(
                  title: "Rekap Bulanan",
                  isActive: controller.isRekapMode,
                  onTap: () => controller.toggleMode(true),
                  activeColor: Colors.green.shade50,
                  activeTextColor: Colors.green.shade800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (!controller.isRekapMode) ...[
              Container(
                width: 70,
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: _boxDecoration(),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: controller.itemLimit,
                    icon: const Icon(Icons.arrow_drop_down),
                    isExpanded: true,
                    items: [5, 10, 20, 50, 100]
                        .map(
                          (val) =>
                              DropdownMenuItem(value: val, child: Text("$val")),
                        )
                        .toList(),
                    onChanged: (val) => controller.updateLimit(val),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: _AbsensiDatePicker(controller: controller),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: _KelasFilterDropdown(controller: controller),
            ),
          ],
        ),
      ],
    );
  }

  BoxDecoration _boxDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withValues(alpha: 0.08),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

class _AbsensiHeader extends StatelessWidget {
  final String schoolName;
  const _AbsensiHeader({required this.schoolName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Data Absensi',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.school, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                schoolName,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final Color activeTextColor;

  const _ModeButton({
    required this.title,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    required this.activeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? activeTextColor : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _AbsensiDatePicker extends StatelessWidget {
  final AbsensiController controller;
  const _AbsensiDatePicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    String label = "Pilih Tanggal";
    String value = DateFormat(
      'EEEE, dd MMM yyyy',
      'id_ID',
    ).format(controller.selectedDate);

    if (controller.isRekapMode) {
      label = "Pilih Bulan";
      value = DateFormat('MMMM yyyy', 'id_ID').format(controller.selectedDate);
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => controller.handleDatePick(context),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
          ],
        ),
      ),
    );
  }
}

class _KelasFilterDropdown extends StatelessWidget {
  final AbsensiController controller;
  const _KelasFilterDropdown({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: controller.isKelasLoading
          ? const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: controller.selectedKelasId,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                hint: const Text("Semua Kelas", style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text("Semua Kelas", style: TextStyle(fontSize: 13)),
                  ),
                  ...controller.daftarKelas.map((kelas) {
                    return DropdownMenuItem<int?>(
                      value: kelas['id'],
                      child: Text(
                        kelas['nama_kelas'],
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (val) => controller.onKelasSelected(val),
              ),
            ),
    );
  }
}

class _AbsensiContent extends StatelessWidget {
  final AbsensiController controller;
  const _AbsensiContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.isRekapMode) {
      if (controller.rekapData.isEmpty) {
        return _EmptyStateView(
          controller: controller,
          message: "Tidak ada data rekap untuk bulan ini.",
        );
      }
    } else {
      if (controller.absensiData.isEmpty) {
        return _EmptyStateView(
          controller: controller,
          message: "Tidak ada data absensi pada tanggal ini.",
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf, size: 18),
          label: Text(
            controller.isRekapMode
                ? 'Export Laporan Bulanan'
                : 'Export Laporan Harian',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 209, 33, 33),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => controller.exportPdf(context),
        ),
        const SizedBox(height: 16),
        controller.isRekapMode
            ? _RekapTable(controller: controller)
            : _AbsensiTable(controller: controller),
        const SizedBox(height: 16),
        if (!controller.isRekapMode) _buildPagination(controller),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildPagination(AbsensiController controller) {
    final int totalData = controller.totalRows;
    final int current = controller.currentPage;
    final int limit = controller.itemLimit;

    final int startItem = totalData == 0 ? 0 : ((current - 1) * limit) + 1;
    final int endItem = (current * limit) > totalData
        ? totalData
        : (current * limit);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Text(
                "Rows:",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: controller.itemLimit,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: const [5, 10, 20, 50, 100]
                      .map(
                        (val) => DropdownMenuItem<int>(
                          value: val,
                          child: Text("$val"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => controller.updateLimit(val),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          "$startItem - $endItem dari $totalData",
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        _pageButton(
          Icons.chevron_left,
          current > 1 ? controller.prevPage : null,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            "$current",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _pageButton(
          Icons.chevron_right,
          current < controller.totalPages ? controller.nextPage : null,
        ),
      ],
    );
  }

  Widget _pageButton(IconData icon, VoidCallback? onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: onPressed == null ? Colors.grey : Colors.black),
        onPressed: onPressed,
      ),
    );
  }
}

class _AbsensiTable extends StatelessWidget {
  final AbsensiController controller;
  const _AbsensiTable({required this.controller});

  @override
  Widget build(BuildContext context) {
    final displayData = controller.absensiData;
    final int startNumber = (controller.currentPage - 1) * controller.itemLimit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 16,
                headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                columns: const [
                  DataColumn(
                    label: Text(
                      'No',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Nama Siswa',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Waktu Masuk',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Waktu Pulang',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Keterangan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Diperbarui Oleh',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: List.generate(displayData.length, (index) {
                  final row = displayData[index];
                  final siswa = row['siswa'] ?? {};
                  final nama = siswa['nama'] ?? '-';
                  final status = row['status'] ?? 'alfa';
                  final guru = row['guru'];
                  final diperbaruiOleh = (guru != null && guru['nama'] != null)
                      ? guru['nama']
                      : '-';

                  return DataRow(
                    cells: [
                      DataCell(Text("${startNumber + index + 1}")),
                      DataCell(
                        Text(
                          nama,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(controller.fmtTime(row['waktu_masuk']))),
                      DataCell(Text(controller.fmtTime(row['waktu_pulang']))),
                      DataCell(_StatusBadge(status: status)),
                      DataCell(
                        Text(
                          row['keterangan'] ?? '-',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Text(diperbaruiOleh, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RekapTable extends StatelessWidget {
  final AbsensiController controller;
  const _RekapTable({required this.controller});

  @override
  Widget build(BuildContext context) {
    final data = controller.rekapData;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 24,
                headingRowColor: WidgetStateProperty.all(
                  Colors.green.shade50,
                ),
                columns: const [
                  DataColumn(
                    label: Text(
                      'Nama Siswa',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Hadir',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Telat',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Sakit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Izin',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Alfa',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '%',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: List.generate(data.length, (index) {
                  final item = data[index];
                  final nama = item['nama_siswa'] ?? 'Unknown';

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          nama,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(Center(child: Text(item['hadir'].toString()))),
                      DataCell(
                        Center(child: Text(item['terlambat'].toString())),
                      ),
                      DataCell(Center(child: Text(item['sakit'].toString()))),
                      DataCell(Center(child: Text(item['izin'].toString()))),
                      DataCell(Center(child: Text(item['alpha'].toString()))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${item['persentase']}%",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'pulang':
        color = Colors.green;
        break;
      case 'terlambat':
        color = Colors.orange;
        break;
      case 'sakit':
        color = Colors.purple;
        break;
      case 'izin':
        color = Colors.blue;
        break;
      case 'alfa':
      default:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  final AbsensiController controller;
  final String message;

  const _EmptyStateView({
    required this.controller,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Muat Ulang'),
            onPressed: controller.fetchData,
          ),
        ],
      ),
    );
  }
}
