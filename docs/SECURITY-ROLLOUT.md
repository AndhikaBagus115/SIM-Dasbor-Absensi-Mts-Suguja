# Aktivasi pengamanan A1–A8

Kode dan SQL di repositori ini belum diterapkan ke Supabase produksi oleh sesi pengerjaan ini.
Jangan menjalankan seluruh migration ke produksi sebelum prasyarat aplikasi orang tua dipenuhi.

## Kondisi yang dikonfirmasi

- Admin: Supabase Auth; ID guru adalah UUID yang sama dengan ID Auth. Role dipercaya dari
  `public.guru.role = 'admin'`, bukan user metadata.
- Orang tua saat ini hanya mencari siswa berdasarkan NIS, tanpa sesi Supabase Auth.
  NIS bukan bukti kepemilikan akun. Policy RLS tidak dapat membedakan orang tua sah dari
  pengunjung lain yang mengetahui NIS.
- Policy yang dikirim pengguna membuka baca data siswa/presensi/surat ke anonim, mengizinkan
  perubahan surat publik, serta memberi semua akun terautentikasi hak tulis guru melalui
  `guru_all`. Karena itu pemeriksaan role memerlukan penguncian sumber role di database.
- Enum presensi aktual: `hadir, izin, sakit, alfa, terlambat, pulang`.
  Kelas memakai `wali_kelas uuid`, bukan `wali_kelas_id integer`.

## Tahap 1: role dan layanan notifikasi

1. Simpan backup database/policy dan uji langkah yang sama di proyek staging.
2. Pastikan migration `202611220001_attendance_workflows.sql` sudah terpasang.
   Pastikan pengelola mempunyai baris guru dengan ID Auth yang benar dan role admin.
3. Jalankan [lock_guru_roles.sql](../supabase/preflight/lock_guru_roles.sql) sebagai pengelola
   database. Skrip ini dapat dijalankan ulang. Ia mengganti policy tulis guru dan menolak
   perubahan role/penugasan oleh guru biasa. Ia mempertahankan jalur baca NIS yang ada.
   **Akses anonim tabel lain masih terbuka pada tahap ini; A2 belum selesai di produksi.**
4. Periksa akun yang sudah ber-role admin melalui SQL Editor. Role yang sebelumnya dapat
   diubah pengguna tidak otomatis menjadi terpercaya hanya karena policy sudah diganti.
   Verifikasi daftar admin dengan pengelola sebelum mengaktifkan endpoint baru.
5. Rotasi kunci OneSignal dan WAHA yang pernah berada di asset/riwayat Git melalui dashboard
   penyedianya. Perbarui konsumen server lain yang memakai kunci tersebut, termasuk webhook
   notifikasi presensi bila ada. Kunci lama tetap berisiko meski build baru sudah bersih.
   Pasang TLS/reverse proxy untuk WAHA dan gunakan URL HTTPS; endpoint baru menolak koneksi
   HTTP agar API key tidak dikirim sebagai plaintext melalui jaringan.
6. Salin `supabase/functions/.env.example` ke file konfigurasi server privat, isi kunci BARU,
   lalu pasang sebagai secrets Edge Functions. Jangan menyalinnya ke `assets` atau
   `--dart-define`. Supabase memasok URL/key proyek dan service role untuk runtime server.

   ```powershell
   supabase secrets set --env-file supabase/functions/.env
   supabase functions deploy admin-notifications
   ```

   Endpoint memverifikasi JWT melalui Auth dan membaca role guru di server untuk setiap
   request. Target siswa/kelas dan nomor orang tua diambil ulang dari database.
   Diagnostik hanya mengembalikan kesiapan konfigurasi; uji koneksi OneSignal memakai GET.
   Aksi tes kirim memang mengirim pesan ketika dipilih admin.
7. Untuk Flutter, file `.env` lokal hanya menjadi INPUT generator konfigurasi publik:

   ```powershell
   python tools/prepare_public_config.py
   flutter pub get
   flutter build web
   python tools/check_web_bundle.py
   ```

   Hasil `assets/public_config.json` hanya memuat `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   dan `APP_ENVIRONMENT`. File hasil diabaikan Git. `.env` tidak menjadi asset lagi.
   Alternatifnya gunakan dua dart-define publik Supabase tanpa file runtime.
   Gunakan publishable key atau JWT role anon; service role dan key penyedia tetap privat.
8. Distribusikan build baru dan ganti seluruh artifact Web lama, termasuk cache/CDN/service
   worker. Penghapusan asset baru tidak menghapus salinan lama milik pengguna; rotasi tetap wajib.

## Tahap 2: identitas orang tua dan policy penuh

Pekerjaan pada aplikasi pendamping berada di repositori lain. Sebelum mengaktifkan migration 002:

1. Ganti login NIS dengan Supabase Auth yang membuktikan identitas orang tua, misalnya OTP pada
   kontak yang sudah diverifikasi pengelola. NIS boleh dipakai untuk pencarian awal.
   Jangan menyediakan endpoint publik yang menerbitkan sesi/menautkan anak hanya dengan NIS.
2. Admin/pengelola menautkan ID Auth orang tua ke ID siswa melalui tabel baru
   `orang_tua_siswa(user_id, siswa_id)`. Klien orang tua tidak dapat membuat tautan sendiri.
   Siapkan daftar tautan terverifikasi untuk dipasang pada jendela migrasi; jangan menebak
   tautan dari metadata, NIS yang dimasukkan pengguna, atau nomor telepon yang belum diverifikasi.
3. Ubah unggahan surat menjadi path unik `<auth.uid()>/<UUID-acak>.<ext>` dalam bucket
   `surat_keterangan`. Jangan menggunakan ulang path lampiran yang sudah dihapus.
   Simpan URL canonical dari Supabase di `surat.file_url`.
4. Surat menjadi bucket private. Aplikasi orang tua harus memakai signed URL sementara untuk
   membaca lampirannya. Admin panel sudah membuat signed URL saat preview, download, dan backup.
   File lama dengan path tanpa prefix akun harus dipindahkan/disalin melalui proses pengelola
   ke prefix pemilik yang terverifikasi dan URL row diperbarui. Jangan menghapus file lama
   sebelum migrasi row berhasil. Jangan membuka bucket kembali untuk mengatasi error izin.
5. Pada maintenance window setelah pembaruan aplikasi siap, jalankan migration
   [002_admin_access](../supabase/migrations/202611220002_admin_access.sql), lalu pasang tautan
   orang tua yang sudah diverifikasi. Buat/isi tabel tautan lebih awal di staging bila diperlukan.
   Akun tanpa tautan hanya mendapatkan hasil kosong.
6. Uji sebagai admin, guru, orang tua dengan dua anak, orang tua lain, akun tanpa tautan, dan
   anonim. Verifikasi scan guru, baca anak sendiri, unggah surat, lampiran private, dan pengumuman
   per kelas. Guru mempertahankan baca direktori sekolah dan input presensi hari ini (Asia/Jakarta);
   identitas record tidak dapat dipindahkan dan actor input ditetapkan dari sesi.
   Koreksi tanggal lampau/mendatang, perubahan master data,
   penghapusan, serta approval surat dikelola admin. Approval langsung dari aplikasi lama perlu
   dialihkan ke alur yang diizinkan; metadata review tidak dapat ditulis lewat update tabel biasa.
7. Migration mengganti seluruh policy pada enam tabel aplikasi dan policy Storage lama yang
   disebutkan pengguna. Jika muncul policy tambahan, tinjau sebelum penerapan: policy permisif
   digabung dengan OR. Inventarisasi view dan RPC lain yang tidak ada dalam repo.
   Lima RPC laporan yang dipakai panel diubah menjadi SECURITY INVOKER agar mengikuti RLS.
   Fungsi lain, webhook lama, Auth settings, serta bucket lain perlu diverifikasi pengelola.

## Tahap 3: antrean penghapusan surat

1. Jalankan [003_surat_deletion_queue](../supabase/migrations/202611220003_surat_deletion_queue.sql)
   setelah migration 001. Jalur UI hapus surat sudah memakai RPC antrean dan membutuhkan migration ini.
   Untuk hak akses tabel/Storage menyeluruh, aktifkan juga tahap 2.
2. Deploy worker:

   ```powershell
   supabase functions deploy cleanup-surat
   ```

3. `enqueue_surat_deletion` menerima batch ID dan paling banyak 20.000 ID yang dikonfirmasi.
   Ia menyimpan snapshot record, URL, actor, dan job pembersihan dalam transaksi yang sama
   dengan penghapusan row. Kegagalan transaksi mempertahankan record dan file.
4. Worker baru menghapus object setelah job tersedia. Ia memeriksa host/bucket/path, mempertahankan
   file yang masih dirujuk surat lain, memakai lease untuk pemulihan crash, dan menyimpan kegagalan
   dengan jeda retry. SQL dan Storage tetap dua operasi terpisah; tidak ada klaim transaksi lintas layanan.
5. Tombol **Bersihkan Lampiran** memproses antrean yang tersimpan, termasuk setelah halaman dimuat
   ulang. Satu invocation dibatasi 10 job atau sekitar 20 detik sebelum claim berikutnya; request
   Storage yang sedang berjalan mempunyai timeout sendiri. Jika masih ada antrean, jalankan lagi.
   Retry gagal ditunda minimal satu menit. URL asing/tidak valid tetap pending untuk ditinjau
   pengelola; jangan mengubah validasi worker agar menghapus host/bucket lain.
   Snapshot job dan audit hanya dapat dibaca admin. Tetapkan retensi snapshot sesuai kebutuhan sekolah.
6. Tanpa scheduler, antrean dilanjutkan oleh aksi admin tersebut. Otomasi berkala memerlukan pemanggil
   tepercaya yang dirancang tersendiri; jangan membuka endpoint worker menjadi anonim.

## Pengujian lokal

```powershell
flutter analyze --no-pub
flutter test --no-pub
node tools/test_attendance_workflows.mjs
node tools/test_admin_security.mjs
node --test tools/test_edge_functions.mjs
python tools/test_public_config.py
npx --yes deno@2.5.6 check supabase/functions/admin-notifications/index.ts supabase/functions/cleanup-surat/index.ts
flutter build web --no-pub
python tools/check_web_bundle.py
```

Pengujian SQL memakai PGlite 0.5.17 di `.dart_tool/sql_checks`; perintah instalasinya ada di README.
Seluruh fixture berjalan lokal; tidak ada notifikasi atau mutasi produksi dalam tes tersebut.
Mode `node tools/test_admin_security.mjs --baseline` sengaja gagal untuk membuktikan policy lama
mengizinkan eskalasi role guru.

Acuan implementasi server: [Supabase getUser](https://supabase.com/docs/reference/javascript/auth-getuser),
[Auth pada Edge Functions](https://supabase.com/docs/guides/functions/auth-legacy-jwt), dan
[Create Message OneSignal](https://documentation.onesignal.com/reference/create-message).
