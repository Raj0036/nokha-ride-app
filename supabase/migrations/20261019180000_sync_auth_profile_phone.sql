-- Keep the existing auth/profile/role triggers intact.
-- This additive trigger keeps the public profile's phone/email fields in sync
-- with Supabase Auth for phone-only and email users.

create or replace function public.sync_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email,
    new.phone
  )
  on conflict (id) do update
  set
    full_name = coalesce(nullif(excluded.full_name, ''), public.profiles.full_name),
    email = excluded.email,
    phone = excluded.phone;

  return new;
end;
$function$;

drop trigger if exists on_auth_user_profile_sync_insert on auth.users;
create trigger on_auth_user_profile_sync_insert
after insert on auth.users
for each row execute function public.sync_auth_user_profile();

drop trigger if exists on_auth_user_profile_sync_update on auth.users;
create trigger on_auth_user_profile_sync_update
after update of phone, email, raw_user_meta_data on auth.users
for each row execute function public.sync_auth_user_profile();
