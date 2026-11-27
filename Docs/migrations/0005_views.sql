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
