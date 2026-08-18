import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// BASE CARD & SECTION TITLE
// ============================================================================

class WhiteCard extends StatelessWidget {
  final Widget child;
  const WhiteCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ============================================================================
// HEADER & PROFILE
// ============================================================================

class AppHeader extends StatelessWidget {
  final DateTime? lastUpdated;
  final String? errorMessage;
  final VoidCallback onRefresh;

  const AppHeader({
    super.key,
    required this.lastUpdated,
    required this.errorMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final last = lastUpdated == null ? '-' : DateFormat('dd MMM yyyy, HH:mm').format(lastUpdated!);

    return WhiteCard(
      child: Row(
        children: [
          const Icon(Icons.dashboard_rounded, color: Color(0xFF42A5F5)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Dashboard Admin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Terakhir update', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text(last, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
          const ProfileSection(),
          if (errorMessage != null) ...[
            const SizedBox(width: 10),
            Tooltip(
              message: errorMessage!,
              child: const Icon(Icons.error_outline, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFF42A5F5),
          child: Text(
            "A",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text("Admin", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text("MTs Sunan Gunung Jati", style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// STATS CARDS (QUICK & DETAILED)
// ============================================================================

class QuickStatsResponsive extends StatelessWidget {
  final bool isMobile;
  final bool isTablet;

  final int totalSiswa;
  final int hadirHariIni;
  final int terlambatHariIni;
  final int absenHariIni;

  const QuickStatsResponsive({
    super.key,
    required this.isMobile,
    required this.isTablet,
    required this.totalSiswa,
    required this.hadirHariIni,
    required this.terlambatHariIni,
    required this.absenHariIni,
  });

  @override
  Widget build(BuildContext context) {
    final totalHadir = hadirHariIni + terlambatHariIni;
    final persenHadir = (totalSiswa > 0) ? ((totalHadir / totalSiswa) * 100).toStringAsFixed(0) : '0';

    final cards = [
      _StatCardData(
        title: 'Kehadiran Hari Ini',
        value: '$persenHadir%',
        subtitle: '$totalHadir dari $totalSiswa siswa aktif',
        icon: Icons.people_outline,
        color: const Color(0xFF42A5F5),
      ),
      _StatCardData(
        title: 'Terlambat',
        value: terlambatHariIni.toString(),
        subtitle: 'Hari ini',
        icon: Icons.access_time,
        color: const Color(0xFFFFA726),
      ),
      _StatCardData(
        title: 'Absen',
        value: absenHariIni.toString(),
        subtitle: 'Sakit / Izin / Alfa',
        icon: Icons.person_off_outlined,
        color: const Color(0xFFEF5350),
      ),
      _StatCardData(
        title: 'Total Siswa Aktif',
        value: totalSiswa.toString(),
        subtitle: 'Status: aktif',
        icon: Icons.school_outlined,
        color: const Color(0xFFAB47BC),
      ),
    ];

    int crossAxisCount = 4;
    double childAspect = 2.3;

    if (isMobile) {
      crossAxisCount = 1;
      childAspect = 3.2;
    } else if (isTablet) {
      crossAxisCount = 2;
      childAspect = 2.6;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspect,
      ),
      itemBuilder: (_, i) => _StatCard(cards[i]),
    );
  }
}

class _StatCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  _StatCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  const _StatCard(this.data);

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(data.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(data.subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetailedStatsResponsive extends StatelessWidget {
  final bool isMobile;

  final int totalSiswa;
  final int hadirSemester;
  final int terlambatSemester;
  final int absenSemester;
  final int totalHariSemester;

  const DetailedStatsResponsive({
    super.key,
    required this.isMobile,
    required this.totalSiswa,
    required this.hadirSemester,
    required this.terlambatSemester,
    required this.absenSemester,
    required this.totalHariSemester,
  });

  @override
  Widget build(BuildContext context) {
    final totalPotensi = (totalSiswa * totalHariSemester).toDouble();
    final totalHadir = hadirSemester + terlambatSemester;

    if (totalPotensi == 0) {
      return WhiteCard(
        child: SizedBox(
          height: 140,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade400, size: 40),
                const SizedBox(height: 10),
                const Text(
                  'Data rekapan semester belum tersedia.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pHadir = totalPotensi > 0 ? totalHadir / totalPotensi : 0.0;
    final pTerlambat = totalPotensi > 0 ? terlambatSemester / totalPotensi : 0.0;
    final pAbsen = totalPotensi > 0 ? absenSemester / totalPotensi : 0.0;

    final cards = [
      _DetailCardData(
        title: 'Rata-rata Kehadiran',
        value: '${(pHadir * 100).toStringAsFixed(0)}%',
        subtitle: '$totalHadir dari ${totalPotensi.toInt()} potensi',
        color: const Color(0xFF66BB6A),
        icon: Icons.check_circle_outline,
        progress: pHadir,
      ),
      _DetailCardData(
        title: 'Total Keterlambatan',
        value: terlambatSemester.toString(),
        subtitle: '${(pTerlambat * 100).toStringAsFixed(1)}% dari total',
        color: const Color(0xFFFFA726),
        icon: Icons.access_time,
        progress: pTerlambat,
      ),
      _DetailCardData(
        title: 'Total Ketidakhadiran',
        value: absenSemester.toString(),
        subtitle: '${(pAbsen * 100).toStringAsFixed(1)}% dari total',
        color: const Color(0xFFEF5350),
        icon: Icons.person_off_outlined,
        progress: pAbsen,
      ),
      _DetailCardData(
        title: 'Hari (berdasarkan data)',
        value: totalHariSemester.toString(),
        subtitle: 'Hari unik yang memiliki input',
        color: const Color(0xFF42A5F5),
        icon: Icons.calendar_today,
        progress: 1.0,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            _DetailStatCard(cards[i]),
            if (i != cards.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: _DetailStatCard(cards[i])),
          if (i != cards.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _DetailCardData {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final double progress;

  _DetailCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.progress,
  });
}

class _DetailStatCard extends StatelessWidget {
  final _DetailCardData data;
  const _DetailStatCard(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: data.color, width: 3)),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.title.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.4),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(data.value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(data.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: data.progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              color: data.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CHARTS SECTION
// ============================================================================

class ChartsSectionResponsive extends StatelessWidget {
  final bool isMobile;
  final List<Map<String, dynamic>> distribusiKelas;

  const ChartsSectionResponsive({
    super.key,
    required this.isMobile,
    required this.distribusiKelas,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          const StatistikKehadiranChart(),
          const SizedBox(height: 12),
          PieChartCard(distribusiData: distribusiKelas),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(flex: 2, child: StatistikKehadiranChart()),
        const SizedBox(width: 12),
        Expanded(child: PieChartCard(distribusiData: distribusiKelas)),
      ],
    );
  }
}

class StatistikKehadiranChart extends StatefulWidget {
  const StatistikKehadiranChart({super.key});

  @override
  State<StatistikKehadiranChart> createState() => _StatistikKehadiranChartState();
}

class _StatistikKehadiranChartState extends State<StatistikKehadiranChart> {
  final SupabaseClient supabase = Supabase.instance.client;

  int _selectedFilterIndex = 0;
  final List<String> _filters = const ['Hari Ini', 'Minggu Ini', 'Bulan Ini', 'Periode'];

  bool _isLoading = true;
  List<FlSpot> _spots = const [];
  Map<double, String> _bottomTitles = const {};

  double _maxY = 10;
  double _minX = 0;
  double _maxX = 6;
  double _intervalX = 1;

  @override
  void initState() {
    super.initState();
    _fetchChartData(_selectedFilterIndex);
  }

  Future<void> _fetchChartData(int index) async {
    setState(() => _isLoading = true);

    try {
      String rpcName;
      switch (index) {
        case 1:
          rpcName = 'get_statistik_mingguan';
          break;
        case 2:
          rpcName = 'get_statistik_bulanan';
          break;
        case 3:
          rpcName = 'get_statistik_tahunan';
          break;
        default:
          rpcName = 'get_statistik_harian';
          break;
      }

      final List<dynamic> result = await supabase.rpc(rpcName);

      final List<FlSpot> spots = [];
      final Map<double, String> titles = {};
      double i = 0;
      double maxVal = 0;

      if (result.isEmpty) {
        spots.add(const FlSpot(0, 0));
        titles[0] = '-';
        maxVal = 10;
        i = 1;
      } else {
        for (final item in result) {
          final label = item['label'].toString();
          final value = double.tryParse(item['value'].toString()) ?? 0.0;

          spots.add(FlSpot(i, value));
          titles[i] = label;

          if (value > maxVal) maxVal = value;
          i++;
        }
      }

      setState(() {
        _spots = spots;
        _bottomTitles = titles;
        _minX = 0;
        _maxX = (i - 1).clamp(0, double.infinity);
        _maxY = (maxVal == 0) ? 10 : (maxVal * 1.2).ceilToDouble();
        _intervalX = (i > 10) ? (i / 10).floorToDouble().clamp(1, 999) : 1;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _spots = const [FlSpot(0, 0)];
        _bottomTitles = {0: 'Err'};
        _minX = 0;
        _maxX = 0;
        _maxY = 10;
        _intervalX = 1;
      });
    }
  }

  List<Widget> _buildFilters() {
    return List.generate(
      _filters.length,
      (i) => Padding(
        padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
        child: InkWell(
          onTap: () {
            setState(() => _selectedFilterIndex = i);
            _fetchChartData(i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: i == _selectedFilterIndex ? const Color(0xFF42A5F5) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: i == _selectedFilterIndex ? const Color(0xFF42A5F5) : Colors.grey.shade200,
              ),
            ),
            child: Text(
              _filters[i],
              style: TextStyle(
                color: i == _selectedFilterIndex ? Colors.white : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getLeftTitle(double v) => v.toInt().toString();

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF42A5F5)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Statistik Kehadiran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _buildFilters())),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 260,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _maxY > 0 ? _maxY / 5 : 5,
                        getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: _intervalX,
                            getTitlesWidget: (value, meta) {
                              final title = _bottomTitles[value.toDouble()];
                              if (title == null) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: _maxY > 0 ? _maxY / 5 : 5,
                            reservedSize: 36,
                            getTitlesWidget: (v, _) => Text(
                              _getLeftTitle(v),
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: _minX,
                      maxX: _maxX,
                      minY: 0,
                      maxY: _maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _spots,
                          isCurved: true,
                          color: const Color(0xFF42A5F5),
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: const Color(0xFF42A5F5),
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.10),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => Colors.blueAccent,
                          getTooltipItems: (spots) => spots
                              .map(
                                (s) => LineTooltipItem(
                                  '${s.y.toInt()} siswa',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class PieChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> distribusiData;
  const PieChartCard({super.key, required this.distribusiData});

  @override
  Widget build(BuildContext context) {
    final total = distribusiData.fold<double>(0.0, (sum, item) => sum + (item['value'] as double));

    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.pie_chart_outline, color: Color(0xFF42A5F5)),
              SizedBox(width: 10),
              Text('Distribusi per Kelas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 210,
            child: total == 0
                ? Center(
                    child: Text('Belum ada data distribusi siswa', style: TextStyle(color: Colors.grey.shade600)),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 52,
                      sections: distribusiData.map((d) {
                        final v = d['value'] as double;
                        final percent = (v / total * 100);
                        return PieChartSectionData(
                          value: v,
                          color: d['color'] as Color,
                          title: percent >= 7 ? '${percent.toStringAsFixed(0)}%' : '',
                          radius: 62,
                          titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          ...distribusiData.take(8).map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: d['color'] as Color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d['label'] as String,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(d['value'] as double).toInt()}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ============================================================================
// MONITORING & ACTIVITIES
// ============================================================================

class BottomSectionResponsive extends StatelessWidget {
  final bool isMobile;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> activities;

  const BottomSectionResponsive({
    super.key,
    required this.isMobile,
    required this.alerts,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          AlertsCard(alerts: alerts),
          const SizedBox(height: 12),
          ActivityCard(activities: activities),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: AlertsCard(alerts: alerts)),
        const SizedBox(width: 12),
        Expanded(child: ActivityCard(activities: activities)),
      ],
    );
  }
}

class AlertsCard extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;
  const AlertsCard({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.notifications_outlined, color: Color(0xFF42A5F5)),
              SizedBox(width: 10),
              Text('Peringatan Sistem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          ...alerts.map((a) => Padding(padding: const EdgeInsets.only(bottom: 12), child: AlertItem(a))),
        ],
      ),
    );
  }
}

class AlertItem extends StatelessWidget {
  final Map<String, dynamic> data;
  const AlertItem(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    final Color c = data['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
            child: Icon(data['icon'] as IconData, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title']?.toString() ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(data['subtitle']?.toString() ?? '-', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  const ActivityCard({super.key, required this.activities});

  IconData _getIconForStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'hadir':
      case 'pulang':
        return Icons.check_circle;
      case 'terlambat':
        return Icons.access_time;
      case 'sakit':
      case 'izin':
        return Icons.mail_outline;
      case 'alfa':
        return Icons.cancel;
      default:
        return Icons.qr_code;
    }
  }

  Color _getColorForStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'hadir':
      case 'pulang':
        return const Color(0xFF66BB6A);
      case 'terlambat':
        return const Color(0xFFFFA726);
      case 'sakit':
      case 'izin':
        return const Color(0xFF42A5F5);
      case 'alfa':
        return const Color(0xFFEF5350);
      default:
        return Colors.grey;
    }
  }

  String _formatTimeAgo(String? isoString) {
    if (isoString == null) return '-';
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return '-';

    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.update, color: Color(0xFF42A5F5)),
              SizedBox(width: 10),
              Text('Aktivitas Terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('Belum ada aktivitas hari ini', style: TextStyle(color: Colors.grey.shade600))),
            ),
          ...activities.map((a) {
            final status = a['status'] as String?;
            final namaSiswa = (a['siswa'] is Map) ? (a['siswa']['nama'] ?? 'Siswa tidak dikenal') : 'Siswa tidak dikenal';
            final waktuMasuk = a['waktu_masuk']?.toString();
            final createdAt = a['created_at']?.toString();

            final color = _getColorForStatus(status);
            final icon = _getIconForStatus(status);

            final timeLabel = waktuMasuk ??
                (createdAt != null ? DateFormat("HH:mm").format(DateTime.parse(createdAt).toLocal()) : '-');

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$namaSiswa • ${status?.toLowerCase() ?? 'scan'}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text('Scan pada $timeLabel', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(_formatTimeAgo(createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
