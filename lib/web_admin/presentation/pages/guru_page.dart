import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';

// --- MODEL KELAS OPTION (Untuk MultiSelect) ---
class KelasOption {
  final String id;
  final String nama;

  KelasOption({required this.id, required this.nama});

  Map<String, dynamic> toJson() => {'id': id, 'nama': nama};

  factory KelasOption.fromJson(Map<String, dynamic> json) => KelasOption(
    id: json['id'] as String? ?? '',
    nama: json['nama'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KelasOption && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// --- PAGE GURU ---
class PageGuru extends StatefulWidget {
  final String schoolName;
  const PageGuru({super.key, required this.schoolName});

  @override
  State<PageGuru> createState() => _PageGuruState();
}

class _PageGuruState extends State<PageGuru> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> guruData = [];

  @override
  void initState() {
    super.initState();
    fetchGuru();
  }

  Future<void> fetchGuru() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('guru')
          .select()
          .order('nama', ascending: true);
      if (mounted) {
        setState(() {
          guruData = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar("Gagal memuat data guru: $e");
        setState(() => isLoading = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showFormDialog({Map<String, dynamic>? guru}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              guru == null ? Icons.person_add : Icons.edit,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(guru == null ? 'Tambah Data Guru' : 'Edit Data Guru'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: SingleChildScrollView(
            child: FormGuru(
              initialData: guru,
              onSave: (data) async {
                try {
                  if (guru == null) {
                    final String password = data['password'];

                    final tempClient = SupabaseClient(
                      AppConstants.supabaseUrl,
                      AppConstants.supabaseAnonKey,
                      authOptions: const FlutterAuthClientOptions(
                        authFlowType: AuthFlowType.implicit,
                      ),
                    );

                    final authResponse = await tempClient.auth.signUp(
                      email: data['email'],
                      password: password,
                    );

                    if (authResponse.user == null) {
                      throw "Gagal membuat akun login.";
                    }

                    final newUserId = authResponse.user!.id;

                    final guruDataToInsert = Map<String, dynamic>.from(data);
                    guruDataToInsert['id'] = newUserId;

                    guruDataToInsert.remove('password');
                    if (guruDataToInsert['avatar_url'] == null) {
                      guruDataToInsert.remove('avatar_url');
                    }

                    await supabase.from('guru').insert(guruDataToInsert);

                    _showSuccessSnackbar(
                      'Guru ${data['nama']} berhasil ditambahkan.',
                    );

                    tempClient.dispose();
                  } else {
                    final id = guru['id'];
                    data.remove('password');

                    await supabase.from('guru').update(data).eq('id', id);

                    _showSuccessSnackbar(
                      'Data guru ${data['nama']} berhasil diupdate',
                    );
                  }

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }

                  fetchGuru();
                } catch (e) {
                  if (e.toString().contains("User already registered")) {
                    throw "Email sudah terdaftar sebagai pengguna lain.";
                  }
                  throw e.toString();
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> guru) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Data Guru'),
        content: Text('Yakin ingin menghapus data guru ${guru['nama']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                final id = guru['id'];
                await supabase.from('guru').delete().eq('id', id);

                final avatarUrl = guru['avatar_url'] as String?;
                if (avatarUrl != null && avatarUrl.isNotEmpty) {
                  try {
                    final fileName = avatarUrl.split('/').last;
                    await supabase.storage.from('avatars').remove([
                      'public/$fileName',
                    ]);
                  } catch (_) {}
                }

                if (dialogContext.mounted) Navigator.of(dialogContext).pop();

                _showSuccessSnackbar(
                  'Data guru ${guru['nama']} berhasil dihapus',
                );
                fetchGuru();
              } catch (e) {
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                _showErrorSnackbar("Gagal menghapus data: $e");
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 28),
            _buildAddButton(),
            const SizedBox(height: 16),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Data Guru',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.school, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.schoolName,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 11, 226, 43),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.person_add),
        label: const Text(
          'Tambah Data Guru',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showFormDialog(),
      ),
    );
  }

  Widget _buildTable() {
    if (guruData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Tidak ada data guru ditemukan.'),
        ),
      );
    }

    final ScrollController horizontalController = ScrollController();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          final double minTableWidth = constraints.maxWidth;

          return Scrollbar(
            controller: horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTableWidth),
                child: DataTable(
                  columnSpacing: 24,
                  headingRowHeight: 56,
                  dataRowMinHeight: 80,
                  dataRowMaxHeight: 80,
                  headingRowColor: WidgetStateProperty.all(
                    Colors.blue.shade50,
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Nama',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Email',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 80,
                        child: Text(
                          'Role',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Kelas Diampu',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 80,
                        child: Text(
                          'Avatar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 180,
                        child: Text(
                          'Aksi',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                  rows: List.generate(guruData.length, (i) {
                    final guru = guruData[i];

                    final dynamic data = guru['kelas_diampu'];
                    List<String> semuaKelas = [];
                    if (data is Map<String, dynamic>) {
                      data.forEach((key, value) {
                        if (value is List) {
                          semuaKelas.addAll(value.cast<String>());
                        }
                      });
                    }
                    final kelasDiampuText = semuaKelas.isNotEmpty
                        ? semuaKelas.join(', ')
                        : '-';

                    return DataRow(
                      cells: [
                        DataCell(Text(guru['nama'] ?? '-')),
                        DataCell(Text(guru['email'] ?? '-')),
                        DataCell(
                          SizedBox(
                            width: 80,
                            child: Center(child: Text(guru['role'] ?? '-')),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 200,
                            child: Text(
                              kelasDiampuText,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 80,
                            child: Center(
                              child:
                                  (guru['avatar_url'] != null &&
                                      guru['avatar_url'].isNotEmpty)
                                  ? CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        guru['avatar_url'],
                                      ),
                                    )
                                  : const CircleAvatar(
                                      child: Icon(Icons.person),
                                    ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildActionButton(
                                  Icons.edit,
                                  'Edit',
                                  Colors.blue,
                                  onPressed: () => _showFormDialog(guru: guru),
                                ),
                                const SizedBox(width: 8),
                                _buildActionButton(
                                  Icons.delete,
                                  'Hapus',
                                  Colors.red,
                                  onPressed: () => _showDeleteDialog(guru),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _buildActionButton(
  IconData icon,
  String label,
  Color color, {
  VoidCallback? onPressed,
}) {
  return ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: color.withValues(alpha: 0.1),
      foregroundColor: color,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    icon: Icon(icon, size: 16),
    label: Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    onPressed: onPressed,
  );
}

class FormGuru extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const FormGuru({super.key, this.initialData, required this.onSave});

  @override
  State<FormGuru> createState() => _FormGuruState();
}

class _FormGuruState extends State<FormGuru> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient supabase = Supabase.instance.client;

  late final TextEditingController _namaController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  String? _selectedRole;
  List<KelasOption> _selectedKelas = [];
  bool _isUploading = false;
  bool _obscurePassword = true;

  Uint8List? _avatarBytes;
  String? _existingAvatarUrl;

  final List<String> _roleOptions = ['guru', 'admin'];
  final List<KelasOption> _kelasOptions = [
    KelasOption(id: '7A', nama: 'Kelas 7A'),
    KelasOption(id: '7B', nama: 'Kelas 7B'),
    KelasOption(id: '8A', nama: 'Kelas 8A'),
    KelasOption(id: '8B', nama: 'Kelas 8B'),
    KelasOption(id: '9A', nama: 'Kelas 9A'),
    KelasOption(id: '9B', nama: 'Kelas 9B'),
  ];
  late final Map<String, KelasOption> _kelasLookup;

  @override
  void initState() {
    super.initState();
    _kelasLookup = {for (var k in _kelasOptions) k.nama: k};

    final data = widget.initialData;
    _namaController = TextEditingController(text: data?['nama'] ?? '');
    _emailController = TextEditingController(text: data?['email'] ?? '');
    _passwordController = TextEditingController();

    final initialRole = data?['role'];
    _selectedRole = _roleOptions.contains(initialRole) ? initialRole : 'guru';
    _existingAvatarUrl = data?['avatar_url'];

    final dynamic kelasData = data?['kelas_diampu'];
    if (kelasData is Map<String, dynamic>) {
      final Map<String, dynamic> kelasDiampuMap = kelasData;
      List<KelasOption> initialKelas = [];
      kelasDiampuMap.forEach((key, value) {
        if (value is List) {
          for (final dynamic kelasNama in value) {
            if (kelasNama is String && _kelasLookup.containsKey(kelasNama)) {
              initialKelas.add(_kelasLookup[kelasNama]!);
            }
          }
        }
      });
      _selectedKelas = initialKelas;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_isUploading) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);

      try {
        String? avatarUrl = _existingAvatarUrl;

        if (_avatarBytes != null) {
          final fileName =
              'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = 'public/$fileName';

          await supabase.storage
              .from('avatars')
              .uploadBinary(
                filePath,
                _avatarBytes!,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                ),
              );

          avatarUrl = supabase.storage.from('avatars').getPublicUrl(filePath);
        }

        Map<String, List<String>> groupedKelas = {};
        for (final kelas in _selectedKelas) {
          String tingkat = "Kelas ${kelas.id[0]}";
          if (!groupedKelas.containsKey(tingkat)) {
            groupedKelas[tingkat] = [];
          }
          groupedKelas[tingkat]!.add(kelas.nama);
        }
        groupedKelas.forEach((key, value) => value.sort());

        final dataToSave = {
          'nama': _namaController.text,
          'email': _emailController.text,
          'role': _selectedRole,
          'kelas_diampu': groupedKelas,
          'avatar_url': avatarUrl,
          'password': _passwordController.text,
        };

        await widget.onSave(dataToSave);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Terjadi kesalahan: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialData != null;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatarPicker(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _namaController,
            decoration: const InputDecoration(
              labelText: 'Nama Guru',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Nama harus diisi' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            readOnly: isEditing,
            decoration: InputDecoration(
              labelText: 'Email',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.email),
              fillColor: isEditing ? Colors.grey.shade200 : null,
              filled: isEditing,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email harus diisi';
              if (!v.contains('@')) return 'Email tidak valid';
              return null;
            },
          ),
          if (!isEditing) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password Login App',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password harus diisi';
                if (v.length < 6) return 'Password minimal 6 karakter';
                return null;
              },
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.work),
            ),
            items: _roleOptions
                .map(
                  (role) =>
                      DropdownMenuItem<String>(value: role, child: Text(role)),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedRole = val),
            validator: (v) => v == null ? 'Role harus dipilih' : null,
          ),
          const SizedBox(height: 16),
          MultiSelectChipField<KelasOption?>(
            items: _kelasOptions
                .map((kelas) => MultiSelectItem<KelasOption>(kelas, kelas.nama))
                .toList(),
            initialValue: _selectedKelas,
            title: const Text("Kelas Diampu"),
            headerColor: Colors.blue.withValues(alpha: 0.1),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400, width: 1.0),
              borderRadius: BorderRadius.circular(4),
            ),
            selectedChipColor: Colors.blue.withValues(alpha: 0.2),
            selectedTextStyle: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
            onTap: (values) {
              _selectedKelas = values.whereType<KelasOption>().toList();
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isUploading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPicker() {
    ImageProvider? imageProvider;
    if (_avatarBytes != null) {
      imageProvider = MemoryImage(_avatarBytes!);
    } else if (_existingAvatarUrl != null && _existingAvatarUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_existingAvatarUrl!);
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? const Icon(Icons.person, size: 50, color: Colors.grey)
              : null,
        ),
        TextButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text('Ubah Foto'),
          onPressed: _pickAvatar,
        ),
      ],
    );
  }
}
