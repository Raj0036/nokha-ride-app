-- Prevent workspace switching from granting or replacing roles.
-- A user must already have both trusted role assignments and both approved workspaces.
create or replace function public.switch_owner_driver_role(target_role public.user_role)
returns public.user_role
language plpgsql
security definer
set search_path = ''
as $function$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  if target_role is null or target_role not in ('OWNER'::public.user_role, 'DRIVER'::public.user_role) then
    raise exception 'Only OWNER and DRIVER workspaces can be selected';
  end if;

  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = current_user_id and ur.role = 'OWNER'::public.user_role
  ) or not exists (
    select 1 from public.user_roles ur
    where ur.user_id = current_user_id and ur.role = 'DRIVER'::public.user_role
  ) then
    raise exception 'Both OWNER and DRIVER roles must already be assigned';
  end if;

  if not exists (
    select 1
    from public.vehicles v
    join public.vehicle_categories vc on vc.id = v.category_id
    where v.owner_id = current_user_id
      and v.verification_status = 'APPROVED'::public.verification_status
      and v.is_active = true
      and vc.is_active = true
      and vc.is_bike = false
      and vc.is_passenger_vehicle = true
  ) then
    raise exception 'Owner workspace is not approved';
  end if;

  if not exists (
    select 1
    from public.drivers d
    where d.profile_id = current_user_id
      and d.verification_status = 'APPROVED'::public.verification_status
      and d.license_expiry >= current_date
  ) then
    raise exception 'Driver workspace is not approved';
  end if;

  -- Selecting a workspace is not a role-assignment operation.
  return target_role;
end;
$function$;

revoke all on function public.switch_owner_driver_role(public.user_role) from public;
revoke all on function public.switch_owner_driver_role(public.user_role) from anon;
grant execute on function public.switch_owner_driver_role(public.user_role) to authenticated;
grant execute on function public.switch_owner_driver_role(public.user_role) to service_role;
