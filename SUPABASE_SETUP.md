# Supabase untuk Absen OSIS

Data di Supabase akan dimulai kosong. Semua tabel diatur agar pengunjung tanpa login dapat membaca, menambah, mengubah, dan menghapus data, sesuai model akses yang dipilih.

## Penyiapan

1. Buat proyek Supabase baru.
2. Di **SQL Editor**, jalankan seluruh isi [`supabase/setup.sql`](supabase/setup.sql).
   Untuk proyek yang sudah memakai setup lama, jalankan [`supabase/enable_realtime.sql`](supabase/enable_realtime.sql) sekali.
3. Di **Project Settings → API Keys** atau dialog **Connect**, salin Project URL dan publishable key ke [`supabase-config.js`](supabase-config.js).
4. Pastikan `public` tersedia di **Integrations → Data API → Exposed schemas**.
5. Deploy ulang situs GitHub Pages.

Publishable key memang digunakan di frontend. Jangan menaruh service-role key atau secret key di `supabase-config.js`; key tersebut melewati RLS.

Karena kebijakan database terbuka untuk role `anon`, setiap orang di internet dapat membaca dan mengubah data, termasuk nomor HP dan absensi. Jangan gunakan model ini untuk informasi yang tidak boleh disebarluaskan.

Setelah Realtime aktif, perubahan anggota, absensi, dan pengaturan akan disinkronkan langsung antar browser. Jika koneksi Realtime terputus, halaman menampilkan pesan status; data tetap dapat dimuat ulang lewat refresh browser. Backup JSON dan restore memakai RPC transaksional agar restore yang gagal tidak meninggalkan data setengah terganti.
