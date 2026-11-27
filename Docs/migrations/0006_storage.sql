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
