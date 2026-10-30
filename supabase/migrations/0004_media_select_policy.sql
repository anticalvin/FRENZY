-- Upserting into storage (upload with upsert:true) needs SELECT on storage.objects.
-- Without this policy, profile photo and post uploads fail. Scoped to the user's own folder;
-- public reads still work through the public bucket URLs.
create policy "media select own folder" on storage.objects for select
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- protect_verified is a trigger function; it must not be callable through the API.
revoke execute on function public.protect_verified() from public, anon, authenticated;
