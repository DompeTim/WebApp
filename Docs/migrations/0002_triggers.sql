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
