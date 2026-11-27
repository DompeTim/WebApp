# PRD: Dompetim

**Versi:** 1.2 (skema database & aturan bisnis sudah dimatangkan)
**Tagline:** Kas tim yang transparan
**Jenis produk:** Aplikasi web pengelolaan uang kas untuk tim kantor

---

## 1. Ringkasan

Dompetim adalah website sederhana untuk mencatat uang kas tim kantor. Pengelola (1 orang atau lebih) mencatat pemasukan (asal dana) dan pengeluaran (kepada siapa dan untuk apa), sedangkan seluruh anggota (kurang dari 30 orang) bisa membuka dan melihat data kapan saja tanpa bisa mengubahnya. Aplikasi dimulai fresh dari saldo Rp 0 (tanpa impor data lama) dengan tujuan transparansi dan menggantikan pencatatan manual di chat atau spreadsheet.

## 2. Tujuan dan Metrik Keberhasilan

**Tujuan**
1. Semua anggota bisa melihat saldo, riwayat transaksi, dan status iuran kapan saja.
2. Hanya pengelola yang dapat menambah, mengubah, atau menghapus data.
3. Setiap perubahan data tercatat dan dapat ditelusuri.
4. Biaya operasional nol (memakai tier gratis).

**Metrik**
- 100% transaksi tercatat di aplikasi (tidak ada lagi catatan di luar sistem).
- Anggota dapat melihat saldo terbaru dalam kurang dari 3 klik setelah login.
- Rekap bulanan dapat diekspor atau dicetak ke PDF dalam kurang dari 1 menit.
- 0 kejadian anggota non-pengelola berhasil mengubah data atau melihat email anggota lain.

## 3. Di Luar Cakupan (Non-Goals) Versi 1

- Pembayaran online / integrasi payment gateway (pembayaran iuran dicatat manual oleh pengelola).
- Pengingat iuran otomatis (email/WhatsApp), kandidat versi berikutnya.
- Banyak kelompok/organisasi dalam satu aplikasi (multi-tenant).
- Nominal iuran berbeda per anggota (v1: sama untuk semua).
- Aplikasi mobile native (v1: website responsif mobile-first).
- Anggaran/budgeting dan persetujuan pengeluaran.
- Banyak file bukti dalam satu transaksi (v1: maksimal 1 file bukti per transaksi; jika ada beberapa struk, dicatat sebagai transaksi terpisah).

## 4. Pengguna dan Peran

| Peran | Jumlah | Hak akses |
|---|---|---|
| **Pengelola (admin)** | 1 (bisa ditambah; disarankan ada admin cadangan) | Kelola penuh: transaksi, iuran, anggota (termasuk lihat email), kategori, pengaturan, upload bukti. Ikut ditagih iuran bulanan jika aktif. |
| **Anggota (member)** | < 30 | Hanya lihat (`view only`): saldo, transaksi, iuran, laporan, diagram, log aktivitas, daftar nama anggota (email anggota lain disembunyikan). |
| **Mantan anggota (nonaktif)** | - | Tidak boleh melihat data kas apa pun; melihat halaman pemberitahuan khusus bahwa akunnya sudah dinonaktifkan. |
| **Bukan anggota** | - | Tidak boleh melihat data kas apa pun, walau punya akun Google; melihat halaman akun belum terdaftar. |

## 5. User Stories

**Anggota**
- Sebagai anggota, saya ingin login dengan akun Google agar tidak perlu membuat password baru.
- Sebagai anggota, saya ingin melihat saldo kas saat ini, ringkasan bulan berjalan, dan ringkasan keseluruhan agar tahu kondisi keuangan tim.
- Sebagai anggota, saya ingin melihat daftar pemasukan (asal dana) dan pengeluaran (kepada siapa/vendor serta untuk apa) agar yakin uang dikelola dengan benar.
- Sebagai anggota, saya ingin melihat bukti/nota pengeluaran dan bukti transfer iuran agar bisa memverifikasi.
- Sebagai anggota, saya ingin melihat status iuran saya dan anggota lain (lunas/belum/terlambat) dengan nyaman dari HP.
- Sebagai anggota, saya ingin melihat grafik pemasukan vs pengeluaran serta diagram per kategori agar mudah dipahami.
- Sebagai anggota, saya ingin melihat riwayat perubahan data (nama pelaku & perubahan) agar yakin tidak ada manipulasi, tanpa email pribadi anggota tersebar ke sesama anggota.

**Pengelola**
- Sebagai pengelola, saya ingin mencatat pemasukan dengan keterangan asal dana dan pengeluaran dengan keterangan penerima/vendor, keperluan, kategori, serta foto nota.
- Sebagai pengelola, saya ingin membuat tagihan iuran bulanan untuk semua anggota aktif sekaligus maupun tagihan satuan untuk anggota baru.
- Sebagai pengelola, saya ingin menentukan mulai bulan berapa anggota baru mulai ditagih iuran.
- Sebagai pengelola, saya ingin menandai iuran lunas untuk 1 bulan, beberapa bulan sekaligus (pelunasan tunggakan maupun bayar di muka), atau banyak anggota sekaligus, beserta upload bukti transfer opsional.
- Sebagai pengelola, saya ingin menambah/mengedit/menonaktifkan anggota (dan melihat data lengkap termasuk emailnya), mengelola kategori, dan mengatur nominal iuran.
- Sebagai pengelola, saya ingin mengekspor rekap ke Excel serta meninjau tampilan cetak laporan di browser untuk disimpan/unduh sebagai PDF.

## 6. Kebutuhan Fungsional

### 6.1 Autentikasi dan Akses
| ID | Kebutuhan | Prioritas |
|---|---|---|
| F-01 | Login hanya dengan akun Google (Supabase Auth). | Wajib |
| F-02 | Hanya email yang terdaftar dan aktif (`is_active = true`) di tabel `members` yang dapat mengakses data kas (whitelist). | Wajib |
| F-03 | Pengguna yang login tetapi belum terdaftar melihat halaman **"Akun belum terdaftar, hubungi pengelola"**; mantan anggota yang sudah dinonaktifkan (`is_active = false`) melihat halaman informatif khusus (menyebut nama dan status nonaktif serta arahan menghubungi pengelola, tanpa membocorkan data kas apa pun). | Wajib |
| F-04 | Aturan view-only vs admin ditegakkan di database (Row Level Security & hak tabel), bukan hanya di tampilan. | Wajib |
| F-05 | Tombol/menu kelola disembunyikan untuk anggota biasa. | Wajib |
| F-06 | **Privasi email:** Alamat email anggota hanya dapat dilihat oleh admin. Anggota biasa hanya melihat nama lengkap di daftar anggota (`v_members`), papan iuran (`v_dues_board`), dan log aktivitas (`v_audit_log`); aturan ini ditegakkan di database (RLS + view). | Wajib |

### 6.2 Transaksi
| ID | Kebutuhan | Prioritas |
|---|---|---|
| F-10 | Admin menambah transaksi: tipe (`income`/`expense`), jumlah (> 0), tanggal (maksimal hari ini WIB; tanggal masa depan ditolak), **pihak (`counterparty`, wajib)** — untuk pemasukan = asal dana, untuk pengeluaran = kepada siapa/vendor — **keperluan (`purpose`, wajib)**, dan kategori. | Wajib |
| F-11 | Admin mengubah dan menghapus transaksi (konfirmasi sebelum hapus). Setiap operasi yang menyebabkan saldo kas menjadi negatif (`< 0`) ditolak oleh database. | Wajib |
| F-12 | Daftar transaksi dengan filter tipe, bulan, kategori, dan pencarian teks (pihak, keperluan, kategori). | Wajib |
| F-13 | Upload bukti/nota maksimal **1 file** per transaksi (JPG/PNG/WebP/PDF, maks 5 MB); jika ada beberapa struk, dicatat sebagai transaksi terpisah. Saat bukti diganti atau transaksi dihapus, file lama di Storage ikut dibersihkan agar tidak menjadi file yatim. | Wajib |
| F-14 | Kategori berasal dari **daftar resmi** (tabel `categories`), bukan teks bebas. Bawaan: Iuran (sistem), Saldo awal (sistem), Donasi, Konsumsi, Hadiah, Acara, Operasional, Lainnya. Admin bisa menambah/menonaktifkan kategori non-sistem. Kategori harus sesuai tipe transaksi dan tipe kategori tidak dapat diubah jika bertentangan dengan transaksi lama. | Wajib |
| F-15 | Aplikasi dimulai fresh dari saldo Rp 0. Jika sewaktu-waktu diperlukan, transaksi berkategori **Saldo awal** hanya boleh dicatat maksimal **1 kali** dan otomatis dikecualikan dari grafik tren pemasukan bulanan agar tidak mendistorsi perbandingan bulanan. | Wajib |
| F-16 | Transaksi hasil iuran (kategori `Iuran`) tidak bisa dibuat manual atau dihapus langsung (hanya lewat modul iuran). Saat diedit dari halaman Transaksi, hanya **catatan (`purpose`)** dan **bukti transfer (`receipt_path`)** yang boleh diubah; nominal, tipe, kategori, tanggal, dan pihak terkunci penuh. | Wajib |

### 6.3 Iuran Bulanan
| ID | Kebutuhan | Prioritas |
|---|---|---|
| F-20 | Admin mengatur nominal iuran bulanan (sama untuk semua anggota) dan tanggal jatuh tempo (tanggal 1–28). | Wajib |
| F-21 | Admin membuat tagihan iuran untuk satu bulan bagi semua anggota aktif, **termasuk admin**, yang memiliki `billing_start_period <= periode` (`generate_dues`). | Wajib |
| F-22 | Papan status iuran adaptif: di **desktop** tampil sebagai matriks anggota x bulan dalam satu tahun (termasuk penanda terlambat `is_overdue` dan ikon bukti bayar); di **HP (lebar 360 px)** tampil dengan layout mobile-first berbasis daftar/kartu per bulan (pemilih bulan, ringkasan lunas/belum, filter status, dan detail riwayat per anggota), bukan memaksakan tabel desktop. | Wajib |
| F-23 | Admin mencatat pelunasan iuran dengan 3 mode yang seluruhnya mendukung upload bukti transfer (opsional), catatan (opsional), dan tanggal bayar maksimal hari ini WIB: (a) **satuan (`pay_due`)**, (b) **multi-bulan per anggota (`pay_member_dues`)** untuk melunasi tunggakan sekaligus dan/atau bayar di muka beberapa bulan sekaligus (otomatis membuatkan tagihan bulan yang belum di-generate), dan (c) **bayar massal (`pay_dues_batch`)** untuk menandai beberapa tagihan sekaligus. Setiap bulan lunas otomatis menghasilkan tepat 1 transaksi pemasukan berkategori Iuran dengan keterangan `"Iuran YYYY-MM"`. | Wajib |
| F-24 | Admin dapat membatalkan status lunas (`unpay_due`): transaksi pemasukan terkait ikut terhapus. Fungsi mengembalikan `receipt_path` apabila file tidak dipakai transaksi lain agar frontend aman membersihkan Storage. Ditolak bila pembatalan membuat saldo kas minus. | Wajib |
| F-25 | Admin dapat membuat tagihan satuan untuk anggota tertentu (`create_due`, misal anggota masuk tengah bulan), menghapus 1 tagihan belum lunas (`delete_due`), serta menghapus semua tagihan belum lunas pada satu periode sekaligus (`delete_unpaid_dues_by_period`). Tagihan yang sudah lunas tidak bisa dihapus. | Wajib |
| F-26 | Tabel `dues` tidak dapat ditulis langsung dari aplikasi; semua perubahan lewat fungsi RPC F-21, F-23, F-24, F-25. | Wajib |
| F-27 | Pembuatan tagihan ditolak jika nominal iuran belum diatur (harus `> 0`). | Wajib |

### 6.4 Laporan
| ID | Kebutuhan | Prioritas |
|---|---|---|
| F-30 | **Dashboard:** menampilkan **Saldo Saat Ini**, **Ringkasan Bulan Berjalan** (pemasukan operasional, pengeluaran, selisih), **Ringkasan Sepanjang Masa** (total pemasukan, total pengeluaran), **Status Iuran Bulan Berjalan** (jumlah lunas, belum lunas, terlambat, serta status pribadi user), grafik ringkas bulanan, dan daftar transaksi terbaru. | Wajib |
| F-31 | **Rekap Bulanan & Kategori:** tabel rekap per bulan (pemasukan operasional, saldo awal bila ada, pengeluaran, selisih) dan rekap per kategori per bulan/periode. | Wajib |
| F-32 | **Grafik & Diagram:** grafik pemasukan vs pengeluaran per bulan (`v_monthly_summary`) serta diagram per kategori yang informatif dan mudah dipahami (donut/bar chart pengeluaran & pemasukan per kategori beserta persentase dan nominal Rupiah dari `v_category_summary`). | Wajib |
| F-33 | **Export Excel & Preview Cetak PDF:** ekspor ke Excel (`.xlsx` via `exceljs`) untuk rekap dan daftar transaksi sesuai filter aktif, serta halaman/tampilan preview cetak laporan di browser (`print-to-PDF`) sehingga user bisa memeriksa hasilnya dan langsung menekan tombol unduh/simpan PDF dari dialog cetak browser. | Wajib |

### 6.5 Transparansi
| ID | Kebutuhan | Prioritas |
|---|---|---|
| F-40 | Setiap `INSERT`/`UPDATE`/`DELETE` pada `transactions`, `dues`, `members`, `categories`, dan `settings` dicatat otomatis ke `audit_log` (nama pelaku, email pelaku internal, aksi, data lama/baru, waktu). | Wajib |
| F-41 | Halaman Log Aktivitas (`v_audit_log`) dapat dilihat semua anggota (read-only) dalam bahasa yang mudah dibaca, menampilkan nama pelaku (`actor_name`). Untuk anggota biasa (`member`), `actor_email` dan field `email` di dalam payload perubahan otomatis disembunyikan oleh database. | Wajib |
| F-42 | Log tidak dapat diubah atau dihapus dari aplikasi. | Wajib |

### 6.6 Manajemen Anggota
| ID | Kebutuhan | Prioritas |
|---|---|---|
| F-50 | Admin menambah anggota (nama lengkap + email Google + role + **bulan mulai ditagih `billing_start_period`**) dan dapat melihat data lengkap termasuk email di halaman Anggota. | Wajib |
| F-51 | Admin mengubah data anggota (termasuk `billing_start_period`) dan menonaktifkan anggota tanpa menghapus riwayatnya. | Wajib |
| F-52 | Pengelola aktif terakhir tidak dapat dihapus, dinonaktifkan, diturunkan role-nya, atau diganti emailnya (dijaga di database). | Wajib |
| F-53 | Anggota yang sudah punya riwayat iuran tidak bisa dihapus; cukup dinonaktifkan. | Wajib |

## 7. Kebutuhan Non-Fungsional

- **Keamanan & Privasi:** RLS aktif di semua tabel; `service_role` key tidak pernah dipakai di frontend; bucket bukti bersifat privat dan diakses lewat signed URL; email anggota disembunyikan di database dari role `member`.
- **Zona Waktu:** Seluruh perhitungan tanggal default ("hari ini"), batas maksimal tanggal transaksi/pembayaran, penanda `is_overdue`, dan bulan berjalan memakai zona waktu **WIB (`Asia/Jakarta`)**.
- **Performa:** halaman utama termuat `< 2` detik untuk data sampai ribuan transaksi.
- **Responsif (Mobile-First):** nyaman dipakai di HP (lebar 360 px), termasuk tampilan khusus papan iuran dan form di layar kecil tanpa memaksakan layout desktop.
- **Bahasa & Format:** antarmuka Bahasa Indonesia; format mata uang Rupiah (`Rp 1.250.000`); format tanggal Indonesia.
- **Biaya:** hanya tier gratis (Vercel + Supabase).
- **Ketersediaan:** proyek Supabase tier gratis dapat dijeda jika lama tidak aktif; pengelola perlu mengaktifkannya kembali bila terjadi.

## 8. Arsitektur dan Teknologi

| Lapisan | Pilihan |
|---|---|
| Frontend | Next.js (App Router, TypeScript), Tailwind CSS, Recharts |
| Backend/DB | Supabase: Postgres, Auth (Google), Storage |
| Hosting | Vercel (tier gratis) |
| Export | `exceljs` (Excel `.xlsx`), browser print preview / `print-to-PDF` (PDF) |
| Skema | `dompetim_schema.sql` (gabungan) atau folder `migrations/` (`0001` sampai `0006`) + `seed_admin.sql`. Mencakup helper WIB, tabel, penjaga integritas & saldo, RLS + privasi email, log aktivitas, fungsi RPC, view laporan & bertopeng, storage. |

**Alur login:** Google OAuth lewat Supabase, lalu aplikasi memeriksa baris user di `members` (lewat policy yang mengizinkan user membaca baris emailnya sendiri):
- Tidak ditemukan -> tampilkan halaman **Akun Belum Terdaftar**.
- Ditemukan dengan `is_active = false` -> tampilkan halaman **Akun Nonaktif** (informatif, menyebut nama & arahan menghubungi pengelola, tanpa data kas).
- Ditemukan dengan `is_active = true` -> masuk ke Dashboard sesuai role (`admin` atau `member`).

## 9. Model Data (ringkasan)

- `members`: `email` (unik, huruf kecil & format email valid), `full_name`, `role` (`admin`/`member`), `is_active`, `billing_start_period` (tanggal 1 bulan mulai ditagih).
- `settings`: 1 baris; `org_name`, `monthly_due_amount`, `due_day` (1–28).
- `categories`: `code` (tetap untuk kategori sistem), `name` (unik tanpa peduli huruf besar/kecil & spasi), `type` (`income`/`expense`/`null` = keduanya), `is_system`, `is_active`.
- `transactions`: `type`, `amount`, `trx_date` (default hari ini WIB, maks hari ini WIB), `counterparty` (wajib untuk income & expense), `purpose` (wajib), `category_id`, `receipt_path` (maks 1 file), `created_by_id`, `created_by_name`.
- `dues`: `member_id`, `period` (tanggal 1), `amount`, `status`, `paid_at`, `transaction_id`; unik per `(member_id, period)`; lunas wajib punya `paid_at` dan `transaction_id`.
- `audit_log`: `table_name`, `record_id`, `action`, `old_data`, `new_data`, `actor_name`, `actor_email`, `created_at`.
- **Views (7):**
  - `v_balance` (saldo saat ini, saldo awal, total masuk/keluar, dan ringkasan bulan berjalan WIB; mengembalikan 0 baris untuk non-anggota)
  - `v_monthly_summary` (pemasukan operasional tanpa `saldo_awal`, `opening_balance`, pengeluaran, selisih)
  - `v_category_summary` (rekap per kategori & bulan)
  - `v_transactions` (daftar transaksi + `category_code`, `due_id`, `is_due`, `created_by_name`)
  - `v_members` (daftar anggota dengan `email = null` untuk non-admin)
  - `v_dues_board` (papan iuran tanpa email, dilengkapi `member_is_active`, `transaction_id`, `receipt_path`, `is_overdue` berbasis WIB)
  - `v_audit_log` (log aktivitas dengan `actor_name`; `actor_email` dan `email` di JSON disembunyikan dari non-admin)
- **RPC (8):** `generate_dues(p_period)`, `create_due(p_member_id, p_period)`, `pay_due(p_due_id, p_paid_at, p_receipt_path, p_note)`, `pay_member_dues(p_member_id, p_periods, p_paid_at, p_receipt_path, p_note)`, `pay_dues_batch(p_due_ids, p_paid_at, p_receipt_path, p_note)`, `unpay_due(p_due_id)`, `delete_due(p_due_id)`, `delete_unpaid_dues_by_period(p_period)`.

**Relasi utama**
- `dues.member_id` -> `members.id` (`on delete restrict`: anggota ber-riwayat tidak bisa dihapus)
- `dues.transaction_id` -> `transactions.id` (`on delete restrict` dan `unique`: satu transaksi hanya untuk satu tagihan iuran)
- `transactions.category_id` -> `categories.id` (`on delete restrict`: kategori terpakai tidak bisa dihapus)
- `transactions.created_by_id` -> `members.id` (`on delete set null`: nama pencatat tetap tersimpan di `created_by_name`)

## 10. Daftar Halaman

| Halaman | Isi | Akses |
|---|---|---|
| Login | Tombol "Masuk dengan Google" | Publik |
| Akun belum terdaftar | Informasi email belum terdaftar & tombol keluar | Login, bukan anggota |
| Akun nonaktif | Informasi khusus mantan anggota (nama, status nonaktif, kontak pengelola) & tombol keluar | Login, mantan anggota (`is_active = false`) |
| Dashboard | Saldo saat ini, ringkasan bulan berjalan, ringkasan sepanjang masa, status iuran bulan ini, grafik ringkas, transaksi terbaru | Semua anggota aktif |
| Transaksi | Daftar + filter + detail + preview bukti; tombol tambah/ubah/hapus (transaksi iuran hanya edit catatan & bukti) | Lihat: semua; kelola: admin |
| Iuran | Desktop: matriks anggota x bulan. Mobile: kartu/daftar per bulan & riwayat anggota. Aksi admin: buat tagihan bulanan/satuan, hapus tagihan unpaid, bayar satuan, bayar multi-bulan (tunggakan + di muka), bayar massal | Lihat: semua; kelola: admin |
| Laporan | Rekap bulanan, grafik pemasukan vs pengeluaran, diagram per kategori, export Excel (`.xlsx`), preview cetak PDF browser | Semua anggota aktif |
| Log Aktivitas | Riwayat perubahan yang mudah dibaca (nama pelaku tanpa email untuk non-admin) | Semua anggota aktif |
| Anggota | Daftar anggota (nama, role, status, mulai ditagih; kolom email & aksi tambah/ubah/nonaktifkan khusus admin) | Lihat nama: semua; kelola & lihat email: admin |
| Pengaturan | Tab **Umum** (nama organisasi, nominal iuran, tanggal jatuh tempo) dan tab **Kategori** (daftar, tambah, ubah, nonaktifkan kategori non-sistem) | Admin |

## 11. Aturan Bisnis

1. Saldo = total pemasukan - total pengeluaran, dan **tidak boleh minus (`>= 0`)**.
2. Tanggal transaksi dan tanggal bayar iuran **maksimal hari ini (WIB)**; transaksi masa depan ditolak.
3. `counterparty` wajib diisi pada pemasukan (asal dana) maupun pengeluaran (untuk siapa/vendor).
4. Satu transaksi maksimal memiliki 1 file bukti; banyak struk dicatat sebagai transaksi terpisah.
5. Transaksi berkategori `Saldo awal` hanya boleh dicatat maksimal **1 kali**, dan dikecualikan dari grafik tren pemasukan bulanan.
6. Iuran lunas selalu menghasilkan tepat satu transaksi pemasukan yang terhubung.
7. Satu anggota hanya punya satu tagihan per bulan (`member_id, period`).
8. Semua anggota aktif **termasuk admin** ikut ditagih iuran bulanan mulai dari `billing_start_period`.
9. Nominal tagihan "dibekukan" saat dibuat; perubahan nominal di pengaturan tidak mengubah tagihan lama.
10. Pembayaran multi-bulan untuk satu anggota (`pay_member_dues`) mendukung pelunasan tunggakan lama sekaligus dan/atau bayar di muka beberapa bulan ke depan (otomatis membuatkan tagihan bulan yang belum ada selama anggota aktif).
11. Anggota nonaktif tidak mendapat tagihan baru, tetapi riwayatnya tetap tersimpan.
12. Jumlah transaksi dan nominal iuran harus `> 0`.
13. Hapus data bersifat permanen, tetapi jejaknya tetap ada di log aktivitas dan file bukti lama dibersihkan dari Storage bila tidak dipakai transaksi lain.
14. Kategori transaksi harus aktif dan sesuai tipe; kategori sistem (`Iuran`, `Saldo awal`) tidak dapat dihapus, dinonaktifkan, atau diubah; tipe kategori non-sistem tidak boleh diubah jika bertentangan dengan transaksi lama.
15. Transaksi iuran hanya lahir dari fungsi RPC iuran dan hanya hilang lewat `unpay_due`. Pada transaksi iuran, hanya catatan (`purpose`) dan bukti transfer (`receipt_path`) yang boleh diedit.
16. Log aktivitas tidak mencatat perubahan kosong (update yang tidak mengubah isi data selain `updated_at`).
17. Privasi email: anggota non-admin tidak dapat mengakses email anggota lain baik di UI maupun langsung melalui API database.

## 12. Kriteria Penerimaan (Acceptance Criteria)

- [ ] Akun Google yang tidak terdaftar tidak dapat melihat data kas apa pun (termasuk `v_balance` mengembalikan 0 baris saat diuji lewat API langsung).
- [ ] Mantan anggota nonaktif melihat halaman khusus status nonaktif dan tetap ditolak oleh RLS saat mengakses data kas lewat API.
- [ ] Anggota biasa tidak dapat membaca email anggota lain melalui tabel `members`, `v_members`, `v_dues_board`, maupun `v_audit_log` lewat API langsung.
- [ ] Anggota biasa yang mencoba `INSERT`/`UPDATE`/`DELETE` langsung ke API atau memanggil RPC admin ditolak oleh database.
- [ ] Transaksi atau pembatalan yang membuat saldo kas `< 0` ditolak oleh database.
- [ ] Transaksi atau pembayaran iuran dengan tanggal lebih dari hari ini (WIB) ditolak oleh database.
- [ ] Pengeluaran tanpa `counterparty` atau transaksi `Saldo awal` kedua kali ditolak oleh database.
- [ ] Menandai iuran lunas (satuan, multi-bulan tunggakan + bayar di muka, maupun massal) membuat transaksi pemasukan yang sesuai; membatalkannya lewat `unpay_due` menghapus transaksi terkait dan mengembalikan path bukti hanya jika tidak dipakai transaksi lain.
- [ ] Mengedit nominal/tipe/kategori/tanggal/pihak transaksi iuran ditolak, tetapi mengubah catatan dan bukti transfer pada transaksi iuran berhasil.
- [ ] Setiap perubahan data muncul di Log Aktivitas dengan `actor_name` (dan `actor_email` tersembunyi untuk member).
- [ ] Bukti yang diupload dapat dilihat anggota aktif via signed URL dan tidak dapat diakses tanpa login; file lama dibersihkan saat diganti/dihapus.
- [ ] Export Excel (`.xlsx`) dan preview cetak PDF browser sesuai dengan data serta filter yang tampil di layar.
- [ ] Tampilan seluruh halaman (termasuk papan iuran) nyaman dan responsif di layar HP lebar 360 px.
- [ ] Pengelola aktif terakhir tidak bisa dihapus/dinonaktifkan/diturunkan/diganti emailnya.
- [ ] Tabel `dues` tidak bisa ditulis langsung dari API, hanya lewat fungsi RPC.
- [ ] Kategori tidak sesuai tipe atau sudah nonaktif ditolak.

## 13. Rencana Pengerjaan

| Fase | Isi |
|---|---|
| 1. Fondasi | Setup Next.js, Supabase, login Google, jalankan skema SQL v1.2, seed pengelola, halaman akun belum terdaftar & akun nonaktif |
| 2. Transaksi & Kategori | CRUD transaksi (validasi saldo non-negatif, tanggal WIB, counterparty wajib, proteksi edit transaksi iuran), filter, manajemen kategori di Pengaturan |
| 3. Iuran | Pengaturan nominal & jatuh tempo, tambah anggota dengan `billing_start_period`, buat tagihan bulanan/satuan, hapus tagihan unpaid, papan status adaptif (desktop matriks / mobile kartu), bayar satuan, bayar multi-bulan (tunggakan + di muka), bayar massal |
| 4. Laporan & Dashboard | Dashboard lengkap (saldo, bulan berjalan, sepanjang masa, status iuran), rekap bulanan, diagram kategori & grafik tren, export Excel (`exceljs`) & preview cetak PDF browser |
| 5. Bukti & Audit | Upload/ganti/hapus 1 bukti per transaksi + pembersihan Storage, halaman Log Aktivitas ramah baca tanpa bocor email |
| 6. Finishing | Uji responsif mobile 360 px, uji keamanan & privasi API dengan akun admin/member/nonaktif/bukan-anggota, deploy ke Vercel |

## 14. Risiko dan Mitigasi

| Risiko | Mitigasi |
|---|---|
| Hanya 1 pengelola (single point of failure) | Skema mendukung banyak admin; disarankan menambah minimal 1 admin cadangan sejak awal |
| Proyek Supabase tier gratis dijeda saat tidak aktif | Pantau berkala; aktifkan kembali dari dashboard bila perlu |
| Salah konfigurasi RLS membuka data atau email | Privasi email & akses data ditegakkan di RLS + view bertopeng; uji API langsung sebelum rilis |
| Salah input transaksi / iuran oleh pengelola | Fitur ubah/hapus + `unpay_due` + penjaga saldo non-negatif + log aktivitas sebagai jejak |
| Bukti berisi data pribadi | Bucket privat, maksimal 1 file per transaksi, signed URL, pembersihan file yatim |
| Pemilik proyek Supabase (akses SQL Editor) tetap bisa mengubah data apa pun termasuk log | Batasi akses dashboard Supabase ke 1–2 orang tepercaya; jangan klaim sistem kebal manipulasi bagi pemegang akses database |

## 15. Data Awal Sebelum Go-Live (Diisi Saat Setup)

- Nama tim / organisasi untuk ditampilkan di aplikasi (`settings.org_name`).
- Email Google admin pertama dan admin cadangan (bila ada).
- Nominal iuran bulanan awal (`settings.monthly_due_amount`) dan tanggal jatuh tempo (`settings.due_day`, antara tanggal 1–28).

---

## Lampiran: Cara Memakai Dokumen Ini di Project Workspace

1. Gunakan `Dompetim_PRD.md` dan `dompetim_schema.sql` (atau folder `migrations/` untuk pengembangan bertahap) sebagai acuan tunggal pengembangan.
2. Di Supabase: jalankan `dompetim_schema.sql`, edit dan jalankan `seed_admin.sql`, lalu aktifkan provider Google di Authentication.
3. Kerjakan bertahap mulai dari Fase 1 di bagian 13 hingga Fase 6.

## Catatan Perubahan v1.2 (terhadap v1.1)

- **Zona waktu WIB (`Asia/Jakarta`):** ditambah fungsi `today_wib()` untuk default `trx_date`, batas maksimal tanggal transaksi/pembayaran, `billing_start_period`, ringkasan bulan berjalan, dan penanda `is_overdue`.
- **Aturan Transaksi diperketat:** penjaga saldo kas tidak boleh minus (`guard_non_negative_balance`), tolak tanggal masa depan, `Saldo awal` maksimal 1 kali dan dikecualikan dari tren bulanan, `counterparty` wajib untuk pemasukan & pengeluaran, maksimal 1 file bukti per transaksi + pembersihan file yatim.
- **Edit transaksi iuran:** hanya catatan (`purpose`) dan bukti transfer (`receipt_path`) yang boleh diubah.
- **Modul Iuran diperkaya:** `members.billing_start_period` untuk mengatur bulan mulai ditagih anggota baru, `create_due`, `pay_member_dues` (pelunasan tunggakan + bayar di muka multi-bulan sekaligus), `pay_dues_batch` (bayar massal), `delete_unpaid_dues_by_period`, `unpay_due` mengembalikan `receipt_path` untuk cleanup, dan `v_dues_board` menyertakan `transaction_id`, `receipt_path`, serta `member_is_active`.
- **Privasi Email & Mantan Anggota:** email disembunyikan dari `member` di level database melalui RLS `members`/`audit_log` serta view `v_members`, `v_dues_board`, dan `v_audit_log`; `transactions` menyimpan `created_by_id` dan `created_by_name` alih-alih email; `v_balance` mengembalikan 0 baris untuk non-anggota; mantan anggota nonaktif mendapat halaman informasi khusus.
- **Integritas Kategori & View:** `guard_categories` mencegah promosi ke `is_system` atau perubahan tipe yang bertentangan dengan transaksi lama; `categories_name_uniq` memakai `lower(trim(name))`; `v_transactions` menyertakan `category_code` dan `due_id`.
- **Dashboard, Laporan & UX:** Dashboard menampilkan ringkasan bulan berjalan & sepanjang masa, Laporan menampilkan diagram per kategori (`v_category_summary`), Iuran memakai layout adaptif mobile-first di 360 px, export Excel memakai `exceljs`, dan PDF memakai preview cetak browser (`print-to-PDF`).
