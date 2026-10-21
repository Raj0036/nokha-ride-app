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

-- Trigger/event-trigger functions are invoked by PostgreSQL, not as client RPCs.
-- Remove default API execution grants without changing the triggers themselves.
do $block$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and p.prorettype::regtype::text in ('trigger', 'event_trigger')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', fn.signature);
  end loop;
end;
$block$;

-- This operation is user-owned but requires a signed-in session.
revoke all on function public.cleanup_vehicle_submission(uuid) from public, anon;
grant execute on function public.cleanup_vehicle_submission(uuid) to authenticated;

-- This bulk maintenance operation is for trusted maintenance only, not client RPC.
revoke all on function public.process_expired_vehicle_documents() from public, anon, authenticated;
grant execute on function public.process_expired_vehicle_documents() to service_role;

-- These functions use schema-qualified application objects. Pinning their
-- search path prevents caller-controlled object shadowing without changing
-- their business logic or trigger behavior.
alter function public.set_updated_at() set search_path = '';
alter function public.generate_booking_number() set search_path = '';
alter function public.validate_vehicle_model() set search_path = '';
alter function public.vehicle_has_valid_required_documents(uuid) set search_path = '';
alter function public.enforce_vehicle_availability_guard() set search_path = '';
alter function public.enforce_vehicle_document_status() set search_path = '';
alter function public.driver_has_valid_required_documents(uuid) set search_path = '';
alter function public.enforce_driver_verification_guard() set search_path = '';
alter function public.owner_kyc_has_valid_required_documents(uuid) set search_path = '';
alter function public.enforce_owner_kyc_guard() set search_path = '';
alter function public.validate_driver_vehicle_assignment() set search_path = '';
alter function public.set_assignment_unassigned_at() set search_path = '';
alter function public.validate_booking_assignment() set search_path = '';
alter function public.validate_booking_status_transition() set search_path = '';
