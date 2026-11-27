-- =====================================================================
-- DOMPETIM v1.2 - Skema Database LENGKAP (gabungan migrasi 0001-0006)
-- Jalankan seluruh file ini di Supabase > SQL Editor pada proyek baru.
-- Aman dijalankan ulang (idempotent) untuk skema yang sama.
-- Setelah itu jalankan seed_admin.sql (setelah diedit) untuk pengelola pertama.
-- Untuk pengembangan lanjutan, gunakan folder migrations/ (satu file per perubahan).
-- =====================================================================

-- ########## 0001_base.sql ##########
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

-- ########## 0002_triggers.sql ##########
-- =====================================================================
-- DOMPETIM v1.2 | 0002_triggers.sql
-- updated_at otomatis, normalisasi input, penjaga integritas data,
-- penjaga saldo non-negatif, dan log aktivitas.
-- =====================================================================

-- ---------- updated_at otomatis ----------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_members_updated      on public.members;
drop trigger if exists trg_settings_updated     on public.settings;
drop trigger if exists trg_categories_updated   on public.categories;
drop trigger if exists trg_transactions_updated on public.transactions;
drop trigger if exists trg_dues_updated         on public.dues;

create trigger trg_members_updated      before update on public.members
  for each row execute function public.set_updated_at();
create trigger trg_settings_updated     before update on public.settings
  for each row execute function public.set_updated_at();
create trigger trg_categories_updated   before update on public.categories
  for each row execute function public.set_updated_at();
create trigger trg_transactions_updated before update on public.transactions
  for each row execute function public.set_updated_at();
create trigger trg_dues_updated         before update on public.dues
  for each row execute function public.set_updated_at();

-- ---------- NORMALISASI: anggota ----------
create or replace function public.normalize_member()
returns trigger
language plpgsql
as $$
begin
  new.email     = lower(trim(new.email));
  new.full_name = trim(new.full_name);
  return new;
end;
$$;

drop trigger if exists trg_members_01_normalize on public.members;
create trigger trg_members_01_normalize before insert or update on public.members
  for each row execute function public.normalize_member();

-- ---------- PENJAGA: pengelola terakhir ----------
-- Menolak menghapus / menonaktifkan / menurunkan role / mengganti email
-- pengelola aktif TERAKHIR (agar tidak ada kondisi tanpa pengelola).
create or replace function public.guard_last_admin()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if old.role = 'admin' and old.is_active then
    if tg_op = 'DELETE'
       or new.role <> 'admin'
       or not new.is_active
       or new.email <> old.email then
      if not exists (
        select 1 from public.members
        where id <> old.id and role = 'admin' and is_active
      ) then
        raise exception 'Pengelola aktif terakhir tidak boleh dihapus, dinonaktifkan, diturunkan role-nya, atau diganti emailnya. Tambahkan pengelola lain terlebih dahulu.'
          using errcode = 'P0001';
      end if;
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists trg_members_guard    on public.members;
drop trigger if exists trg_members_02_guard on public.members;
create trigger trg_members_02_guard before update or delete on public.members
  for each row execute function public.guard_last_admin();

-- ---------- PENJAGA: kategori ----------
-- 1) Kategori sistem tidak dapat dihapus, dinonaktifkan, atau diubah identitas/jenisnya.
-- 2) Kategori non-sistem tidak dapat dinaikkan menjadi kategori sistem.
-- 3) Tipe kategori non-sistem tidak boleh diubah jika sudah bertentangan dengan transaksi yang ada.
create or replace function public.guard_categories()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'Kategori bawaan sistem tidak boleh dihapus.'
        using errcode = 'P0001';
    end if;
    return old;
  end if;

  new.name = trim(new.name);

  if tg_op = 'UPDATE' then
    if old.is_system then
      if new.code      is distinct from old.code
         or new.name   is distinct from old.name
         or new.type   is distinct from old.type
         or new.is_system <> old.is_system
         or not new.is_active then
        raise exception 'Kategori bawaan sistem tidak boleh dinonaktifkan atau diubah jenis/namanya.'
          using errcode = 'P0001';
      end if;
    else
      if new.is_system or new.code is distinct from old.code then
        raise exception 'Kategori non-sistem tidak dapat diubah menjadi kategori sistem.'
          using errcode = 'P0001';
      end if;
      if new.type is distinct from old.type and new.type is not null then
        if exists (
          select 1 from public.transactions
          where category_id = old.id and type <> new.type
        ) then
          raise exception 'Tipe kategori tidak dapat diubah karena sudah digunakan transaksi dengan tipe berbeda.'
            using errcode = 'P0001';
        end if;
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_categories_guard on public.categories;
create trigger trg_categories_guard before insert or update or delete on public.categories
  for each row execute function public.guard_categories();

-- ---------- PENJAGA: transaksi ----------
-- 1) Tanggal transaksi maksimal hari ini (WIB), tidak boleh tanggal masa depan.
-- 2) Kategori harus aktif & sesuai tipe.
-- 3) Kategori 'iuran' hanya boleh dibuat lewat fungsi RPC modul iuran.
-- 4) Kategori 'saldo_awal' hanya boleh dicatat 1 kali.
-- 5) created_by_id & created_by_name diisi otomatis dari sesi login dan tidak bisa diubah.
-- 6) Transaksi hasil iuran: hanya catatan (purpose) dan bukti (receipt_path) yang boleh diubah;
--    tidak boleh dihapus langsung (gunakan unpay_due()).
create or replace function public.guard_transactions()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  v_cat        public.categories%rowtype;
  v_via_rpc    boolean := coalesce(current_setting('dompetim.via_rpc', true), '') = '1';
  v_actor_id   uuid;
  v_actor_name text;
begin
  if tg_op = 'DELETE' then
    if exists (select 1 from public.dues where transaction_id = old.id) then
      raise exception 'Transaksi ini terhubung ke iuran. Batalkan pembayaran iuran (unpay_due) untuk menghapusnya.'
        using errcode = 'P0001';
    end if;
    return old;
  end if;

  if tg_op = 'INSERT' then
    select id, full_name into v_actor_id, v_actor_name
    from public.members
    where email = public.current_email();

    new.created_by_id   = v_actor_id;
    new.created_by_name = coalesce(v_actor_name, 'Sistem');
  else
    new.created_by_id   = old.created_by_id;
    new.created_by_name = old.created_by_name;
  end if;

  new.counterparty = trim(new.counterparty);
  new.purpose      = trim(new.purpose);

  if new.trx_date > public.today_wib() then
    raise exception 'Tanggal transaksi tidak boleh melebihi hari ini (WIB).'
      using errcode = 'P0001';
  end if;

  select * into v_cat from public.categories where id = new.category_id;
  if not found then
    raise exception 'Kategori tidak ditemukan.' using errcode = 'P0001';
  end if;

  if v_cat.type is not null and v_cat.type <> new.type then
    raise exception 'Kategori "%" tidak sesuai dengan tipe transaksi', v_cat.name
      using errcode = 'P0001';
  end if;

  if tg_op = 'INSERT' or new.category_id <> old.category_id then
    if not v_cat.is_active then
      raise exception 'Kategori "%" sudah tidak aktif', v_cat.name using errcode = 'P0001';
    end if;
    if v_cat.code = 'iuran' and not v_via_rpc then
      raise exception 'Kategori Iuran hanya dibuat otomatis saat iuran ditandai lunas'
        using errcode = 'P0001';
    end if;
    if v_cat.code = 'saldo_awal' then
      perform 1 from public.categories where id = v_cat.id for update;
      if exists (
        select 1 from public.transactions t
        where t.category_id = v_cat.id
          and (tg_op = 'INSERT' or t.id <> old.id)
      ) then
        raise exception 'Transaksi Saldo awal hanya boleh dicatat satu kali.'
          using errcode = 'P0001';
      end if;
    end if;
  end if;

  if tg_op = 'UPDATE'
     and (new.amount       <> old.amount
       or new.type         <> old.type
       or new.category_id  <> old.category_id
       or new.trx_date     <> old.trx_date
       or new.counterparty <> old.counterparty)
     and exists (select 1 from public.dues where transaction_id = old.id) then
    raise exception 'Pada transaksi iuran, hanya catatan (keperluan) dan bukti transfer yang boleh diubah. Untuk mengubah nominal atau tanggal, batalkan lalu catat ulang lewat modul iuran.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_transactions_guard on public.transactions;
create trigger trg_transactions_guard before insert or update or delete on public.transactions
  for each row execute function public.guard_transactions();

-- ---------- PENJAGA: saldo tidak boleh minus ----------
create or replace function public.guard_non_negative_balance()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  v_balance numeric(14,2);
begin
  perform pg_advisory_xact_lock(90210777);

  select
    coalesce(sum(amount) filter (where type = 'income'), 0)
    - coalesce(sum(amount) filter (where type = 'expense'), 0)
  into v_balance
  from public.transactions;

  if v_balance < 0 then
    raise exception 'Operasi ditolak: saldo kas tidak boleh minus (saldo akan menjadi -Rp %).',
      to_char(abs(v_balance), 'FM999G999G999G990')
      using errcode = 'P0001';
  end if;

  return null;
end;
$$;

drop trigger if exists trg_transactions_balance on public.transactions;
create trigger trg_transactions_balance after insert or update or delete on public.transactions
  for each statement execute function public.guard_non_negative_balance();

-- ---------- PENJAGA: iuran lunas tidak boleh diubah diam-diam ----------
create or replace function public.guard_dues()
returns trigger
language plpgsql
as $$
begin
  if old.status = 'paid' and new.status = 'paid'
     and (new.member_id      <> old.member_id
       or new.period         <> old.period
       or new.amount         <> old.amount
       or new.paid_at        <> old.paid_at
       or new.transaction_id <> old.transaction_id) then
    raise exception 'Iuran yang sudah lunas tidak boleh diubah. Batalkan pembayaran terlebih dahulu.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_dues_guard on public.dues;
create trigger trg_dues_guard before update on public.dues
  for each row execute function public.guard_dues();

-- ---------- LOG AKTIVITAS ----------
-- Mencatat INSERT/UPDATE/DELETE. UPDATE yang tidak mengubah isi data
-- (selain updated_at) diabaikan agar log tidak penuh noise.
create or replace function public.log_audit()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  v_old        jsonb := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end;
  v_new        jsonb := case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end;
  v_actor_name text;
begin
  if tg_op = 'UPDATE' and (v_new - 'updated_at') = (v_old - 'updated_at') then
    return null;
  end if;

  select full_name into v_actor_name
  from public.members
  where email = public.current_email();

  insert into public.audit_log (
    table_name, record_id, action, old_data, new_data, actor_name, actor_email
  )
  values (
    tg_table_name,
    coalesce(v_new ->> 'id', v_old ->> 'id'),
    tg_op,
    v_old,
    v_new,
    coalesce(v_actor_name, 'Sistem'),
    nullif(public.current_email(), '')
  );
  return null; -- trigger AFTER: nilai kembalian diabaikan
end;
$$;

drop trigger if exists trg_members_audit      on public.members;
drop trigger if exists trg_settings_audit     on public.settings;
drop trigger if exists trg_categories_audit   on public.categories;
drop trigger if exists trg_transactions_audit on public.transactions;
drop trigger if exists trg_dues_audit         on public.dues;

create trigger trg_members_audit      after insert or update or delete on public.members
  for each row execute function public.log_audit();
create trigger trg_settings_audit     after insert or update or delete on public.settings
  for each row execute function public.log_audit();
create trigger trg_categories_audit   after insert or update or delete on public.categories
  for each row execute function public.log_audit();
create trigger trg_transactions_audit after insert or update or delete on public.transactions
  for each row execute function public.log_audit();
create trigger trg_dues_audit         after insert or update or delete on public.dues
  for each row execute function public.log_audit();

-- ########## 0003_rls.sql ##########
-- =====================================================================
-- DOMPETIM v1.2 | 0003_rls.sql
-- Row Level Security & privasi email.
-- - Tabel members: non-admin hanya dapat membaca baris miliknya sendiri
--   (agar UI bisa membedakan belum terdaftar vs mantan anggota nonaktif).
--   Daftar anggota tanpa email dibaca melalui view v_members.
-- - Tabel audit_log: hanya admin yang boleh query tabel mentah;
--   anggota biasa membaca melalui view v_audit_log (email disembunyikan).
-- - Tabel dues & audit_log TIDAK bisa ditulis langsung dari client.
-- =====================================================================

alter table public.members      enable row level security;
alter table public.settings     enable row level security;
alter table public.categories   enable row level security;
alter table public.transactions enable row level security;
alter table public.dues         enable row level security;
alter table public.audit_log    enable row level security;

-- members
drop policy if exists members_select on public.members;
drop policy if exists members_insert on public.members;
drop policy if exists members_update on public.members;
drop policy if exists members_delete on public.members;
create policy members_select on public.members for select to authenticated
  using (public.is_admin() or email = public.current_email());
create policy members_insert on public.members for insert to authenticated
  with check (public.is_admin());
create policy members_update on public.members for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy members_delete on public.members for delete to authenticated
  using (public.is_admin());

-- settings (satu baris tetap: tanpa insert/delete)
drop policy if exists settings_select on public.settings;
drop policy if exists settings_update on public.settings;
create policy settings_select on public.settings for select to authenticated
  using (public.is_member());
create policy settings_update on public.settings for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- categories
drop policy if exists categories_select on public.categories;
drop policy if exists categories_insert on public.categories;
drop policy if exists categories_update on public.categories;
drop policy if exists categories_delete on public.categories;
create policy categories_select on public.categories for select to authenticated
  using (public.is_member());
create policy categories_insert on public.categories for insert to authenticated
  with check (public.is_admin() and not is_system and code is null);
create policy categories_update on public.categories for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy categories_delete on public.categories for delete to authenticated
  using (public.is_admin());

-- transactions
drop policy if exists transactions_select on public.transactions;
drop policy if exists transactions_insert on public.transactions;
drop policy if exists transactions_update on public.transactions;
drop policy if exists transactions_delete on public.transactions;
create policy transactions_select on public.transactions for select to authenticated
  using (public.is_member());
create policy transactions_insert on public.transactions for insert to authenticated
  with check (public.is_admin());
create policy transactions_update on public.transactions for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy transactions_delete on public.transactions for delete to authenticated
  using (public.is_admin());

-- dues: hanya SELECT; penulisan lewat fungsi RPC di 0004
drop policy if exists dues_select on public.dues;
create policy dues_select on public.dues for select to authenticated
  using (public.is_member());

-- audit_log: tabel mentah hanya SELECT untuk admin; anggota pakai v_audit_log
drop policy if exists audit_log_select on public.audit_log;
create policy audit_log_select on public.audit_log for select to authenticated
  using (public.is_admin());

-- ---------- HAK TABEL (lapisan kedua di atas RLS) ----------
revoke all on public.members, public.settings, public.categories,
              public.transactions, public.dues, public.audit_log from anon;

revoke insert, update, delete, truncate on public.dues      from authenticated;
revoke insert, update, delete, truncate on public.audit_log from authenticated;

-- ########## 0004_functions.sql ##########
-- =====================================================================
-- DOMPETIM v1.2 | 0004_functions.sql
-- Fungsi kerja (RPC) untuk modul iuran. SECURITY DEFINER karena tabel
-- dues tidak bisa ditulis langsung; setiap fungsi memeriksa is_admin().
-- =====================================================================

-- Hapus signature versi sebelumnya (bila ada) agar aman saat upgrade.
drop function if exists public.pay_due(uuid, date, text);
drop function if exists public.unpay_due(uuid);

-- 1. Buat tagihan iuran semua anggota aktif (termasuk admin) untuk satu bulan
--    yang billing_start_period <= periode tersebut.
--    Contoh: select public.generate_dues('2026-12-01'); -> jumlah tagihan baru
create or replace function public.generate_dues(p_period date)
returns int
language plpgsql security definer
set search_path = public
as $$
declare
  v_period date := date_trunc('month', p_period)::date;
  v_amount numeric(14,2);
  v_count  int;
begin
  if not public.is_admin() then
    raise exception 'Hanya pengelola yang boleh membuat tagihan iuran' using errcode = '42501';
  end if;

  if v_period is null then
    raise exception 'Periode tagihan tidak valid' using errcode = 'P0001';
  end if;

  select monthly_due_amount into v_amount from public.settings where id = 1;
  if v_amount is null or v_amount <= 0 then
    raise exception 'Nominal iuran bulanan belum diatur (harus lebih dari 0)' using errcode = 'P0001';
  end if;

  insert into public.dues (member_id, period, amount)
  select m.id, v_period, v_amount
  from public.members m
  where m.is_active
    and m.billing_start_period <= v_period
  on conflict (member_id, period) do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- 2. Buat 1 tagihan iuran satuan untuk anggota aktif tertentu (misal anggota baru tengah bulan).
create or replace function public.create_due(p_member_id uuid, p_period date)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_period date := date_trunc('month', p_period)::date;
  v_member public.members%rowtype;
  v_amount numeric(14,2);
  v_due_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Hanya pengelola yang boleh membuat tagihan iuran' using errcode = '42501';
  end if;

  if v_period is null then
    raise exception 'Periode tagihan tidak valid' using errcode = 'P0001';
  end if;

  select * into v_member from public.members where id = p_member_id;
  if not found then
    raise exception 'Anggota tidak ditemukan' using errcode = 'P0001';
  end if;
  if not v_member.is_active then
    raise exception 'Anggota nonaktif tidak dapat dibuatkan tagihan baru' using errcode = 'P0001';
  end if;

  select monthly_due_amount into v_amount from public.settings where id = 1;
  if v_amount is null or v_amount <= 0 then
    raise exception 'Nominal iuran bulanan belum diatur (harus lebih dari 0)' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.dues where member_id = p_member_id and period = v_period
  ) then
    raise exception 'Tagihan iuran untuk anggota dan periode ini sudah ada' using errcode = 'P0001';
  end if;

  insert into public.dues (member_id, period, amount)
  values (p_member_id, v_period, v_amount)
  returning id into v_due_id;

  return v_due_id;
end;
$$;

-- 3. Tandai 1 tagihan iuran lunas + otomatis catat pemasukan (kategori Iuran).
--    Contoh: select public.pay_due('<due_id>', null, null, 'Transfer BCA'); -> id transaksi
create or replace function public.pay_due(
  p_due_id       uuid,
  p_paid_at      date default null,
  p_receipt_path text default null,
  p_note         text default null
)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_due     public.dues%rowtype;
  v_paid_at date := coalesce(p_paid_at, public.today_wib());
  v_receipt text := nullif(trim(p_receipt_path), '');
  v_note    text := nullif(trim(p_note), '');
  v_name    text;
  v_cat     uuid;
  v_trx     uuid;
begin
  if not public.is_admin() then
    raise exception 'Hanya pengelola yang boleh mencatat pembayaran iuran' using errcode = '42501';
  end if;

  if v_paid_at > public.today_wib() then
    raise exception 'Tanggal pembayaran tidak boleh melebihi hari ini (WIB).' using errcode = 'P0001';
  end if;

  select * into v_due from public.dues where id = p_due_id for update;
  if not found then
    raise exception 'Iuran tidak ditemukan' using errcode = 'P0001';
  end if;
  if v_due.status = 'paid' then
    raise exception 'Iuran ini sudah berstatus lunas' using errcode = 'P0001';
  end if;

  select full_name into v_name from public.members where id = v_due.member_id;
  select id into v_cat from public.categories where code = 'iuran';

  -- izinkan pembuatan transaksi berkategori Iuran hanya di dalam transaksi ini
  perform set_config('dompetim.via_rpc', '1', true);

  insert into public.transactions (type, amount, trx_date, counterparty, purpose, category_id, receipt_path)
  values (
    'income',
    v_due.amount,
    v_paid_at,
    v_name,
    'Iuran ' || to_char(v_due.period, 'YYYY-MM') || case when v_note is not null then ' - ' || v_note else '' end,
    v_cat,
    v_receipt
  )
  returning id into v_trx;

  perform set_config('dompetim.via_rpc', '', true);

  update public.dues
     set status = 'paid', paid_at = v_paid_at, transaction_id = v_trx
   where id = p_due_id;

  return v_trx;
end;
$$;

-- 4. Bayar iuran multi-bulan sekaligus untuk 1 anggota (tunggakan + bulan berjalan + bayar di muka).
--    Jika periode belum punya tagihan, otomatis dibuatkan terlebih dahulu selama anggota aktif.
create or replace function public.pay_member_dues(
  p_member_id    uuid,
  p_periods      date[],
  p_paid_at      date default null,
  p_receipt_path text default null,
  p_note         text default null
)
returns uuid[]
language plpgsql security definer
set search_path = public
as $$
declare
  v_paid_at        date := coalesce(p_paid_at, public.today_wib());
  v_receipt        text := nullif(trim(p_receipt_path), '');
  v_note           text := nullif(trim(p_note), '');
  v_member         public.members%rowtype;
  v_default_amount numeric(14,2);
  v_cat            uuid;
  v_period         date;
  v_due            public.dues%rowtype;
  v_due_id         uuid;
  v_amount         numeric(14,2);
  v_trx            uuid;
  v_trx_ids        uuid[] := '{}';
begin
  if not public.is_admin() then
    raise exception 'Hanya pengelola yang boleh mencatat pembayaran iuran' using errcode = '42501';
  end if;

  if v_paid_at > public.today_wib() then
    raise exception 'Tanggal pembayaran tidak boleh melebihi hari ini (WIB).' using errcode = 'P0001';
  end if;

  if p_periods is null or coalesce(array_length(p_periods, 1), 0) = 0 then
    raise exception 'Pilih minimal satu periode iuran.' using errcode = 'P0001';
  end if;

  select * into v_member from public.members where id = p_member_id;
  if not found then
    raise exception 'Anggota tidak ditemukan' using errcode = 'P0001';
  end if;

  select monthly_due_amount into v_default_amount from public.settings where id = 1;
  select id into v_cat from public.categories where code = 'iuran';

  for v_period in
    select distinct date_trunc('month', p)::date
    from unnest(p_periods) as p
    where p is not null
    order by 1
  loop
    select * into v_due
    from public.dues
    where member_id = p_member_id and period = v_period
    for update;

    if found then
      if v_due.status = 'paid' then
        raise exception 'Iuran periode % sudah berstatus lunas.', to_char(v_period, 'YYYY-MM')
          using errcode = 'P0001';
      end if;
      v_due_id := v_due.id;
      v_amount := v_due.amount;
    else
      if not v_member.is_active then
        raise exception 'Anggota nonaktif tidak dapat dibuatkan tagihan baru untuk periode %.', to_char(v_period, 'YYYY-MM')
          using errcode = 'P0001';
      end if;
      if v_default_amount is null or v_default_amount <= 0 then
        raise exception 'Nominal iuran bulanan belum diatur (harus lebih dari 0)' using errcode = 'P0001';
      end if;

      insert into public.dues (member_id, period, amount)
      values (p_member_id, v_period, v_default_amount)
      returning id, amount into v_due_id, v_amount;
    end if;

    perform set_config('dompetim.via_rpc', '1', true);

    insert into public.transactions (type, amount, trx_date, counterparty, purpose, category_id, receipt_path)
    values (
      'income',
      v_amount,
      v_paid_at,
      v_member.full_name,
      'Iuran ' || to_char(v_period, 'YYYY-MM') || case when v_note is not null then ' - ' || v_note else '' end,
      v_cat,
      v_receipt
    )
    returning id into v_trx;

    perform set_config('dompetim.via_rpc', '', true);

    update public.dues
       set status = 'paid', paid_at = v_paid_at, transaction_id = v_trx
     where id = v_due_id;

    v_trx_ids := array_append(v_trx_ids, v_trx);
  end loop;

  if coalesce(array_length(v_trx_ids, 1), 0) = 0 then
    raise exception 'Pilih minimal satu periode iuran yang valid.' using errcode = 'P0001';
  end if;

  return v_trx_ids;
end;
$$;

-- 5. Bayar massal beberapa tagihan sekaligus (lintas anggota / lintas bulan).
create or replace function public.pay_dues_batch(
  p_due_ids      uuid[],
  p_paid_at      date default null,
  p_receipt_path text default null,
  p_note         text default null
)
returns uuid[]
language plpgsql security definer
set search_path = public
as $$
declare
  v_paid_at date := coalesce(p_paid_at, public.today_wib());
  v_due_id  uuid;
  v_trx     uuid;
  v_trx_ids uuid[] := '{}';
begin
  if not public.is_admin() then
    raise exception 'Hanya pengelola yang boleh mencatat pembayaran iuran' using errcode = '42501';
  end if;

  if v_paid_at > public.today_wib() then
    raise exception 'Tanggal pembayaran tidak boleh melebihi hari ini (WIB).' using errcode = 'P0001';
  end if;

  if p_due_ids is null or coalesce(array_length(p_due_ids, 1), 0) = 0 then
    raise exception 'Pilih minimal satu tagihan iuran.' using errcode = 'P0001';
  end if;

  for v_due_id in
    select distinct d_id
    from unnest(p_due_ids) as d_id
    where d_id is not null
    order by 1
  loop
    v_trx := public.pay_due(v_due_id, v_paid_at, p_receipt_path, p_note);
    v_trx_ids := array_append(v_trx_ids, v_trx);
  end loop;

  if coalesce(array_length(v_trx_ids, 1), 0) = 0 then
    raise exception 'Pilih minimal satu tagihan iuran yang valid.' using errcode = 'P0001';
  end if;

  return v_trx_ids;
end;
$$;

-- 6. Batalkan status lunas (transaksi pemasukan terkait ikut dihapus).
--    Mengembalikan receipt_path jika file tersebut tidak dipakai transaksi lain
--    sehingga aman untuk dihapus dari Storage oleh frontend.
create or replace function public.unpay_due(p_due_id uuid)
returns text
language plpgsql security definer
set search_path = public
as $$
declare
  v_due          public.dues%rowtype;
  v_receipt_path text;
begin
  if not public.is_admin() then
    raise exception 'Hanya pengelola yang boleh membatalkan pembayaran' using errcode = '42501';
  end if;

  select * into v_due from public.dues where id = p_due_id for update;
  if not found then
    raise exception 'Iuran tidak ditemukan' using errcode = 'P0001';
  end if;
  if v_due.status <> 'paid' then
    raise exception 'Iuran ini belum berstatus lunas' using errcode = 'P0001';
  end if;

  select receipt_path into v_receipt_path
  from public.transactions
  where id = v_due.transaction_id;

  update public.dues
     set status = 'unpaid', paid_at = null, transaction_id = null
   where id = p_due_id;

  delete from public.transactions where id = v_due.transaction_id;

  if v_receipt_path is not null
     and not exists (select 1 from public.transactions where receipt_path = v_receipt_path) then
    return v_receipt_path;
  end if;

  return null;
end;
$$;

-- 7. Hapus 1 tagihan yang belum lunas (misal anggota dibebaskan bulan tertentu). Yang lunas tidak boleh.
create or replace function public.delete_due(p_due_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_status public.due_status;
begin
  if not public.is_admin() then
    raise exception 'Hanya pengelola yang boleh menghapus tagihan' using errcode = '42501';
  end if;

  select status into v_status from public.dues where id = p_due_id for update;
  if not found then
    raise exception 'Iuran tidak ditemukan' using errcode = 'P0001';
  end if;
  if v_status = 'paid' then
    raise exception 'Tagihan yang sudah lunas tidak boleh dihapus. Batalkan pembayaran terlebih dahulu.'
      using errcode = 'P0001';
  end if;

  delete from public.dues where id = p_due_id;
end;
$$;

-- 8. Hapus semua tagihan belum lunas pada satu periode sekaligus (misal salah generate bulan).
--    Tagihan yang sudah lunas tidak ikut terhapus.
create or replace function public.delete_unpaid_dues_by_period(p_period date)
returns int
language plpgsql security definer
set search_path = public
as $$
declare
  v_period date := date_trunc('month', p_period)::date;
  v_count  int;
begin
  if not public.is_admin() then
    raise exception 'Hanya pengelola yang boleh menghapus tagihan' using errcode = '42501';
  end if;

  if v_period is null then
    raise exception 'Periode tagihan tidak valid' using errcode = 'P0001';
  end if;

  delete from public.dues
  where period = v_period and status = 'unpaid';

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Hanya user login yang boleh memanggil fungsi kerja ini.
revoke all on function public.generate_dues(date)                               from public, anon;
revoke all on function public.create_due(uuid, date)                             from public, anon;
revoke all on function public.pay_due(uuid, date, text, text)                    from public, anon;
revoke all on function public.pay_member_dues(uuid, date[], date, text, text)    from public, anon;
revoke all on function public.pay_dues_batch(uuid[], date, text, text)           from public, anon;
revoke all on function public.unpay_due(uuid)                                    from public, anon;
revoke all on function public.delete_due(uuid)                                   from public, anon;
revoke all on function public.delete_unpaid_dues_by_period(date)                 from public, anon;

grant execute on function public.generate_dues(date)                             to authenticated;
grant execute on function public.create_due(uuid, date)                          to authenticated;
grant execute on function public.pay_due(uuid, date, text, text)                 to authenticated;
grant execute on function public.pay_member_dues(uuid, date[], date, text, text) to authenticated;
grant execute on function public.pay_dues_batch(uuid[], date, text, text)        to authenticated;
grant execute on function public.unpay_due(uuid)                                 to authenticated;
grant execute on function public.delete_due(uuid)                                to authenticated;
grant execute on function public.delete_unpaid_dues_by_period(date)              to authenticated;

-- ########## 0005_views.sql ##########
-- =====================================================================
-- DOMPETIM v1.2 | 0005_views.sql
-- View laporan & view bertopeng privasi (email disembunyikan untuk non-admin).
-- =====================================================================

drop view if exists
  public.v_balance,
  public.v_monthly_summary,
  public.v_category_summary,
  public.v_transactions,
  public.v_members,
  public.v_dues_board,
  public.v_audit_log;

-- 1. Ringkasan saldo keseluruhan & bulan berjalan (WIB).
--    HAVING public.is_member() memastikan non-anggota mendapat 0 baris.
create or replace view public.v_balance
with (security_invoker = true) as
select
  coalesce(sum(t.amount) filter (where c.code = 'saldo_awal'), 0) as opening_balance,
  coalesce(sum(t.amount) filter (where t.type = 'income'),     0) as total_income,
  coalesce(sum(t.amount) filter (where t.type = 'expense'),    0) as total_expense,
  coalesce(sum(t.amount) filter (where t.type = 'income'),     0)
  - coalesce(sum(t.amount) filter (where t.type = 'expense'),  0) as balance,
  coalesce(sum(t.amount) filter (
    where t.type = 'income'
      and coalesce(c.code, '') <> 'saldo_awal'
      and date_trunc('month', t.trx_date)::date = date_trunc('month', public.today_wib())::date
  ), 0) as month_income,
  coalesce(sum(t.amount) filter (
    where t.type = 'expense'
      and date_trunc('month', t.trx_date)::date = date_trunc('month', public.today_wib())::date
  ), 0) as month_expense,
  coalesce(sum(t.amount) filter (
    where t.type = 'income'
      and coalesce(c.code, '') <> 'saldo_awal'
      and date_trunc('month', t.trx_date)::date = date_trunc('month', public.today_wib())::date
  ), 0)
  - coalesce(sum(t.amount) filter (
    where t.type = 'expense'
      and date_trunc('month', t.trx_date)::date = date_trunc('month', public.today_wib())::date
  ), 0) as month_net
from public.transactions t
left join public.categories c on c.id = t.category_id
having public.is_member();

-- 2. Rekap bulanan (pemasukan operasional mengecualikan saldo_awal agar grafik tidak bias).
create or replace view public.v_monthly_summary
with (security_invoker = true) as
select
  date_trunc('month', t.trx_date)::date as month,
  coalesce(sum(t.amount) filter (where t.type = 'income' and coalesce(c.code, '') <> 'saldo_awal'), 0) as income,
  coalesce(sum(t.amount) filter (where c.code = 'saldo_awal'), 0)                                     as opening_balance,
  coalesce(sum(t.amount) filter (where t.type = 'expense'), 0)                                        as expense,
  coalesce(sum(t.amount) filter (where t.type = 'income' and coalesce(c.code, '') <> 'saldo_awal'), 0)
  - coalesce(sum(t.amount) filter (where t.type = 'expense'), 0)                                      as net
from public.transactions t
join public.categories c on c.id = t.category_id
group by 1
order by 1 desc;

-- 3. Rekap per kategori per bulan (untuk grafik donat/batang kategori).
create or replace view public.v_category_summary
with (security_invoker = true) as
select
  date_trunc('month', t.trx_date)::date as month,
  c.id   as category_id,
  c.name as category,
  c.code as category_code,
  t.type,
  sum(t.amount) as total,
  count(*)      as trx_count
from public.transactions t
join public.categories c on c.id = t.category_id
group by 1, 2, 3, 4, 5
order by 1 desc, 6 desc;

-- 4. Daftar transaksi lengkap (termasuk penanda transaksi iuran).
create or replace view public.v_transactions
with (security_invoker = true) as
select
  t.id, t.type, t.amount, t.trx_date, t.counterparty, t.purpose,
  c.name as category, c.code as category_code, t.category_id,
  t.receipt_path, (t.receipt_path is not null) as has_receipt,
  d.id as due_id, (d.id is not null) as is_due,
  t.created_by_name, t.created_at
from public.transactions t
join public.categories c on c.id = t.category_id
left join public.dues d on d.transaction_id = t.id
order by t.trx_date desc, t.created_at desc;

-- 5. Daftar anggota (email hanya tampil untuk admin; tetap dijaga is_member()).
create or replace view public.v_members as
select
  m.id,
  m.full_name,
  m.role,
  m.is_active,
  m.billing_start_period,
  case when public.is_admin() then m.email else null end as email,
  m.created_at,
  m.updated_at
from public.members m
where public.is_member()
order by m.is_active desc, m.full_name;

-- 6. Papan status iuran (tanpa email anggota, dilengkapi transaction_id & receipt_path).
create or replace view public.v_dues_board as
select
  d.id as due_id,
  d.period,
  m.id as member_id,
  m.full_name,
  m.is_active as member_is_active,
  d.amount,
  d.status,
  d.paid_at,
  d.transaction_id,
  t.receipt_path,
  (d.status = 'unpaid' and public.today_wib() > (d.period + (s.due_day - 1))) as is_overdue
from public.dues d
join public.members m on m.id = d.member_id
cross join public.settings s
left join public.transactions t on t.id = d.transaction_id
where public.is_member()
order by d.period desc, m.full_name;

-- 7. Log aktivitas (email pelaku & field email pada JSON disembunyikan dari non-admin).
create or replace view public.v_audit_log as
select
  a.id,
  a.table_name,
  a.record_id,
  a.action,
  case when public.is_admin() then a.old_data else a.old_data - 'email' end as old_data,
  case when public.is_admin() then a.new_data else a.new_data - 'email' end as new_data,
  coalesce(a.actor_name, 'Sistem') as actor_name,
  case when public.is_admin() then a.actor_email else null end as actor_email,
  a.created_at
from public.audit_log a
where public.is_member()
order by a.created_at desc, a.id desc;

revoke all on public.v_balance, public.v_monthly_summary, public.v_category_summary,
              public.v_transactions, public.v_members, public.v_dues_board, public.v_audit_log from anon;

grant select on public.v_balance, public.v_monthly_summary, public.v_category_summary,
                public.v_transactions, public.v_members, public.v_dues_board, public.v_audit_log to authenticated;

-- ########## 0006_storage.sql ##########
-- =====================================================================
-- DOMPETIM v1.2 | 0006_storage.sql
-- Bucket privat untuk bukti/nota (maks 1 file per transaksi, maks 5 MB).
-- Saran path:
--   receipts/<tahun>/<uuid-file>.<ext>
-- Catatan aplikasi:
--   - Upload dilakukan sebelum insert/update transaksi atau sebelum panggil
--     pay_due() / pay_member_dues() / pay_dues_batch().
--   - Saat bukti diganti, transaksi dihapus, atau unpay_due() mengembalikan
--     path non-null, frontend wajib menghapus file lama di bucket agar
--     kuota storage tetap bersih.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'receipts', 'receipts', false, 5242880,   -- maks 5 MB
  array['image/jpeg','image/png','image/webp','application/pdf']
)
on conflict (id) do nothing;

drop policy if exists receipts_select on storage.objects;
drop policy if exists receipts_insert on storage.objects;
drop policy if exists receipts_update on storage.objects;
drop policy if exists receipts_delete on storage.objects;

create policy receipts_select on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and public.is_member());
create policy receipts_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and public.is_admin());
create policy receipts_update on storage.objects for update to authenticated
  using (bucket_id = 'receipts' and public.is_admin())
  with check (bucket_id = 'receipts' and public.is_admin());
create policy receipts_delete on storage.objects for delete to authenticated
  using (bucket_id = 'receipts' and public.is_admin());
