-- R&R NEXUS: company logos and public logo delivery.
-- Run once in Supabase SQL Editor. Does not change existing company data.
alter table public.companies add column if not exists logo_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('company-logos', 'company-logos', true, 2097152, array['image/png','image/jpeg','image/webp'])
on conflict (id) do update
set public = true,
    file_size_limit = 2097152,
    allowed_mime_types = array['image/png','image/jpeg','image/webp'];

drop policy if exists "Master admins upload company logos" on storage.objects;
create policy "Master admins upload company logos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'company-logos'
  and exists (
    select 1 from public.user_profiles p
    where p.user_id = auth.uid() and p.role = 'master_admin'
  )
);

drop policy if exists "Master admins update company logos" on storage.objects;
create policy "Master admins update company logos"
on storage.objects for update to authenticated
using (
  bucket_id = 'company-logos'
  and exists (
    select 1 from public.user_profiles p
    where p.user_id = auth.uid() and p.role = 'master_admin'
  )
)
with check (
  bucket_id = 'company-logos'
  and exists (
    select 1 from public.user_profiles p
    where p.user_id = auth.uid() and p.role = 'master_admin'
  )
);

drop policy if exists "Public can view company logos" on storage.objects;
create policy "Public can view company logos"
on storage.objects for select to public
using (bucket_id = 'company-logos');
