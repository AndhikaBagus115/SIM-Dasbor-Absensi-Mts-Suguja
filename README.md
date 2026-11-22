# 💻 MTs School Admin Dashboard & Notification Portal (Flutter Web & Desktop)

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Backend](https://img.shields.io/badge/Backend-Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![OneSignal](https://img.shields.io/badge/Push-OneSignal%20REST-E51B24?style=for-the-badge&logo=onesignal&logoColor=white)
![Tests](https://img.shields.io/badge/Tests-Passed-brightgreen?style=for-the-badge&logo=flutter)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

> **Web & Desktop Admin Dashboard Portal** berbasis **Flutter** dan **Supabase** untuk Sistem Informasi Manajemen Sekolah MTs. Dilengkapi dengan **Sistem Notifikasi Mobile (OneSignal Push Notification REST API)**, pembuat **Kartu Presensi Siswa berbasis QR Code & Cetak PDF**, manajemen status kelulusan siswa, caching performa tinggi (*Stale-While-Revalidate*), verifikasi surat izin digital, serta ekspor laporan multi-format (Excel, CSV, & PDF).

---

## 📌 Tentang Aplikasi

Aplikasi ini bertindak sebagai pusat kendali administrasi sekolah (*Admin Central Hub*) yang mengintegrasikan pengelolaan master data siswa, guru, rombel kelas, rekapitulasi presensi harian secara *real-time*, hingga komunikasi langsung dengan orang tua/wali murid melalui kanal **Push Notification Mobile**.

Dirancang menggunakan prinsip **Clean & Modular Architecture** dengan pemisahan *Core Services*, *Models*, *Repositories*, *Logic/Controllers*, dan *Presentation Layer*, aplikasi ini mendukung pengoperasian penuh di antarmuka **Web Browser** maupun **Desktop (Windows/macOS/Linux)**.

Aplikasi ini terhubung langsung dengan ekosistem aplikasi mobile: **Mobile App Guru & Orang Tua (`UtsMobileLanjut` / `mts-school-mobile-app`)**.

---

## 🚀 Fitur-Fitur Utama

### 📊 1. Dashboard Interaktif & Statistik Real-Time
* **Statistik Kehadiran Harian**: Ringkasan persentase kehadiran, jumlah siswa hadir, terlambat, izin, sakit, dan alpa secara instan.
* **Grafik Visualisasi Presensi (`fl_chart`)**: Grafik tren kehadiran interaktif dengan kalkulasi dinamis batas sumbu Y dan interval otomatis.
* **Aktivitas & Log Cepat**: Pemantauan aktivitas presensi terbaru dan status operasional sistem.

### 🔔 2. Sistem Push Notification & Broadcast Pengumuman (OneSignal)
* **OneSignal Push Notification**: Integrasi REST API OneSignal untuk menyiarkan pengumuman langsung ke perangkat *smartphone* wali murid dan guru.
* **Pusat Simulasi & Pengujian Notifikasi**: Halaman simulasi notifikasi presensi, template pesan kehadiran, serta riwayat siaran (*broadcast*) pengumuman.
* **Segmentasi Pengiriman**: Mendukung broadcast ke *Semua Wali Murid*, *Per Rombel Kelas*, maupun *Per Siswa*.

### ⚡ 3. Master Data Caching (Stale-While-Revalidate)
* **MasterDataCacheService**: Mengurangi *latency* dan beban query database Supabase dengan strategi caching cerdas untuk data Kelas, Guru, dan Siswa.
* **Auto-Invalidation**: Cache otomatis diperbarui saat terjadi penambahan, pengeditan, atau penghapusan data master (*event-driven invalidation*).

### 🏷️ 4. Generator Kartu Siswa & QR Code Presensi (`barcode_widget`, `pdf`, `printing`)
* Pembuatan **QR Code unik** untuk setiap siswa (`SiswaModel`) yang dapat dipindai (*scan*) oleh guru menggunakan aplikasi mobile companion.
* **Export & Batch Print ke PDF**: Cetak kartu identitas siswa dalam format lembar dokumen PDF siap cetak dengan *loading progress indicator*.
* Mendukung unduhan individual maupun *bulk export* per kelas.

### 👨‍🎓 5. Manajemen Master Data Lengkap (Siswa, Guru, Kelas)
* **Siswa**: Pengelolaan biodata lengkap, NISN, kontak wali, dan status keanggotaan (*Aktif, Lulus, Alumni, Mutasi / Tidak Aktif*).
* **Guru**: Pendataan tenaga pendidik, NIP, mata pelajaran, dan penetapan wali kelas (`GuruModel`).
* **Kelas**: Manajemen rombel, kapasitas ruang, tingkat kelas, dan relasi wali kelas (`KelasModel`).
* **Pencarian Cepat & Debouncing**: Input pencarian responsif dengan utility `Debouncer`.

### ⏱️ 6. Rekapitulasi Presensi & Waktu Presensi Detail
* Pencatatan riwayat presensi harian dengan informasi **Waktu Masuk**, **Waktu Pulang**, status kehadiran, dan audit jejak pembaruan (`updated_by`).
* Filter fleksibel berdasarkan rentang tanggal, status kehadiran, dan rombel kelas.
* Penyesuaian presensi manual oleh admin dengan log perubahan.

### 📝 7. Manajemen Surat Perizinan & Sakit Digital
* Verifikasi dan persetujuan (*Approve / Reject*) surat perizinan yang diajukan oleh wali murid melalui aplikasi mobile.
* Pratinjau lampiran foto/dokumen surat keterangan dokter secara langsung di dasbor.
* Sinkronisasi otomatis status surat dengan rekapitulasi kehadiran harian siswa.

### 🔒 8. Autentikasi, Pemulihan Password & Profil Admin
* Sistem login aman berbasis Supabase Auth.
* **Alur Pemulihan Kata Sandi (*Password Recovery*)**: Pengiriman tautan reset kata sandi ke email admin dengan halaman pembaruan password terproteksi.
* **Manajemen Profil Admin**: Pembaruan nama lengkap, email, foto profil, dan kredensial keamanan.

### 📁 9. Ekspor Laporan Multi-Format
* **Excel (`.xlsx`) & CSV**: Ekspor data siswa, guru, rombel kelas, dan rekapitulasi presensi ke format spreadsheet (`excel`, `csv`).
* **Laporan PDF**: Pembuatan laporan cetak resmi dengan tata letak profesional.

---

## 🛠️ Stack Teknologi & Pustaka

| Komponen | Pustaka / Teknologi | Keterangan |
| :--- | :--- | :--- |
| **Framework Utama** | [Flutter 3.x](https://flutter.dev/) | Mendukung target Web & Desktop |
| **Bahasa Pemrograman** | [Dart 3.x](https://dart.dev/) | Null safety & Modern OOP |
| **Backend & Database** | Supabase Flutter (`supabase_flutter`) | PostgreSQL, Auth, Storage, Realtime |
| **Push Notification** | OneSignal REST API | Notifikasi broadcast ke mobile app |
| **State Management** | Provider Pattern (`provider`) | Arsitektur state terpusat & teruji |
| **Visualisasi Data** | `fl_chart` | Grafik statistik presensi interaktif |
| **Barcode & QR Code** | `barcode_widget`, `qr` | Generator kode presensi siswa |
| **Dokumen & Cetak** | `pdf`, `printing` | Rendering & printing dokumen PDF |
| **Ekspor Spreadsheet** | `excel`, `csv`, `archive` | Ekspor rekap data multi-format |
| **Manajemen Window** | `window_manager` | Pengaturan ukuran dan window desktop |
| **Konfigurasi Lingkungan**| `flutter_dotenv` | Manajemen variabel environment `.env` |
| **File Picker** | `file_picker`, `image_picker` | Unggah berkas dan lampiran |

---

## 📁 Struktur Direktori & Arsitektur

```text
lib/
├── main.dart                               # Inisialisasi Environment, Supabase, dan Window Manager
└── web_admin/
    ├── core/                               # Komponen Inti & Konfigurasi Global
    │   ├── constants.dart                  # Nama Tabel Supabase, Enums, StatusColors, Role
    │   ├── exceptions.dart                 # Custom AppException, RepositoryException
    │   ├── theme.dart                      # Skema Warna & Tema Material 3
    │   ├── services/                       # Core Services Layer
    │   │   ├── error_handler_service.dart  # Centralized Error Handling & Dialogs
    │   │   ├── logging_service.dart        # Logger & Logging Utilities
    │   │   ├── master_data_cache_service.dart # SWR Caching untuk Kelas, Guru, Siswa
    │   │   ├── notification_service.dart   # Service Notifikasi & Broadcast
    │   │   └── onesignal_service.dart      # REST Client OneSignal Push Notification
    │   └── utils/
    │       └── debouncer.dart              # Search Input Debouncer Utility
    │
    ├── data/                               # Data Layer
    │   ├── models/                         # Type-Safe Data Models (fromJson, toJson, copyWith)
    │   │   ├── absensi_model.dart          # Presensi (Waktu Masuk, Waktu Pulang, updated_by)
    │   │   ├── guru_model.dart             # Data Guru & Penugasan Wali Kelas
    │   │   ├── kelas_model.dart            # Rombel Kelas & Kapasitas
    │   │   ├── pengumuman_model.dart       # Model Broadcast & Riwayat Pengumuman
    │   │   ├── siswa_model.dart            # Data Siswa, NISN, Kontak Wali & Status
    │   │   └── surat_model.dart            # Surat Perizinan / Sakit Siswa
    │   └── repositories/                   # Supabase Data Repositories & Cache Invalidation
    │       ├── absensi_repository.dart
    │       ├── guru_repository.dart
    │       ├── kelas_repository.dart
    │       ├── siswa_repository.dart
    │       └── surat_repository.dart
    │
    ├── logic/                              # Business Logic & Controllers
    │   ├── absensi_controller.dart
    │   ├── kelas_logic.dart
    │   └── siswa_logic.dart
    │
    └── presentation/                       # Presentation Layer (UI)
        ├── pages/                          # Halaman Utama Dashboard
        │   ├── absensi_page.dart           # Rekapitulasi & Filter Presensi
        │   ├── dashboard_page.dart         # Statistik & Grafik Dashboard
        │   ├── guru_page.dart              # Manajemen Guru
        │   ├── kelas_page.dart             # Manajemen Rombel Kelas
        │   ├── notifikasi_test_page.dart   # Pengujian Notifikasi & Broadcast
        │   ├── password_recovery_screen.dart # Form Pemulihan Kata Sandi
        │   ├── profil_admin_page.dart      # Manajemen Profil Admin
        │   ├── siswa_page.dart             # Manajemen Siswa & QR Code Generator
        │   └── surat_page.dart             # Verifikasi Surat Izin / Sakit
        └── widgets/                        # Modular Reusable Sub-Widgets
            ├── dashboard/
            │   └── dashboard_widgets.dart  # Stat Cards, Chart Components
            └── notifikasi/
                ├── gateway_diagnostics_card.dart # Diagnostik Status Server Gateway
                ├── notifikasi_dialogs.dart       # Dialog Pratinjau Template & Target Badge
                ├── pengumuman_form_card.dart     # Form Broadcast Pengumuman
                ├── presensi_simulation_card.dart # Simulasi Alert Presensi
                └── riwayat_pengumuman_card.dart  # Kartu Riwayat Pesan Notifikasi
```

---

## ⚙️ Panduan Instalasi & Menjalankan Aplikasi

### 1. Prasyarat Sistem
* [Flutter SDK](https://flutter.dev/docs/get-started/install) versi 3.x atau lebih baru.
* [Dart SDK](https://dart.dev/get-dart) versi 3.x.
* Web Browser (Google Chrome / Edge) atau C++ Desktop Build Tools (untuk Windows Desktop).

### 2. Clone Repositori
```bash
git clone https://github.com/AndhikaBagus115/SIM-Dasbor-Absensi-Mts-Suguja.git
cd SIM-Dasbor-Absensi-Mts-Suguja
```

### 3. Konfigurasi Environment (`.env`)
Salin file `.env.example` menjadi `.env`:
```bash
cp .env.example .env
```
Sesuaikan konfigurasi pada file `.env`:
```env
# Supabase Configuration
SUPABASE_URL=https://your-project-url.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here

# OneSignal Push Notification Configuration
ONESIGNAL_APP_ID=your-onesignal-app-id-here
ONESIGNAL_REST_API_KEY=your-onesignal-rest-api-key-here

# App Configuration
APP_ENVIRONMENT=development
```

### 4. Unduh Dependensi
```bash
flutter pub get
```

### 5. Menjalankan Aplikasi
* **Jalankan di Web Browser (Chrome)**:
  ```bash
  flutter run -d chrome
  ```
* **Jalankan di Desktop Windows**:
  ```bash
  flutter run -d windows
  ```

---

## Aktivasi verifikasi surat dan koreksi presensi

Fitur persetujuan surat dan koreksi presensi memerlukan migration
[`202611220001_attendance_workflows.sql`](supabase/migrations/202611220001_attendance_workflows.sql).
Jalankan isi file tersebut melalui Supabase SQL Editor sebagai pengelola database sebelum memakai aksi baru.
Migration ini disiapkan dan diuji lokal; penerapannya ke Supabase produksi dilakukan terpisah.

Hak admin ditentukan dari `guru.id = auth.uid()` dan `guru.role = 'admin'`.
Pastikan akun admin mempunyai baris guru tersebut dan policy yang ada melindungi perubahan `guru.role`.
Endpoint baru memeriksa hak ini di server; identitas pengubah tidak diterima dari input klien.

Migration menambahkan:

- `review_surat`: memproses surat `menunggu` menjadi `disetujui` atau `ditolak`. Penolakan memerlukan alasan.
  Persetujuan mengisi status `izin`/`sakit` untuk seluruh rentang `tanggal` sampai `tanggal_selesai`.
  Presensi `hadir`, `terlambat`, atau `pulang` tidak ditimpa; admin harus meninjaunya dahulu.
  Pengulangan keputusan yang sama tidak membuat catatan audit ganda.
- `correct_absensi`: menyimpan koreksi, identitas admin, dan audit sebelum/sesudah dalam satu transaksi.
  Data yang telah berubah sejak dialog dibuka ditolak agar koreksi orang lain tidak tertimpa.
- `attendance_status_options`: mengambil pilihan status dari enum database yang sebenarnya, termasuk
  jika database memakai ejaan `alpa` alih-alih `alfa`.
- `absensi_audit`: riwayat yang dapat dibaca admin; klien tidak diberi hak menulis atau menghapus audit.
  Dialog menampilkan 100 perubahan terbaru untuk record yang dipilih.
- `surat.reviewed_by` dan `surat.reviewed_at`: identitas dan waktu verifikasi.

Trigger notifikasi yang dikirim bersama schema proyek dibatasi ke tanggal hari ini menurut Asia/Jakarta.
Handler dan argumen webhook tetap dipertahankan. Ini mencegah approval rentang tanggal mengirim notifikasi
presensi lampau/mendatang saat itu juga. Jika instalasi sudah memiliki kondisi `WHEN` khusus, migration
mempertahankannya untuk ditinjau pengelola. Dashboard semester menghitung data sampai hari ini.

## Ekspor laporan

Menu **Ekspor** pada halaman Siswa, Guru, Kelas, dan Presensi menyediakan Excel (`.xlsx`) dan CSV.
Ekspor siswa mengikuti kelas, status, dan pencarian; presensi mengikuti tanggal/bulan dan kelas.
Seluruh halaman data diambil hingga jumlah record terpenuhi. Laporan PDF harian juga mengambil seluruh
data sesuai filter, bukan hanya halaman tabel yang sedang terbuka.

NIS dan nomor telepon disimpan sebagai teks dalam XLSX. CSV memakai UTF-8 dengan BOM dan menetralkan
input yang bisa dibaca sebagai formula spreadsheet. Browser mengunduh file; desktop menyediakan dialog
penyimpanan. Pembatalan dialog tidak dilaporkan sebagai keberhasilan ekspor.

## 🧪 Pengujian (Testing)

Proyek ini dilengkapi dengan unit test dan widget test untuk memastikan integritas logika data, caching, dan komponen antarmuka.

Jalankan seluruh rangkaian pengujian dengan perintah:
```bash
flutter test
```

Rangkaian pengujian mencakup:
* `test/unit/master_data_cache_service_test.dart`: Validasi TTL, freshness, and invalidation lifecycle cache.
* `test/unit/models_test.dart`: Validasi serialisasi/deserialisasi JSON model data.
* `test/unit/notification_enums_test.dart`: Validasi enum kanal & tipe notifikasi.
* `test/widget/notifikasi_dialogs_test.dart`: Pengujian widget badge target notifikasi dan info card.
* `test/unit/pengumuman_controller_test.dart`: Race pemilihan kelas, pembaruan penerima saat kirim, kegagalan penyimpanan, dan pengiriman parsial.
* `test/unit/onesignal_result_test.dart`: Respons tanpa ID pesan dan target yang hanya sebagian diterima.
* `test/unit/report_export_test.dart`: CSV/XLSX, formula spreadsheet, filter, dan pagination ekspor.
* `test/widget/attendance_workflow_widgets_test.dart`: Validasi persetujuan/penolakan dan koreksi presensi.
* `test/widget/pengumuman_form_test.dart`: Tombol kirim menunggu penerima yang siap dan tidak kosong.

Transaksi dan otorisasi SQL dapat diuji pada PostgreSQL tertanam dengan fixture lokal, tanpa akses Supabase:

```bash
npm install --prefix .dart_tool/sql_checks --no-save --no-package-lock --ignore-scripts --no-audit --no-fund @electric-sql/pglite@0.5.17
node tools/test_attendance_workflows.mjs
```

Dependency pengujian SQL disimpan di `.dart_tool` yang diabaikan Git. Pengujian mencakup rollback,
audit, konflik koreksi, keputusan idempotent, rentang surat, notifikasi tanggal mendatang, enum aktual,
serta penolakan akses guru dan anonim. Fixture webhook tidak melakukan request jaringan.

---

## 👥 Ekosistem & Aplikasi Terkait

Proyek ini dirancang untuk beroperasi secara berdampingan dengan:
* **Mobile App Guru & Orang Tua**: Aplikasi mobile Flutter untuk pencatatan presensi dengan pemindaian QR code dan pengajuan surat izin oleh orang tua.
* **OneSignal Service**: Layanan push notification untuk notifikasi real-time di aplikasi mobile.

---

## 👨‍💻 Penulis & Lisensi

Dikembangkan oleh **Andhika Bagus Satria** & Tim untuk Sistem Informasi Manajemen Sekolah MTs.

* **Lisensi**: Open-source di bawah lisensi [MIT License](LICENSE).
