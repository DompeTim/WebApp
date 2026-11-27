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
