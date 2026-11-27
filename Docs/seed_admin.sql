-- =====================================================================
-- DOMPETIM v1.2 | seed_admin.sql  (JALANKAN MANUAL, SEKALI SAJA)
-- Edit nilai di bawah, lalu jalankan di Supabase SQL Editor
-- (SQL Editor melewati RLS, jadi bisa dipakai sebelum ada admin).
-- Catatan:
--   - billing_start_period otomatis diisi bulan berjalan (WIB).
--   - Aplikasi dimulai fresh dari saldo Rp 0 (tanpa data awal).
--     Bila suatu saat perlu mencatat saldo awal, transaksi berkategori
--     'saldo_awal' hanya boleh dicatat maksimal 1 kali lewat aplikasi.
-- =====================================================================

insert into public.members (email, full_name, role)
values (lower(trim('GANTI_dengan_email_google_pengelola@gmail.com')), 'GANTI Nama Pengelola', 'admin')
on conflict (email) do nothing;

-- Nominal iuran bulanan (contoh Rp 50.000) dan tanggal jatuh tempo (1-28),
-- wajib > 0 sebelum membuat tagihan:
update public.settings
   set org_name = 'Dompetim',
       monthly_due_amount = 50000,
       due_day = 10
 where id = 1;
