# Supabase untuk Absen OSIS

Data di Supabase akan dimulai kosong. Semua tabel diatur agar pengunjung tanpa login dapat membaca, menambah, mengubah, dan menghapus data, sesuai model akses yang dipilih.

## Penyiapan

1. Buat proyek Supabase baru.
2. Di **SQL Editor**, jalankan seluruh isi [`supabase/setup.sql`](supabase/setup.sql).
3. Di **Project Settings → API Keys** atau dialog **Connect**, salin Project URL dan publishable key ke [`supabase-config.js`](supabase-config.js).
4. Pastikan `public` tersedia di **Integrations → Data API → Exposed schemas**.
5. Deploy ulang situs GitHub Pages.

Publishable key memang digunakan di frontend. Jangan menaruh service-role key atau secret key di `supabase-config.js`; key tersebut melewati RLS.

Karena kebijakan database terbuka untuk role `anon`, setiap orang di internet dapat membaca dan mengubah data, termasuk nomor HP dan absensi. Jangan gunakan model ini untuk informasi yang tidak boleh disebarluaskan.

Setelah konfigurasi terpasang, halaman memuat data bersama dari database. Muat ulang halaman browser untuk mengambil perubahan yang dibuat browser lain. Backup JSON dan restore memakai RPC transaksional agar restore yang gagal tidak meninggalkan data setengah terganti.
