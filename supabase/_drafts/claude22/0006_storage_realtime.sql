-- 0006_storage_realtime.sql — Storage buckets/policies and Realtime publication. Supabase-specific (storage.* and supabase_realtime).
-- Path conventions are documented in docs/STORAGE_ARCHITECTURE.md.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('profile-photos',     'profile-photos',     false, 2097152, array['image/jpeg','image/png','image/webp']),
  ('provider-portfolio', 'provider-portfolio', true,  5242880, array['image/jpeg','image/png','image/webp']),
  ('inspection-photos',  'inspection-photos',  false, 5242880, array['image/jpeg','image/png','image/webp']),
  ('invoice-files',      'invoice-files',      false, 5242880, array['application/pdf'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
                               allowed_mime_types = excluded.allowed_mime_types;

-- profile-photos: {user_id}/avatar.{ext}
create policy sp_profile_select on storage.objects for select to authenticated
  using (bucket_id = 'profile-photos' and ((storage.foldername(name))[1] = auth.uid()::text or is_admin()
         or provider_visible(safe_uuid((storage.foldername(name))[1])) or shares_job_with(safe_uuid((storage.foldername(name))[1]))));
create policy sp_profile_write on storage.objects for insert to authenticated
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy sp_profile_update on storage.objects for update to authenticated
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy sp_profile_delete on storage.objects for delete to authenticated
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- provider-portfolio (public read via CDN): {provider_id}/{uuid}.{ext}; only the owning provider writes
create policy sp_portfolio_select on storage.objects for select to authenticated using (bucket_id = 'provider-portfolio');
create policy sp_portfolio_write on storage.objects for insert to authenticated
  with check (bucket_id = 'provider-portfolio' and (storage.foldername(name))[1] = auth.uid()::text
              and exists (select 1 from provider_profiles pp where pp.user_id = auth.uid()));
create policy sp_portfolio_update on storage.objects for update to authenticated
  using (bucket_id = 'provider-portfolio' and (storage.foldername(name))[1] = auth.uid()::text);
create policy sp_portfolio_delete on storage.objects for delete to authenticated
  using (bucket_id = 'provider-portfolio' and (storage.foldername(name))[1] = auth.uid()::text);

-- inspection-photos (private): {job_id}/{inspection_id}/{uuid}.{ext}; assigned provider uploads while job is INSPECTION; both parties read
create policy sp_insp_select on storage.objects for select to authenticated
  using (bucket_id = 'inspection-photos' and (is_admin() or is_job_party(safe_uuid((storage.foldername(name))[1]))));
create policy sp_insp_write on storage.objects for insert to authenticated
  with check (bucket_id = 'inspection-photos' and is_job_provider(safe_uuid((storage.foldername(name))[1]))
              and exists (select 1 from jobs j where j.id = safe_uuid((storage.foldername(name))[1]) and j.status = 'INSPECTION'));
create policy sp_insp_delete on storage.objects for delete to authenticated
  using (bucket_id = 'inspection-photos' and is_job_provider(safe_uuid((storage.foldername(name))[1]))
         and exists (select 1 from jobs j where j.id = safe_uuid((storage.foldername(name))[1]) and j.status = 'INSPECTION'));

-- invoice-files (private): {job_id}/{invoice_id}.pdf ; parties read; NO client write policy (service role / Edge Function only)
create policy sp_invoice_select on storage.objects for select to authenticated
  using (bucket_id = 'invoice-files' and (is_admin() or is_job_party(safe_uuid((storage.foldername(name))[1]))));

-- Realtime: RLS still filters every change event per subscriber.
do $$ declare t text; begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['jobs','job_status_history','quotes','notifications'] loop
      if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;
