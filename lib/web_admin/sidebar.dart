import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'core/theme.dart';

// Lebar Sidebar
const double _sidebarWidthExpanded = 250.0;
const double _sidebarWidthCollapsed = 70.0;

// Lebar Area Icon (Dikecilkan dari 70 jadi 60 agar tidak overflow border 1px)
const double _iconAreaWidth = 60.0;

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onMenuSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onMenuSelected,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isCollapsed = false;

  void _toggleSidebar() {
    setState(() => _isCollapsed = !_isCollapsed);
  }

  @override
  Widget build(BuildContext context) {
    // Definisi Menu
    final List<Map<String, dynamic>> menuItems = [
      {'icon': Icons.dashboard_outlined, 'title': 'Dashboard', 'index': 0},
      {
        'icon': Icons.assignment_turned_in_outlined,
        'title': 'Absensi',
        'index': 1,
      },
      {'icon': Icons.person_outline, 'title': 'Data Guru', 'index': 2},
      {'icon': Icons.class_outlined, 'title': 'Data Kelas', 'index': 3},
      {'icon': Icons.school_outlined, 'title': 'Data Siswa', 'index': 4},
      {'icon': Icons.mail_outline, 'title': 'Surat', 'index': 5},
      {'icon': Icons.notifications_active_outlined, 'title': 'Test Notifikasi', 'index': 6},
    ];

    return AnimatedContainer(
      width: _isCollapsed ? _sidebarWidthCollapsed : _sidebarWidthExpanded,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
      // Clip layout agar tidak ada yang bocor keluar
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        // Border kanan 1px ini yang memakan tempat layout sebelumnya
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            const Divider(height: 1, thickness: 1),

            // Profile Admin
            _buildAdminProfile(),

            const SizedBox(height: 10),

            // Menu List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                // Cegah scroll horizontal di listview
                physics: const ClampingScrollPhysics(),
                children: [
                  ...menuItems.map(
                    (item) => _buildMenuItem(
                      icon: item['icon'] as IconData,
                      title: item['title'] as String,
                      index: item['index'] as int,
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    child: Divider(),
                  ),

                  _buildMenuItem(
                    icon: Icons.logout_rounded,
                    title: 'Keluar',
                    index: 7,
                    isLogout: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Gunakan LayoutBuilder agar responsif terhadap lebar parent
    return SizedBox(
      height: 70,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: _isCollapsed ? _sidebarWidthCollapsed : _sidebarWidthExpanded,
          child: Row(
            // Center jika collapsed agar icon pas ditengah
            mainAxisAlignment: _isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              if (_isCollapsed)
                IconButton(
                  icon: const Icon(Icons.menu_open_rounded),
                  color: AppColors.primary,
                  onPressed: _toggleSidebar,
                  tooltip: 'Buka Menu',
                )
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppConstants.schoolName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Panel Admin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          color: AppColors.primary,
                          onPressed: _toggleSidebar,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminProfile() {
    // Animasi tinggi profil
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _isCollapsed ? 0 : 80,
      curve: Curves.easeInOut,
      clipBehavior: Clip.hardEdge,
      child: OverflowBox(
        minWidth: _sidebarWidthExpanded,
        maxWidth: _sidebarWidthExpanded,
        alignment: Alignment.topLeft,
        child: Container(
          width: _sidebarWidthExpanded, // Paksa lebar penuh agar tidak gepeng
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/Logo MTS.png',
                  width: 30,
                  height: 30,
                  // Fallback jika gambar error/belum load
                  errorBuilder: (ctx, err, stack) =>
                      const Icon(Icons.account_circle, size: 30),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Administrator',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Online',
                        style: TextStyle(color: Colors.green, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required int index,
    bool isLogout = false,
  }) {
    final bool isSelected = widget.selectedIndex == index;
    final Color itemColor = isLogout
        ? AppColors.error
        : (isSelected ? AppColors.primary : AppColors.textDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onMenuSelected(index),
        hoverColor: isLogout
            ? AppColors.error.withValues(alpha: 0.05)
            : AppColors.primary.withValues(alpha: 0.05),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: isSelected && !_isCollapsed
                ? const Border(
                    left: BorderSide(color: AppColors.primary, width: 4),
                  )
                : null,
          ),
          child: Row(
            // Jika collapsed, center content. Jika expanded, start.
            mainAxisAlignment: _isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              // AREA ICON
              // Lebar diset 60 (bukan 70) agar aman dari border 1px sidebar
              SizedBox(
                width: _iconAreaWidth,
                child: Center(child: Icon(icon, color: itemColor, size: 24)),
              ),

              // AREA TEXT
              if (!_isCollapsed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: itemColor,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFamily: 'Segoe UI',
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
