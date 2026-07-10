-- WhereToNext — v16 migration: banner images move to Storage
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
--
-- Uploaded trip banners were stored as base64 data-URLs inside the
-- wtn_trips row, so every dashboard load dragged megabytes of image data
-- through JSON (and bloated the offline localStorage cache). This creates
-- a small public bucket for them; the app now uploads the resized JPEG
-- there and stores only the URL. Existing data-URL banners keep working
-- and migrate to Storage the next time the trip's banner is changed.

insert into storage.buckets (id, name, public)
values ('wtn-banners','wtn-banners', true)
on conflict (id) do update set public = true;

-- Anyone may view (the bucket is public; select policy covers API access)
drop policy if exists wtn_banners_read on storage.objects;
create policy wtn_banners_read on storage.objects
  for select using (bucket_id = 'wtn-banners');

-- Signed-in users manage only their own folder: <user-id>/<uuid>.jpg
drop policy if exists wtn_banners_insert on storage.objects;
create policy wtn_banners_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'wtn-banners' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists wtn_banners_update on storage.objects;
create policy wtn_banners_update on storage.objects
  for update to authenticated
  using (bucket_id = 'wtn-banners' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists wtn_banners_delete on storage.objects;
create policy wtn_banners_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'wtn-banners' and (storage.foldername(name))[1] = auth.uid()::text);
