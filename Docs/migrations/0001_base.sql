-- =====================================================================
-- DOMPETIM v1.2 | 0001_base.sql
-- Ekstensi, enum, helper zona waktu WIB, tabel, indeks, data referensi,
-- dan fungsi hak akses.
-- Aman dijalankan ulang (idempotent) pada database kosong atau yang sudah
-- berisi skema ini. Catatan: menjalankan ulang TIDAK mengubah struktur
-- tabel yang sudah ada; perubahan struktur ditulis sebagai migrasi baru.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------- ENUM ----------
do $$ begin create type public.member_role as enum ('admin', 'member');
exception when duplicate_object then null; end $$;

do $$ begin create type public.trx_type as enum ('income', 'expense');
exception when duplicate_object then null; end $$;

do $$ begin create type public.due_status as enum ('unpaid', 'paid');
exception when duplicate_object then null; end $$;

-- ---------- IDENTITAS & ZONA WAKTU ----------
-- Email user yang sedang login (dari JWT Supabase), huruf kecil.
create or replace function public.current_email()
returns text
language sql stable
as $$
  select lower(trim(coalesce(auth.jwt() ->> 'email', '')));
$$;

-- Tanggal hari ini menurut zona waktu kantor (WIB / Asia/Jakarta).
create or replace function public.today_wib()
returns date
language sql stable
as $$
  select (now() at time zone 'Asia/Jakarta')::date;
$$;

-- ---------- TABEL ----------
-- Anggota = whitelist login + penentu role
create table if not exists public.members (
  id                   uuid primary key default gen_random_uuid(),
  email                text not null unique,
  full_name            text not null check (length(trim(full_name)) > 0),
  role                 public.member_role not null default 'member',
  is_active            boolean not null default true,
  billing_start_period date not null default date_trunc('month', public.today_wib())::date
                         check (billing_start_period = date_trunc('month', billing_start_period)::date),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint members_email_valid check (
    email = lower(trim(email))
    and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  )
);

-- Pengaturan aplikasi (selalu 1 baris)
create table if not exists public.settings (
  id                  int primary key default 1,
  org_name            text not null default 'Dompetim' check (length(trim(org_name)) > 0),
  monthly_due_amount  numeric(14,2) not null default 0 check (monthly_due_amount >= 0),
  due_day             int not null default 10 check (due_day between 1 and 28),
  updated_at          timestamptz not null default now(),
  constraint settings_single_row check (id = 1)
);

-- Kategori transaksi (daftar resmi, tidak teks bebas)
--   code     : kode tetap untuk kategori sistem (dipakai oleh fungsi/view)
--   type     : null = bisa untuk pemasukan maupun pengeluaran
--   is_system: kategori bawaan yang tidak boleh dihapus/dinonaktifkan/diubah jenisnya
create table if not exists public.categories (
  id          uuid primary key default gen_random_uuid(),
  code        text unique,
  name        text not null check (length(trim(name)) > 0),
  type        public.trx_type,
  is_system   boolean not null default false,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
drop index if exists public.categories_name_uniq;
create unique index categories_name_uniq on public.categories (lower(trim(name)));

-- Transaksi kas
create table if not exists public.transactions (
  id              uuid primary key default gen_random_uuid(),
  type            public.trx_type not null,
  amount          numeric(14,2) not null check (amount > 0),
  trx_date        date not null default public.today_wib(),
  counterparty    text not null check (length(trim(counterparty)) > 0), -- masuk: asal dana | keluar: kepada siapa/vendor
  purpose         text not null check (length(trim(purpose)) > 0),      -- keterangan/keperluan transaksi
  category_id     uuid not null references public.categories(id) on delete restrict,
  receipt_path    text,                                                 -- maksimal 1 file bukti di bucket 'receipts'
  created_by_id   uuid references public.members(id) on delete set null,
  created_by_name text not null default 'Sistem',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists transactions_date_idx     on public.transactions (trx_date desc);
create index if not exists transactions_type_idx     on public.transactions (type);
create index if not exists transactions_category_idx on public.transactions (category_id);
create index if not exists transactions_receipt_idx  on public.transactions (receipt_path) where receipt_path is not null;

-- Iuran bulanan per anggota
create table if not exists public.dues (
  id              uuid primary key default gen_random_uuid(),
  member_id       uuid not null references public.members(id) on delete restrict,
  period          date not null check (period = date_trunc('month', period)::date), -- selalu tanggal 1
  amount          numeric(14,2) not null check (amount > 0),
  status          public.due_status not null default 'unpaid',
  paid_at         date,
  transaction_id  uuid unique references public.transactions(id) on delete restrict,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (member_id, period),
  -- lunas WAJIB punya tanggal bayar + transaksi; belum lunas WAJIB kosong keduanya
  constraint dues_paid_consistency check (
    (status = 'paid'   and paid_at is not null and transaction_id is not null) or
    (status = 'unpaid' and paid_at is null     and transaction_id is null)
  )
);
create index if not exists dues_period_idx on public.dues (period);

-- Log aktivitas
create table if not exists public.audit_log (
  id          bigint generated always as identity primary key,
  table_name  text not null,
  record_id   text,
  action      text not null check (action in ('INSERT','UPDATE','DELETE')),
  old_data    jsonb,
  new_data    jsonb,
  actor_name  text,
  actor_email text,
  created_at  timestamptz not null default now()
);
create index if not exists audit_log_created_idx on public.audit_log (created_at desc);
create index if not exists audit_log_table_idx   on public.audit_log (table_name, record_id);

-- ---------- FUNGSI HAK AKSES ----------
-- Anggota aktif (whitelist)?
create or replace function public.is_member()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.members m
    where m.email = public.current_email() and m.is_active
  );
$$;

-- Pengelola aktif?
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.members m
    where m.email = public.current_email() and m.is_active and m.role = 'admin'
  );
$$;

-- ---------- DATA REFERENSI ----------
insert into public.settings (id) values (1) on conflict do nothing;

insert into public.categories (code, name, type, is_system) values
  ('iuran',      'Iuran',       'income',  true),
  ('saldo_awal', 'Saldo awal',  'income',  true),
  (null,         'Donasi',      'income',  false),
  (null,         'Konsumsi',    'expense', false),
  (null,         'Hadiah',      'expense', false),
  (null,         'Acara',       'expense', false),
  (null,         'Operasional', 'expense', false),
  (null,         'Lainnya',     null,      false)
on conflict do nothing;
