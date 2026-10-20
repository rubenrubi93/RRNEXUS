-- Run ONLY after:
-- 1) The master_admin role migration has been applied.
-- 2) You have created/invited this email in Supabase Authentication > Users.
-- This grants platform-wide administration to this exact Auth account.
do $$
declare
  target_user_id uuid;
begin
  select id into target_user_id
  from auth.users
  where lower(email) = lower('rrubiconsulting@gmail.com')
  limit 1;

  if target_user_id is null then
    raise exception 'No Supabase Auth user found for rrubiconsulting@gmail.com. Create/invite that account first.';
  end if;

  insert into public.user_profiles (user_id, full_name, role)
  values (target_user_id, 'Rubén Rubí', 'master_admin')
  on conflict (user_id) do update
    set full_name = excluded.full_name,
        role = excluded.role;
end $$;
