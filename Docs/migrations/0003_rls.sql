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
