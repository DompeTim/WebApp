# AGENTS.md — Panduan Pengembangan & Maintenance Dompetim

Dokumen ini menjadi pedoman utama bagi agen AI saat mengembangkan fitur lanjutan (Fase 2–6), melakukan bugfix, maupun maintenance jangka panjang pada repositori **Dompetim**.

## 1. Sumber Kebenaran Proyek

Selalu rujuk berkas berikut sebelum mengubah logika bisnis atau skema database:
- **Spesifikasi Produk & Aturan Bisnis:** `Docs/Dompetim_PRD.md` (v1.2)
- **Skema Database Gabungan (Idempotent):** `Docs/dompetim_schema.sql` (v1.2)
- **Migrasi Bernomor:** `Docs/migrations/0001_base.sql` s.d. `0006_storage.sql`
- **Seed Awal Admin:** `Docs/seed_admin.sql` dan `Docs/migrations/seed_admin.sql`

Jika terjadi perbedaan antara asumsi di kode dan `Docs/Dompetim_PRD.md` / `Docs/dompetim_schema.sql`, ikuti PRD & skema SQL v1.2 sebagai acuan resmi.

## 2. Arsitektur & Tech Stack

- **Frontend:** Next.js 15 (App Router), React 19, TypeScript (`strict: true`), Tailwind CSS v4, `lucide-react`
- **Backend / Database:** Supabase (Postgres, RLS, Triggers, RPC Functions, Views, Auth Google OAuth, Storage bucket privat `receipts`)
- **Visualisasi & Ekspor (Fase 4):** `recharts` (grafik tren & diagram kategori), `exceljs` (ekspor `.xlsx`), browser print preview / `print-to-PDF` (`.no-print` + `window.print()`)
- **Hosting:** Vercel (tier gratis) & Supabase (tier gratis)

## 3. Aturan Domain & Database (Wajib Dipatuhi)

1. **Zona Waktu WIB (`Asia/Jakarta`):**
   - Seluruh perhitungan tanggal "hari ini", bulan berjalan, batas maksimal tanggal transaksi/bayar, dan status terlambat wajib memakai zona waktu **WIB (`Asia/Jakarta`)**.
   - Di TypeScript, gunakan `todayWIB()` dan `currentMonthPeriodWIB()` di `src/lib/format.ts`. **Dilarang** memakai `new Date().toISOString().slice(0, 10)` karena menggunakan UTC.
   - Di SQL/Postgres, gunakan `public.today_wib()` (bukan `current_date`).

2. **Privasi Email Anggota (Database-Enforced):**
   - Anggota biasa (`role = 'member'`) **tidak boleh** melihat email anggota lain di UI maupun API.
   - Selalu query view bertopeng untuk tampilan umum: `v_members`, `v_dues_board`, `v_transactions`, `v_audit_log`.
   - Tabel mentah `members` hanya dibaca untuk cek status login diri sendiri (`src/lib/auth.ts`, `src/app/auth/callback/route.ts`) dan halaman pengelolaan khusus `admin`.

3. **Keamanan Supabase & RLS:**
   - **Dilarang keras** menggunakan atau menaruh `SUPABASE_SERVICE_ROLE_KEY` di frontend, client bundle, atau env publik.
   - **Dilarang** menulis langsung (`INSERT`/`UPDATE`/`DELETE`) ke tabel `dues` dan `audit_log` dari aplikasi. Semua mutasi iuran wajib lewat 8 RPC resmi: `generate_dues`, `create_due`, `pay_due`, `pay_member_dues`, `pay_dues_batch`, `unpay_due`, `delete_due`, dan `delete_unpaid_dues_by_period`.
   - Setiap rute/aksi khusus pengelola wajib dijaga di server (`await requireAdmin()` di `src/lib/auth.ts`) dan tetap mengandalkan RLS/trigger Postgres sebagai penegak akhir.

4. **Aturan Bisnis Kas & Transaksi:**
   - **Saldo non-negatif (`>= 0`):** Pengeluaran, edit, atau pembatalan (`unpay_due`) yang membuat saldo kas negatif ditolak oleh trigger `guard_non_negative_balance()`.
   - **Tanggal maksimal hari ini WIB:** Transaksi dan pembayaran iuran tidak boleh menggunakan tanggal masa depan.
   - **`counterparty` & `purpose` wajib diisi** baik untuk `income` (asal dana) maupun `expense` (kepada siapa/vendor + keperluan).
   - **Kategori `saldo_awal`:** Maksimal 1 kali sepanjang hidup aplikasi; dikecualikan dari metrik & grafik pemasukan operasional bulanan (`v_balance.month_income`, `v_monthly_summary.income`).
   - **Transaksi hasil iuran (`is_due = true`):** Tidak dapat dihapus langsung atau diubah nominal/tipe/kategori/tanggal/pihaknya. Hanya catatan (`purpose`) dan bukti (`receipt_path`) yang boleh diedit lewat modul Transaksi; perubahan status lunas wajib lewat `unpay_due()`.
   - **Admin ikut iuran:** Semua anggota aktif termasuk `admin` ditagih oleh `generate_dues` jika `billing_start_period <= period`.

5. **Storage Bukti/Nota (`receipts`):**
   - Bucket `receipts` bersifat **privat** (akses view/download lewat signed URL, maks 5 MB, format JPG/PNG/WebP/PDF).
   - Maksimal **1 file** per transaksi (`receipts/<tahun>/<uuid-file>.<ext>`).
   - Saat bukti diganti, transaksi dihapus, atau `unpay_due()` mengembalikan `receipt_path` non-null, aplikasi wajib menghapus file lama di Storage agar tidak menjadi file yatim (*orphan file*).

## 4. Konvensi Kode Next.js 15 & UI

- **Async Request APIs:** `cookies()`, `headers()`, `searchParams`, dan `params` di Next.js 15 wajib di-`await`.
- **Kompatibilitas Build Offline/Sandbox:** Jangan gunakan `next/font/google`; pertahankan stack font sistem di `src/app/globals.css` agar `npm run build` selalu berhasil tanpa akses jaringan saat build.
- **Performa Query:** Jalankan query independen secara paralel dengan `Promise.all(...)` untuk menghindari request waterfall. Gunakan query bertarget (hindari `select('*')` jika hanya butuh beberapa kolom pada tabel besar).
- **UI & Responsivitas:**
  - Seluruh teks antarmuka menggunakan **Bahasa Indonesia** yang jelas dan ringkas.
  - Format uang wajib lewat `formatRupiah()` dengan kelas Tailwind `tabular-nums`.
  - Desain wajib nyaman pada layar HP lebar **`360px`** tanpa scroll horizontal yang memaksa. Modul Iuran wajib tampil adaptif (matriks di desktop, kartu/daftar per bulan di mobile).
  - Untuk ekspor Excel gunakan `exceljs` (hindari `xlsx`/SheetJS lama); untuk PDF gunakan tampilan cetak browser (`.no-print` + `window.print()`).

## 5. Aturan Maintenance & Migrasi Database

- **Jangan ubah migrasi lama (`0001`–`0006`)** jika sudah dijalankan di database produksi/Supabase. Perubahan struktur, indeks, fungsi, atau view baru ditulis sebagai berkas migrasi baru berurutan (`Docs/migrations/0007_<nama>.sql`, dst.) yang bersifat idempotent.
- Setiap perubahan skema SQL wajib disinkronkan ke:
  1. `Docs/dompetim_schema.sql` (skema gabungan terbaru)
  2. `src/types/database.ts` (definisi TypeScript)
  3. `Docs/Dompetim_PRD.md` (bila mengubah aturan bisnis atau antarmuka)

## 6. Skill Workspace Terpasang (`.agents/skills/`)

Muat skill yang relevan sebelum mengerjakan tugas di area terkait:
- `supabase` & `supabase-postgres-best-practices`: wajib dibaca sebelum mengubah skema SQL, RLS, trigger, RPC, query Supabase, SSR auth, atau Storage.
- `vercel-react-best-practices` & `vercel-composition-patterns`: baca saat menulis atau merefaktor halaman/komponen Next.js App Router, Server/Client Components, serta data fetching.
- `antislop-design`, `frontend-design`, `web-design-guidelines`, & `dompetim-ui-antislop`: baca sebelum membuat atau mengaudit UI, form, tabel, grafik, halaman cetak, dan responsivitas `360px`.
- `deploy-to-vercel`: baca saat menyiapkan deployment atau konfigurasi environment ke Vercel (Fase 6).
- **Plugin Marketplace yang Disarankan:** Aktifkan plugin resmi **Supabase** dan **Vercel** di Antigravity untuk akses dokumentasi dan MCP server proyek saat pengembangan lanjutan.

## 7. Checklist Verifikasi Sebelum Selesai Tugas

1. Jalankan `npx tsc --noEmit` dan `npm run build` — keduanya wajib lulus tanpa error.
2. Pastikan fitur baru mematuhi batasan peran (`admin` vs `member` vs `inactive` vs `unregistered`).
3. Pastikan tidak ada kebocoran email anggota lain untuk role `member` dan tidak ada perubahan yang melanggar aturan saldo/WIB.
4. Uji tata letak pada viewport `360px` (mobile) dan desktop.
