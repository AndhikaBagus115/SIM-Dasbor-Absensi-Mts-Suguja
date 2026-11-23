# Kontrak database yang dikonfirmasi

Acuan: definisi CREATE TABLE dan enum yang dikirim pengelola pada pengerjaan audit A1–A8,
22 November 2026. Dokumen ini mencatat kontrak aplikasi, bukan skrip untuk membuat ulang database.
Migration fitur bersifat tambahan terhadap tabel yang sudah ada.

| Tabel | ID / relasi | Kolom lain yang dikonfirmasi |
| --- | --- | --- |
| guru | `id uuid` = `auth.users.id` | nama, email, role, kelas_diampu (jsonb), avatar_url, no_hp, foto_url, created_at |
| kelas | `id integer`; `wali_kelas uuid nullable → guru.id` | nama_kelas, jam_masuk (wajib, default 07:00:00), jam_pulang (nullable), created_at |
| siswa | `id integer`; `kelas_id integer nullable → kelas.id` | nis (unik), nama, orang_tua_nama, orang_tua_nomor, status, created_at |
| absensi | `id integer`; `siswa_id integer nullable → siswa.id`; `updated_by uuid nullable → guru.id` | tanggal (date), status, waktu_masuk (time), waktu_pulang (time), keterangan, created_at, updated_at |
| surat | `id integer`; `siswa_id integer nullable → siswa.id` | tanggal (date), tanggal_selesai (date nullable), jenis, file_url, status, keterangan, catatan_guru, created_at |

Presensi: `hadir, izin, sakit, alfa, terlambat, pulang`.
Status siswa yang diizinkan check constraint: `aktif, lulus, pindah, keluar`.
Jenis surat: `izin` dan `sakit`, sesuai UI dan workflow yang sudah ada.

Model tidak menulis kolom fiktif seperti guru.nip/status/updated_at,
kelas.tingkat/jumlah_siswa/wali_kelas_id/updated_at,
siswa.email/no_hp/alamat/updated_at, atau surat.tipe/alasan/updated_at.
Jumlah siswa merupakan hasil query agregat, bukan kolom tulis kelas.
Properti domain `Surat.tipe` diserialisasi sebagai `jenis`.
Properti domain `Siswa.kelasId` tetap string untuk kompatibilitas pemakai, namun JSON tulis memakai integer.

Metadata review `surat.reviewed_by/reviewed_at` dan tabel `absensi_audit` ditambahkan migration 001.
Tabel tautan akun orang tua ditambahkan migration 002; ia belum ada dalam schema awal.
Tabel batch/job penghapusan ditambahkan migration 003.

Tes kontrak ada di `test/unit/schema_contract_test.dart` dan
`test/unit/schema_repository_test.dart`. Fixture SQL pengamanan mencakup relasi akun dan
kebijakan akses, tanpa mengakses database produksi.
