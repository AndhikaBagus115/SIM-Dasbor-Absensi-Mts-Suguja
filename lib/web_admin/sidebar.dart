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

  // Status buka/tutup dropdown untuk masing-masing kategori
  bool _expandDataMaster = true;
  bool _expandPresensi = true;
  bool _expandPengaturan = true;

  @override
  void initState() {
    super.initState();
    _autoExpand();
  }

  @override
  void didUpdateWidget(covariant Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _autoExpand();
    }
  }

  void _autoExpand() {
    final idx = widget.selectedIndex;
    if (idx == 2 || idx == 3 || idx == 4) {
      _expandDataMaster = true;
    } else if (idx == 1 || idx == 5) {
      _expandPresensi = true;
    } else if (idx == 6 || idx == 7) {
      _expandPengaturan = true;
    }
  }

  void _toggleSidebar() {
    setState(() => _isCollapsed = !_isCollapsed);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      width: _isCollapsed ? _sidebarWidthCollapsed : _sidebarWidthExpanded,
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
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

            const SizedBox(height: 6),

            // Menu List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                physics: const ClampingScrollPhysics(),
                children: [
                  // 1. MENU UTAMA
                  if (!_isCollapsed) _buildStaticHeader('MENU UTAMA'),
                  _buildMenuItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    index: 0,
                  ),

                  const SizedBox(height: 4),

                  // 2. DATA MASTER (DROPDOWN PADA JUDUL)
                  if (!_isCollapsed) ...[
                    _buildDropdownHeader(
                      title: 'DATA MASTER',
                      isExpanded: _expandDataMaster,
                      containsActive: [2, 3, 4].contains(widget.selectedIndex),
                      onToggle: () => setState(() => _expandDataMaster = !_expandDataMaster),
                    ),
                    if (_expandDataMaster) ...[
                      _buildMenuItem(
                        icon: Icons.person_outline,
                        title: 'Data Guru',
                        index: 2,
                      ),
                      _buildMenuItem(
                        icon: Icons.class_outlined,
                        title: 'Data Kelas',
                        index: 3,
                      ),
                      _buildMenuItem(
                        icon: Icons.school_outlined,
                        title: 'Data Siswa',
                        index: 4,
                      ),
                    ],
                  ] else ...[
                    _buildMenuItem(
                      icon: Icons.person_outline,
                      title: 'Data Guru',
                      index: 2,
                    ),
                    _buildMenuItem(
                      icon: Icons.class_outlined,
                      title: 'Data Kelas',
                      index: 3,
                    ),
                    _buildMenuItem(
                      icon: Icons.school_outlined,
                      title: 'Data Siswa',
                      index: 4,
                    ),
                  ],

                  const SizedBox(height: 4),

                  // 3. PRESENSI & LAYANAN (DROPDOWN PADA JUDUL)
                  if (!_isCollapsed) ...[
                    _buildDropdownHeader(
                      title: 'PRESENSI & LAYANAN',
                      isExpanded: _expandPresensi,
                      containsActive: [1, 5].contains(widget.selectedIndex),
                      onToggle: () => setState(() => _expandPresensi = !_expandPresensi),
                    ),
                    if (_expandPresensi) ...[
                      _buildMenuItem(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'Absensi',
                        index: 1,
                      ),
                      _buildMenuItem(
                        icon: Icons.mail_outline,
                        title: 'Surat',
                        index: 5,
                      ),
                    ],
                  ] else ...[
                    _buildMenuItem(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Absensi',
                      index: 1,
                    ),
                    _buildMenuItem(
                      icon: Icons.mail_outline,
                      title: 'Surat',
                      index: 5,
                    ),
                  ],

                  const SizedBox(height: 4),

                  // 4. PENGATURAN (DROPDOWN PADA JUDUL)
                  if (!_isCollapsed) ...[
                    _buildDropdownHeader(
                      title: 'PENGATURAN',
                      isExpanded: _expandPengaturan,
                      containsActive: [6, 7].contains(widget.selectedIndex),
                      onToggle: () => setState(() => _expandPengaturan = !_expandPengaturan),
                    ),
                    if (_expandPengaturan) ...[
                      _buildMenuItem(
                        icon: Icons.notifications_active_outlined,
                        title: 'Notifikasi',
                        index: 6,
                      ),
                      _buildMenuItem(
                        icon: Icons.manage_accounts_outlined,
                        title: 'Profil Admin',
                        index: 7,
                      ),
                    ],
                  ] else ...[
                    _buildMenuItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notifikasi',
                      index: 6,
                    ),
                    _buildMenuItem(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Profil Admin',
                      index: 7,
                    ),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                    child: Divider(),
                  ),

                  // 5. KELUAR
                  _buildMenuItem(
                    icon: Icons.logout_rounded,
                    title: 'Keluar',
                    index: 8,
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

  Widget _buildStaticHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 18, right: 16, top: 10, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Colors.grey.shade500,
          fontFamily: 'Segoe UI',
        ),
      ),
    );
  }

  Widget _buildDropdownHeader({
    required String title,
    required bool isExpanded,
    required bool containsActive,
    required VoidCallback onToggle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        hoverColor: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.only(left: 18, right: 16, top: 12, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: containsActive ? AppColors.primary : Colors.grey.shade500,
                    fontFamily: 'Segoe UI',
                  ),
                ),
              ),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_right_rounded,
                size: 16,
                color: containsActive ? AppColors.primary : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 70,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: _isCollapsed ? _sidebarWidthCollapsed : _sidebarWidthExpanded,
          child: Row(
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
                          tooltip: 'Tutup Menu',
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
    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _isCollapsed ? 0 : 80,
        curve: Curves.easeInOut,
        child: OverflowBox(
          minWidth: _sidebarWidthExpanded,
          maxWidth: _sidebarWidthExpanded,
          minHeight: 80,
          maxHeight: 80,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _sidebarWidthExpanded,
            height: 80,
            child: Padding(
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
                      errorBuilder: (ctx, err, stack) =>
                          const Icon(Icons.account_circle, size: 30),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
          height: 48,
          decoration: BoxDecoration(
            border: isSelected && !_isCollapsed
                ? const Border(
                    left: BorderSide(color: AppColors.primary, width: 4),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: _isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              SizedBox(
                width: _iconAreaWidth,
                child: Center(
                  child: Tooltip(
                    message: title,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Icon(icon, color: itemColor, size: 24),
                  ),
                ),
              ),
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
