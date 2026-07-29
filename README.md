# 💻 MTs School Admin Dashboard & WhatsApp Gateway (Flutter Web & Desktop)

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Backend](https://img.shields.io/badge/Backend-Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Integration](https://img.shields.io/badge/Integration-WhatsApp%20Gateway-25D366?style=for-the-badge&logo=whatsapp&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

> **Web & Desktop Admin Dashboard Portal** berbasis **Flutter** dan **Supabase** untuk Sistem Informasi Manajemen Sekolah MTs. Dilengkapi dengan **Integrasi WhatsApp Gateway Notification**, pembuat **QR Code / Barcode Kartu Siswa**, manajemen status kelulusan siswa, serta ekspor laporan multi-format (Excel, CSV, & PDF).

---

## 📌 Tentang Aplikasi

Aplikasi ini bertindak sebagai pusat kendali administrasi sekolah (*Admin Central Hub*) yang mengintegrasikan pengelolaan data siswa, guru, kelas, rekapitulasi presensi, hingga komunikasi langsung dengan orang tua/wali murid melalui pesan notifikasi otomatis **WhatsApp**.

Dirancang menggunakan prinsip **Clean Architecture** (Refactored Layer) dengan pemisahan *Models*, *Repositories*, dan *Provider State Management*, aplikasi ini mendukung pengoperasian di antarmuka **Web** maupun **Desktop (Windows/Mac/Linux)**.

Aplikasi ini berpasangan langsung dengan aplikasi client **Mobile App Guru & Orang Tua (`UtsMobileLanjut` / `mts-school-mobile-app`)**.

---

## 🚀 Fitur-Fitur Utama

### 📲 1. Integrasi WhatsApp Gateway Notification System
* Otomatis mengalirkan notifikasi pesan **WhatsApp** ke nomor HP orang tua/wali murid saat terjadi ketidakhadiran, absensi, maupun pengumuman sekolah.

### 🏷️ 2. Generator QR Code / Barcode Kartu Presensi Siswa (`barcode_widget`)
* Membuat dan mencetak QR Code / Barcode unik untuk setiap siswa (`SiswaModel`).
* Barcode yang dicetak dapat langsung dipindai (*scan*) oleh guru menggunakan aplikasi mobile companion.

### 👨‍🎓 3. Manajemen Keanggotaan & Status Kelulusan Siswa
* Manajemen status siswa terstruktur (*Aktif, Lulus, Alumni, Tidak Aktif*).
* Pendataan guru/tenaga pengajar (`GuruModel`) dan pemetaan rombel kelas (`KelasModel`).

### 📝 4. Rekapitulasi Presensi & Surat Perizinan
* Tracking riwayat presensi harian siswa (`AbsensiModel`).
* Manajemen dan verifikasi surat perizinan/sakit dari orang tua (`SuratModel`).

### 📊 5. Ekspor Laporan Multi-Format & Analytics
* **Export Excel (`.xlsx`) & CSV**: Unduh data rekapitulasi siswa dan presensi ke spreadsheet (`excel`, `csv`).
* **Cetak PDF & Printing (`pdf`, `printing`)**: Cetak dokumen resmi dan laporan presensi.
* **Grafik Visualisasi Data (`fl_chart`)**: Dashboard statistik kehadiran dan performa sekolah.

---

## 🛠️ Stack Teknologi & Arsitektur

| Komponen | Pustaka / Teknologi |
| :--- | :--- |
| **Framework Utama** | [Flutter 3.x](https://flutter.dev/) (Web & Desktop) |
| **Bahasa Pemrograman** | Dart 3.x |
| **Backend & Auth** | Supabase Flutter (`supabase_flutter`) |
| **Integrasi Notifikasi** | WhatsApp API Gateway (`http`) |
| **Pustaka Barcode/PDF** | `barcode_widget`, `pdf`, `printing`, `screenshot` |
| **Pustaka Ekspor Data** | `excel`, `csv`, `archive` |
| **State Management** | Provider Pattern (`provider`) |
| **Desktop Management** | Window Manager (`window_manager`) |

---

## 📁 Arsitektur Kode (Clean Architecture)

```text
lib/
├── web_admin/
│   ├── core/
│   │   ├── constants.dart        # DbTables, Column Names, Enums, StatusColors
│   │   └── exceptions.dart       # AppException, RepositoryException, ValidationException
│   └── data/
│       ├── models/               # Type-Safe Data Models
│       │   ├── siswa_model.dart  # Model Siswa (JSON Deserialization, copyWith, Equality)
│       │   ├── guru_model.dart   # Model Guru
│       │   ├── kelas_model.dart  # Model Kelas
│       │   ├── absensi_model.dart# Model Presensi
│       │   └── surat_model.dart  # Model Surat Izin/Sakit
│       └── repositories/         # Supabase Data Access Repositories
└── main.dart                     # Entrypoint Aplikasi & Initialization
```

---

## ⚙️ Panduan Build & Running Project

### 1. Clone Repositori
```bash
git clone https://github.com/AndhikaBagus115/mts-school-admin-dashboard.git
cd mts-school-admin-dashboard
```

### 2. Konfigurasi Environment (`.env`)
Salin file `.env.example` menjadi `.env`:
```bash
cp .env.example .env
```
Isi konfigurasi URL & API Key Supabase serta WhatsApp Gateway pada `.env`:
```env
SUPABASE_URL=https://your-supabase-url.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
WA_GATEWAY_URL=https://your-wa-gateway-api.com
```

### 3. Install Dependency
```bash
flutter pub get
```

### 4. Jalankan Server Web / Desktop
Untuk menjalankan di browser (Web):
```bash
flutter run -d chrome
```
Untuk menjalankan di Desktop Windows:
```bash
flutter run -d windows
```

---

## 👨‍💻 Penulis & Lisensi

Dikembangkan oleh **Andhika Bagus Satria** & Tim sebagai Web & Desktop Admin Dashboard Portal Sekolah.

* **Lisensi**: Open-source di bawah lisensi [MIT License](LICENSE).
