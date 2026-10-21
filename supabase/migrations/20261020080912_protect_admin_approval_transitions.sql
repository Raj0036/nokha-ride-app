-- Approval status must be controlled by an administrator or trusted service.
-- Vehicle identity edits invalidate approval and make the vehicle unavailable.
create or replace function public.enforce_vehicle_availability_guard()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  if auth.uid() is not null
     and coalesce(auth.role(), '') not in ('service_role', 'supabase_admin')
     and public.is_admin() is not true
  then
    if tg_op = 'INSERT'
       and new.verification_status is distinct from 'PENDING'::public.verification_status
    then
      raise exception 'Only an administrator can approve a vehicle.';
    end if;

    if tg_op = 'UPDATE'
       and new.verification_status is distinct from old.verification_status
       and new.verification_status is distinct from 'PENDING'::public.verification_status
    then
      raise exception 'Only an administrator can change vehicle verification status.';
    end if;

    if tg_op = 'UPDATE'
       and (
         new.registration_number is distinct from old.registration_number
         or new.vehicle_model_id is distinct from old.vehicle_model_id
         or new.category_id is distinct from old.category_id
         or new.manufacturing_year is distinct from old.manufacturing_year
       )
    then
      new.verification_status := 'PENDING'::public.verification_status;
      new.availability_status := 'UNAVAILABLE'::public.vehicle_availability_status;
    end if;

    if tg_op = 'UPDATE'
       and new.verification_status = 'PENDING'::public.verification_status
       and old.verification_status is distinct from 'PENDING'::public.verification_status
    then
      new.availability_status := 'UNAVAILABLE'::public.vehicle_availability_status;
    end if;
  end if;

  if new.availability_status = 'AVAILABLE'::public.vehicle_availability_status then
    if new.verification_status <> 'APPROVED'::public.verification_status then
      raise exception 'Vehicle cannot become AVAILABLE until it is ADMIN APPROVED.';
    end if;

    if public.vehicle_has_valid_required_documents(new.id) is not true then
      raise exception 'Vehicle cannot become AVAILABLE because required documents are missing, pending, rejected, or expired.';
    end if;
  end if;

  if new.verification_status in (
    'REJECTED'::public.verification_status,
    'SUSPENDED'::public.verification_status,
    'EXPIRED'::public.verification_status
  ) then
    new.availability_status := 'UNAVAILABLE'::public.vehicle_availability_status;
  end if;

  return new;
end;
$function$;

create or replace function public.enforce_driver_verification_guard()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  if auth.uid() is not null
     and coalesce(auth.role(), '') not in ('service_role', 'supabase_admin')
     and public.is_admin() is not true
  then
    if tg_op = 'INSERT'
       and new.verification_status is distinct from 'PENDING'::public.verification_status
    then
      raise exception 'Only an administrator can approve a driver.';
    end if;

    if tg_op = 'UPDATE'
       and new.verification_status is distinct from old.verification_status
       and new.verification_status is distinct from 'PENDING'::public.verification_status
    then
      raise exception 'Only an administrator can change driver verification status.';
    end if;

    if tg_op = 'UPDATE'
       and (
         new.license_number is distinct from old.license_number
         or new.license_expiry is distinct from old.license_expiry
       )
    then
      new.verification_status := 'PENDING'::public.verification_status;
      new.online_status := false;
    end if;

    if tg_op = 'UPDATE'
       and new.verification_status = 'PENDING'::public.verification_status
       and old.verification_status is distinct from 'PENDING'::public.verification_status
    then
      new.online_status := false;
    end if;
  end if;

  if new.verification_status = 'APPROVED'::public.verification_status then
    if new.license_number is null or btrim(new.license_number) = '' then
      raise exception 'Driver cannot be approved without a valid license number.';
    end if;

    if new.license_expiry is null or new.license_expiry < current_date then
      raise exception 'Driver cannot be approved because the driving licence is missing or expired.';
    end if;

    if public.driver_has_valid_required_documents(new.id) is not true then
      raise exception 'Driver cannot be approved because required documents are missing, pending, rejected, or expired.';
    end if;
  end if;

  if new.verification_status in (
    'REJECTED'::public.verification_status,
    'SUSPENDED'::public.verification_status,
    'EXPIRED'::public.verification_status
  ) then
    new.online_status := false;
  end if;

  return new;
end;
$function$;
