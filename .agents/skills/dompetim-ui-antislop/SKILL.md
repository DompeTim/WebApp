---
name: dompetim-ui-antislop
description: >-
  Panduan UI khusus aplikasi kas tim Dompetim yang melengkapi antislop-design,
  frontend-design, dan web-design-guidelines. Muat saat membangun atau meninjau
  halaman, formulir, tabel, grafik, atau tampilan cetak Dompetim agar konsisten,
  bebas AI-slop, akurat secara keuangan, dan nyaman di layar HP 360px.
---

# Dompetim UI Anti-Slop Contract

Skill ini menetapkan standar visual dan interaksi khusus domain **Dompetim** agar antarmuka terasa seperti aplikasi kas tim kantor yang tenang, rapi, dan dapat dipercaya—bukan template generik AI.

## 1. Estetika & Palet Warna Kas Tim

- **Identitas visual:** Bersih, ringkas, berbasis data (*treasury-first*). Hindari gradasi ungu/pink/neon, kartu glassmorphism dekoratif, blob latar belakang, atau grid fitur 3-kolom seragam.
- **Palet semantik konsisten:**
  - Primer / Pemasukan / Lunas: `emerald` (`emerald-600`, `emerald-700`, `emerald-50`)
  - Netral / Permukaan / Struktur: `slate` (`slate-50` latar, `white` kartu dengan `border-slate-200`, `slate-900` teks utama)
  - Pengeluaran / Terlambat / Aksi Destruktif: `rose` (`rose-600`, `rose-700`, `rose-50`)
  - Belum Lunas / Peringatan: `amber` (`amber-600`, `amber-700`, `amber-50`)
- **Ikon:** Gunakan satu keluarga ikon SVG (`lucide-react`). Jangan pernah memakai emoji sebagai ikon fungsional pada tombol, menu, atau status.
- **Tombol & interaktivitas:** Hindari `hover:scale-*` yang membuat layout bergetar; gunakan transisi warna/border/bayangan yang halus. Pastikan seluruh tombol dan kontrol sentuh memiliki ukuran nyaman di layar sentuh (`min-h-[40px]` atau `min-h-[44px]` untuk aksi utama mobile).

## 2. Tipografi & Angka Keuangan

- **Nominal Rupiah wajib `tabular-nums`:** Setiap angka saldo, tabel transaksi, ringkasan, atau nominal iuran wajib memakai kelas `tabular-nums` dan helper `formatRupiah()` dari `src/lib/format.ts` agar kolom angka sejajar vertikal dan mudah dipindai.
- **Hierarki angka jelas:** Bedakan tegas antara angka utama (Saldo Saat Ini), angka ringkasan (Bulan Berjalan vs Sepanjang Masa), dan metadata sekunder (tanggal, kategori, nama pencatat).
- **Kontras:** Patuhi minimal kontras WCAG AA (`slate-900`/`slate-700` di atas putih, hindari teks abu-abu terlalu pudar seperti `slate-300` untuk informasi penting).

## 3. Aturan Mobile-First `360px` (Wajib)

- **Dilarang memaksakan tabel lebar desktop di layar HP.**
  - **Halaman Iuran:** Di desktop tampil sebagai matriks anggota × bulan; di layar `< md` (`360px`) wajib berubah menjadi tampilan kartu/daftar per bulan dengan pemilih bulan, filter status (`Semua`, `Lunas`, `Belum Lunas`, `Terlambat`), progres ringkas, dan drawer/modal detail riwayat per anggota.
  - **Halaman Transaksi:** Di desktop dapat memakai tabel terstruktur; di mobile tampilkan daftar kartu ringkas dengan tipe, keperluan, pihak, kategori, tanggal, ikon bukti, dan nominal di kanan.
- **Ruang aman bottom nav:** Halaman di dalam `(app)` harus memberi padding bawah cukup (`pb-24 md:pb-10`, sudah ditangani `AppShell`) agar tombol atau baris terakhir tidak tertutup navigasi bawah.

## 4. Kelengkapan State & Aksi Aman

Setiap halaman/modul interaktif wajib menyediakan:
1. **Empty state bermakna** (misal belum ada transaksi, belum ada tagihan bulan ini, hasil filter kosong + tombol reset filter).
2. **Loading & pending state** yang jelas pada tombol submit (`Menyimpan...`, `disabled` saat mutasi berlangsung agar tidak double-submit).
3. **Error state Bahasa Indonesia** yang menerjemahkan pesan error database (misal saldo tidak boleh minus, tanggal melebihi hari ini WIB, kategori tidak sesuai tipe) dengan bahasa ramah pengguna.
4. **Dialog konfirmasi eksplisit** sebelum aksi destruktif (hapus transaksi, batalkan lunas `unpay_due`, hapus tagihan `delete_due` / `delete_unpaid_dues_by_period`, nonaktifkan anggota/kategori).

## 5. Audit Checklist Sebelum Selesai (PASS/FAIL)

- [ ] Tidak ada warna ungu/indigo/neon, emoji ikon, atau `hover:scale-*`.
- [ ] Semua nominal memakai `formatRupiah()` + `tabular-nums`.
- [ ] Seluruh tampilan nyaman dan tidak mengalami horizontal overflow pada lebar `360px`.
- [ ] Tidak ada tombol atau kolom edit yang diekspos untuk role `member` (selain read-only).
- [ ] Tidak ada alamat email anggota lain yang ditampilkan ke role `member`.
- [ ] Tampilan cetak (`.no-print` untuk kontrol navigasi/tombol) bersih saat di-print/simpan PDF dari browser.
