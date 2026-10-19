-- Safely extend new-user provisioning for native phone OTP signups.
-- Existing profiles and roles are preserved; no user data is rewritten.
begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    full_name,
    email,
    phone
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.email, ''),
    nullif(new.phone, '')
  )
  on conflict (id) do nothing;

  -- New accounts receive only the least-privileged customer role.
  -- Owner/admin privileges must be granted through a separate verified workflow.
  insert into public.user_roles (user_id, role)
  values (new.id, 'CUSTOMER'::public.user_role)
  on conflict (user_id, role) do nothing;

  return new;
end;
$$;

commit;
