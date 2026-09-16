-- ============================================================
-- NOKHA RIDE - PRODUCTION DATABASE SCHEMA
-- Supabase / PostgreSQL
-- Migration: initial_nokha_ride_schema
--
-- IMPORTANT:
-- - NO MOCK DATA
-- - NO DEMO DATA
-- - NO FAKE USERS
-- - NO FAKE VEHICLES
-- - NO FAKE BOOKINGS
-- - NO FAKE PAYMENTS
-- - Production prices are NOT hardcoded here.
-- ============================================================

begin;

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================

create extension if not exists pgcrypto;


-- ============================================================
-- 2. ENUM TYPES
-- ============================================================

do $$
begin

  if not exists (
    select 1 from pg_type where typname = 'user_role'
  ) then
    create type public.user_role as enum (
      'CUSTOMER',
      'OWNER',
      'DRIVER',
      'ADMIN',
      'SUPER_ADMIN',
      'FINANCE',
      'SUPPORT',
      'VERIFICATION'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'account_status'
  ) then
    create type public.account_status as enum (
      'ACTIVE',
      'INACTIVE',
      'SUSPENDED',
      'BLOCKED',
      'DELETED'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'verification_status'
  ) then
    create type public.verification_status as enum (
      'PENDING',
      'APPROVED',
      'REJECTED',
      'SUSPENDED',
      'EXPIRED'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'vehicle_availability_status'
  ) then
    create type public.vehicle_availability_status as enum (
      'AVAILABLE',
      'UNAVAILABLE',
      'IN_SERVICE',
      'MAINTENANCE'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'booking_type'
  ) then
    create type public.booking_type as enum (
      'RIDE_NOW',
      'SCHEDULED',
      'OUTSTATION',
      'EVENT'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'trip_type'
  ) then
    create type public.trip_type as enum (
      'ONE_WAY',
      'ROUND_TRIP',
      'LOCAL'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'booking_status'
  ) then
    create type public.booking_status as enum (
      'REQUESTED',
      'SEARCHING',
      'DRIVER_ASSIGNED',
      'DRIVER_ACCEPTED',
      'DRIVER_ARRIVING',
      'DRIVER_ARRIVED',
      'RIDE_STARTED',
      'RIDE_COMPLETED',
      'PAYMENT_PENDING',
      'PAYMENT_COMPLETED',
      'RATED',
      'CUSTOMER_CANCELLED',
      'DRIVER_CANCELLED',
      'ADMIN_CANCELLED',
      'SYSTEM_CANCELLED'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'payment_status'
  ) then
    create type public.payment_status as enum (
      'CREATED',
      'PENDING',
      'SUCCESS',
      'FAILED',
      'REFUND_PENDING',
      'REFUNDED',
      'PARTIAL_REFUND'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'payout_status'
  ) then
    create type public.payout_status as enum (
      'REQUESTED',
      'PROCESSING',
      'COMPLETED',
      'FAILED',
      'CANCELLED'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'settlement_status'
  ) then
    create type public.settlement_status as enum (
      'PENDING',
      'READY',
      'PROCESSING',
      'SETTLED',
      'FAILED'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'document_type'
  ) then
    create type public.document_type as enum (
      'RC',
      'INSURANCE',
      'PERMIT',
      'FITNESS',
      'DL',
      'AADHAAR',
      'PAN',
      'OTHER'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'document_verification_status'
  ) then
    create type public.document_verification_status as enum (
      'PENDING',
      'APPROVED',
      'REJECTED',
      'EXPIRED'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'event_status'
  ) then
    create type public.event_status as enum (
      'REQUESTED',
      'QUOTED',
      'CONFIRMED',
      'IN_PROGRESS',
      'COMPLETED',
      'CANCELLED'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'event_item_status'
  ) then
    create type public.event_item_status as enum (
      'REQUESTED',
      'ASSIGNING',
      'ASSIGNED',
      'IN_PROGRESS',
      'COMPLETED',
      'CANCELLED'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'notification_type'
  ) then
    create type public.notification_type as enum (
      'BOOKING_REQUESTED',
      'DRIVER_ASSIGNED',
      'DRIVER_ACCEPTED',
      'DRIVER_ARRIVING',
      'DRIVER_ARRIVED',
      'RIDE_STARTED',
      'RIDE_COMPLETED',
      'PAYMENT_SUCCESS',
      'PAYMENT_FAILED',
      'BOOKING_CANCELLED',
      'UPCOMING_BOOKING',
      'DOCUMENT_EXPIRY',
      'PAYOUT',
      'PROMOTION',
      'SYSTEM',
      'SUPPORT'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'support_priority'
  ) then
    create type public.support_priority as enum (
      'LOW',
      'MEDIUM',
      'HIGH',
      'URGENT'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'support_status'
  ) then
    create type public.support_status as enum (
      'OPEN',
      'IN_PROGRESS',
      'WAITING_FOR_USER',
      'RESOLVED',
      'CLOSED'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'discount_type'
  ) then
    create type public.discount_type as enum (
      'PERCENTAGE',
      'FIXED'
    );
  end if;

end
$$;


-- ============================================================
-- 3. COMMON UPDATED_AT FUNCTION
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ============================================================
-- 4. PROFILES
-- ============================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,

  full_name text,
  phone text,
  email text,

  profile_photo_url text,

  date_of_birth date,
  gender text,

  address text,
  city text,
  state text,
  pincode text,

  account_status public.account_status
    not null default 'ACTIVE',

  preferred_language text
    not null default 'hi',

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 5. USER ROLES
-- ============================================================

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  role public.user_role not null,

  created_at timestamptz
    not null default now(),

  unique(user_id, role)
);


-- ============================================================
-- 6. VEHICLE CATEGORIES
-- ============================================================

create table if not exists public.vehicle_categories (
  id uuid primary key default gen_random_uuid(),

  name text not null,
  slug text not null unique,

  description text,
  icon_url text,

  min_seats integer,
  max_seats integer,

  is_passenger_vehicle boolean
    not null default true,

  is_commercial_vehicle boolean
    not null default true,

  -- Bikes are permanently prohibited.
  is_bike boolean
    not null default false
    check (is_bike = false),

  is_active boolean
    not null default true,

  sort_order integer
    not null default 0,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now(),

  check (min_seats is null or min_seats > 0),
  check (max_seats is null or max_seats >= min_seats)
);


-- ============================================================
-- 7. VEHICLES
-- ============================================================

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),

  owner_id uuid not null
    references public.profiles(id)
    on delete restrict,

  category_id uuid not null
    references public.vehicle_categories(id)
    on delete restrict,

  registration_number text not null unique,

  brand text,
  model text,
  variant text,

  manufacturing_year integer,

  fuel_type text,

  seat_capacity integer,

  ac_available boolean
    not null default false,

  color text,

  verification_status public.verification_status
    not null default 'PENDING',

  availability_status public.vehicle_availability_status
    not null default 'UNAVAILABLE',

  is_active boolean
    not null default true,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now(),

  check (seat_capacity is null or seat_capacity > 0),
  check (
    manufacturing_year is null
    or manufacturing_year between 1900 and extract(year from now())::integer + 1
  )
);


-- ============================================================
-- 8. VEHICLE IMAGES
-- ============================================================

create table if not exists public.vehicle_images (
  id uuid primary key default gen_random_uuid(),

  vehicle_id uuid not null
    references public.vehicles(id)
    on delete cascade,

  storage_path text not null,

  image_type text,

  sort_order integer
    not null default 0,

  created_at timestamptz
    not null default now()
);


-- ============================================================
-- 9. VEHICLE DOCUMENTS
-- ============================================================

create table if not exists public.vehicle_documents (
  id uuid primary key default gen_random_uuid(),

  vehicle_id uuid not null
    references public.vehicles(id)
    on delete cascade,

  document_type public.document_type not null,

  document_number text,

  storage_path text not null,

  issued_at date,
  expires_at date,

  verification_status public.document_verification_status
    not null default 'PENDING',

  verified_by uuid
    references public.profiles(id)
    on delete set null,

  verified_at timestamptz,

  rejection_reason text,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 10. DRIVERS
-- ============================================================

create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),

  profile_id uuid not null unique
    references public.profiles(id)
    on delete cascade,

  license_number text unique,

  license_expiry date,

  verification_status public.verification_status
    not null default 'PENDING',

  online_status boolean
    not null default false,

  rating_average numeric(3,2)
    not null default 0
    check (rating_average between 0 and 5),

  completed_rides integer
    not null default 0
    check (completed_rides >= 0),

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 11. DRIVER DOCUMENTS
-- ============================================================

create table if not exists public.driver_documents (
  id uuid primary key default gen_random_uuid(),

  driver_id uuid not null
    references public.drivers(id)
    on delete cascade,

  document_type public.document_type not null,

  document_number text,

  storage_path text not null,

  issued_at date,
  expires_at date,

  verification_status public.document_verification_status
    not null default 'PENDING',

  verified_by uuid
    references public.profiles(id)
    on delete set null,

  verified_at timestamptz,

  rejection_reason text,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 12. DRIVER ↔ VEHICLE ASSIGNMENTS
-- ============================================================

create table if not exists public.driver_vehicle_assignments (
  id uuid primary key default gen_random_uuid(),

  vehicle_id uuid not null
    references public.vehicles(id)
    on delete cascade,

  driver_id uuid not null
    references public.drivers(id)
    on delete cascade,

  assigned_at timestamptz
    not null default now(),

  unassigned_at timestamptz,

  is_active boolean
    not null default true,

  created_at timestamptz
    not null default now()
);


-- ============================================================
-- 13. SERVICE AREAS
-- ============================================================

create table if not exists public.service_areas (
  id uuid primary key default gen_random_uuid(),

  name text not null,
  slug text not null unique,

  area_type text,

  parent_area_id uuid
    references public.service_areas(id)
    on delete set null,

  is_active boolean
    not null default true,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 14. PRICING RULES
-- ============================================================

create table if not exists public.pricing_rules (
  id uuid primary key default gen_random_uuid(),

  service_area_id uuid not null
    references public.service_areas(id)
    on delete restrict,

  vehicle_category_id uuid not null
    references public.vehicle_categories(id)
    on delete restrict,

  booking_type public.booking_type not null,

  base_fare numeric(12,2)
    not null default 0,

  minimum_fare numeric(12,2)
    not null default 0,

  per_km_rate numeric(12,2)
    not null default 0,

  per_minute_rate numeric(12,2)
    not null default 0,

  waiting_rate numeric(12,2)
    not null default 0,

  night_charge numeric(12,2)
    not null default 0,

  extra_km_rate numeric(12,2)
    not null default 0,

  extra_hour_rate numeric(12,2)
    not null default 0,

  effective_from timestamptz
    not null,

  effective_until timestamptz,

  is_active boolean
    not null default true,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now(),

  check (base_fare >= 0),
  check (minimum_fare >= 0),
  check (per_km_rate >= 0),
  check (per_minute_rate >= 0),
  check (waiting_rate >= 0),
  check (night_charge >= 0),
  check (extra_km_rate >= 0),
  check (extra_hour_rate >= 0)
);


-- ============================================================
-- 15. FARE QUOTES
-- ============================================================

create table if not exists public.fare_quotes (
  id uuid primary key default gen_random_uuid(),

  customer_id uuid not null
    references public.profiles(id)
    on delete restrict,

  vehicle_category_id uuid not null
    references public.vehicle_categories(id)
    on delete restrict,

  service_area_id uuid
    references public.service_areas(id)
    on delete set null,

  pickup_latitude numeric(10,7) not null,
  pickup_longitude numeric(10,7) not null,

  destination_latitude numeric(10,7),
  destination_longitude numeric(10,7),

  distance numeric(12,3),
  duration integer,

  base_fare numeric(12,2)
    not null default 0,

  distance_charge numeric(12,2)
    not null default 0,

  time_charge numeric(12,2)
    not null default 0,

  waiting_charge numeric(12,2)
    not null default 0,

  night_charge numeric(12,2)
    not null default 0,

  toll_charge numeric(12,2)
    not null default 0,

  parking_charge numeric(12,2)
    not null default 0,

  other_charge numeric(12,2)
    not null default 0,

  discount numeric(12,2)
    not null default 0,

  tax numeric(12,2)
    not null default 0,

  total_fare numeric(12,2)
    not null default 0,

  expires_at timestamptz
    not null,

  created_at timestamptz
    not null default now(),

  check (total_fare >= 0)
);


-- ============================================================
-- 16. BOOKING NUMBER SEQUENCE
-- ============================================================

create sequence if not exists public.booking_number_seq
  start 100001
  increment 1;


create or replace function public.generate_booking_number()
returns text
language plpgsql
as $$
begin
  return 'NR-' ||
         to_char(current_date, 'YYYYMMDD') ||
         '-' ||
         lpad(nextval('public.booking_number_seq')::text, 6, '0');
end;
$$;


-- ============================================================
-- 17. BOOKINGS
-- ============================================================

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),

  booking_number text
    not null unique
    default public.generate_booking_number(),

  customer_id uuid not null
    references public.profiles(id)
    on delete restrict,

  driver_id uuid
    references public.drivers(id)
    on delete set null,

  vehicle_id uuid
    references public.vehicles(id)
    on delete set null,

  booking_type public.booking_type not null,

  trip_type public.trip_type not null,

  pickup_address text not null,

  pickup_latitude numeric(10,7) not null,
  pickup_longitude numeric(10,7) not null,

  destination_address text,

  destination_latitude numeric(10,7),
  destination_longitude numeric(10,7),

  scheduled_at timestamptz,

  passenger_count integer
    not null default 1
    check (passenger_count > 0),

  estimated_distance numeric(12,3),
  estimated_duration integer,

  fare_quote_id uuid
    references public.fare_quotes(id)
    on delete set null,

  quoted_fare numeric(12,2),

  final_fare numeric(12,2),

  payment_method text,

  payment_status public.payment_status
    not null default 'CREATED',

  booking_status public.booking_status
    not null default 'REQUESTED',

  customer_notes text,

  created_at timestamptz
    not null default now(),

  accepted_at timestamptz,
  driver_arrived_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,

  check (
    quoted_fare is null
    or quoted_fare >= 0
  ),

  check (
    final_fare is null
    or final_fare >= 0
  ),

  check (
    scheduled_at is null
    or booking_type = 'SCHEDULED'
  )
);


-- ============================================================
-- 18. BOOKING STATUS HISTORY
-- ============================================================

create table if not exists public.booking_status_history (
  id uuid primary key default gen_random_uuid(),

  booking_id uuid not null
    references public.bookings(id)
    on delete cascade,

  old_status public.booking_status,

  new_status public.booking_status not null,

  changed_by uuid
    references public.profiles(id)
    on delete set null,

  reason text,

  created_at timestamptz
    not null default now()
);


-- ============================================================
-- 19. PAYMENTS
-- ============================================================

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),

  booking_id uuid not null
    references public.bookings(id)
    on delete restrict,

  customer_id uuid not null
    references public.profiles(id)
    on delete restrict,

  gateway text,

  gateway_order_id text unique,

  gateway_payment_id text unique,

  amount numeric(12,2)
    not null
    check (amount >= 0),

  currency text
    not null default 'INR',

  payment_method text,

  status public.payment_status
    not null default 'CREATED',

  verified_at timestamptz,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 20. PAYMENT EVENTS
-- ============================================================

create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),

  payment_id uuid
    references public.payments(id)
    on delete cascade,

  event_type text not null,

  gateway_event_id text unique,

  payload_reference text,

  signature_verified boolean
    not null default false,

  processed_at timestamptz,

  created_at timestamptz
    not null default now()
);


-- ============================================================
-- 21. REFUNDS
-- ============================================================

create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),

  payment_id uuid not null
    references public.payments(id)
    on delete restrict,

  booking_id uuid not null
    references public.bookings(id)
    on delete restrict,

  amount numeric(12,2)
    not null
    check (amount >= 0),

  reason text,

  gateway_refund_id text unique,

  status public.payment_status
    not null default 'REFUND_PENDING',

  created_at timestamptz
    not null default now(),

  completed_at timestamptz
);


-- ============================================================
-- 22. DRIVER EARNINGS
-- ============================================================

create table if not exists public.driver_earnings (
  id uuid primary key default gen_random_uuid(),

  booking_id uuid not null unique
    references public.bookings(id)
    on delete restrict,

  driver_id uuid not null
    references public.drivers(id)
    on delete restrict,

  gross_amount numeric(12,2)
    not null default 0,

  platform_commission numeric(12,2)
    not null default 0,

  adjustments numeric(12,2)
    not null default 0,

  net_amount numeric(12,2)
    not null default 0,

  settlement_status public.settlement_status
    not null default 'PENDING',

  created_at timestamptz
    not null default now(),

  check (gross_amount >= 0),
  check (platform_commission >= 0)
);


-- ============================================================
-- 23. PAYOUTS
-- ============================================================

create table if not exists public.payouts (
  id uuid primary key default gen_random_uuid(),

  owner_id uuid not null
    references public.profiles(id)
    on delete restrict,

  amount numeric(12,2)
    not null
    check (amount > 0),

  status public.payout_status
    not null default 'REQUESTED',

  payout_reference text unique,

  requested_at timestamptz
    not null default now(),

  processed_at timestamptz,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 24. PAYOUT TRANSACTIONS
-- ============================================================

create table if not exists public.payout_transactions (
  id uuid primary key default gen_random_uuid(),

  payout_id uuid not null
    references public.payouts(id)
    on delete cascade,

  gateway text,

  gateway_transaction_id text unique,

  amount numeric(12,2)
    not null
    check (amount >= 0),

  status public.payout_status
    not null default 'PROCESSING',

  response_reference text,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 25. DRIVER CURRENT LOCATION
-- ============================================================

create table if not exists public.driver_current_locations (
  driver_id uuid primary key
    references public.drivers(id)
    on delete cascade,

  latitude numeric(10,7) not null,
  longitude numeric(10,7) not null,

  heading numeric(7,2),

  speed numeric(10,2),

  accuracy numeric(10,2),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 26. RIDE LOCATION EVENTS
-- ============================================================

create table if not exists public.ride_location_events (
  id uuid primary key default gen_random_uuid(),

  booking_id uuid not null
    references public.bookings(id)
    on delete cascade,

  driver_id uuid not null
    references public.drivers(id)
    on delete cascade,

  latitude numeric(10,7) not null,
  longitude numeric(10,7) not null,

  heading numeric(7,2),

  speed numeric(10,2),

  accuracy numeric(10,2),

  recorded_at timestamptz
    not null default now()
);


-- ============================================================
-- 27. EVENTS
-- ============================================================

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),

  customer_id uuid not null
    references public.profiles(id)
    on delete restrict,

  event_type text,
  event_name text,

  event_date date not null,

  start_time time,
  end_time time,

  venue_address text not null,

  latitude numeric(10,7),
  longitude numeric(10,7),

  passenger_count integer,

  special_requirements text,

  status public.event_status
    not null default 'REQUESTED',

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 28. EVENT BOOKING ITEMS
-- ============================================================

create table if not exists public.event_booking_items (
  id uuid primary key default gen_random_uuid(),

  event_id uuid not null
    references public.events(id)
    on delete cascade,

  vehicle_category_id uuid not null
    references public.vehicle_categories(id)
    on delete restrict,

  quantity integer
    not null
    check (quantity > 0),

  status public.event_item_status
    not null default 'REQUESTED',

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 29. EVENT ITEM ASSIGNMENTS
-- Supports multiple vehicles/drivers for one event requirement.
-- ============================================================

create table if not exists public.event_item_assignments (
  id uuid primary key default gen_random_uuid(),

  event_booking_item_id uuid not null
    references public.event_booking_items(id)
    on delete cascade,

  vehicle_id uuid not null
    references public.vehicles(id)
    on delete restrict,

  driver_id uuid
    references public.drivers(id)
    on delete set null,

  assigned_at timestamptz
    not null default now(),

  unassigned_at timestamptz,

  is_active boolean
    not null default true,

  created_at timestamptz
    not null default now()
);


-- ============================================================
-- 30. NOTIFICATIONS
-- ============================================================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  type public.notification_type not null,

  title text not null,

  body text not null,

  booking_id uuid
    references public.bookings(id)
    on delete set null,

  is_read boolean
    not null default false,

  read_at timestamptz,

  created_at timestamptz
    not null default now()
);


-- ============================================================
-- 31. PUSH DEVICE TOKENS
-- ============================================================

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  token text not null unique,

  platform text,

  is_active boolean
    not null default true,

  last_seen_at timestamptz
    not null default now(),

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 32. RATINGS
-- ============================================================

create table if not exists public.ratings (
  id uuid primary key default gen_random_uuid(),

  booking_id uuid not null
    references public.bookings(id)
    on delete cascade,

  from_user_id uuid not null
    references public.profiles(id)
    on delete restrict,

  to_user_id uuid not null
    references public.profiles(id)
    on delete restrict,

  rating numeric(2,1)
    not null
    check (rating >= 1 and rating <= 5),

  created_at timestamptz
    not null default now(),

  unique(booking_id, from_user_id, to_user_id),

  check (from_user_id <> to_user_id)
);


-- ============================================================
-- 33. REVIEWS
-- ============================================================

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),

  rating_id uuid not null unique
    references public.ratings(id)
    on delete cascade,

  comment text,

  status text
    not null default 'PUBLISHED',

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);


-- ============================================================
-- 34. COUPONS
-- ============================================================

create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),

  code text not null unique,

  discount_type public.discount_type not null,

  discount_value numeric(12,2)
    not null
    check (discount_value >= 0),

  minimum_booking_amount numeric(12,2)
    not null default 0,

  maximum_discount numeric(12,2),

  valid_from timestamptz not null,

  valid_until timestamptz not null,

  usage_limit integer,

  per_user_limit integer
    not null default 1,

  is_active boolean
    not null default true,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now(),

  check (valid_until > valid_from),

  check (
    maximum_discount is null
    or maximum_discount >= 0
  )
);


-- ============================================================
-- 35. COUPON REDEMPTIONS
-- ============================================================

create table if not exists public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),

  coupon_id uuid not null
    references public.coupons(id)
    on delete restrict,

  user_id uuid not null
    references public.profiles(id)
    on delete restrict,

  booking_id uuid not null unique
    references public.bookings(id)
    on delete restrict,

  discount_amount numeric(12,2)
    not null
    check (discount_amount >= 0),

  created_at timestamptz
    not null default now()
);


-- ============================================================
-- 36. SUPPORT TICKETS
-- ============================================================

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  booking_id uuid
    references public.bookings(id)
    on delete set null,

  category text,

  subject text not null,

  description text not null,

  priority public.support_priority
    not null default 'MEDIUM',

  status public.support_status
    not null default 'OPEN',

  assigned_to uuid
    references public.profiles(id)
    on delete set null,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now(),

  resolved_at timestamptz
);


-- ============================================================
-- 37. SUPPORT MESSAGES
-- ============================================================

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),

  ticket_id uuid not null
    references public.support_tickets(id)
    on delete cascade,

  sender_id uuid not null
    references public.profiles(id)
    on delete restrict,

  message text not null,

  attachment_path text,

  created_at timestamptz
    not null default now()
);


-- ============================================================
-- 38. AUDIT LOGS
-- ============================================================

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),

  actor_user_id uuid
    references public.profiles(id)
    on delete set null,

  action text not null,

  entity_type text not null,

  entity_id uuid,

  old_data jsonb,

  new_data jsonb,

  ip_address inet,

  user_agent text,

  created_at timestamptz
    not null default now()
);


-- ============================================================
-- 39. UPDATED_AT TRIGGERS
-- ============================================================

drop trigger if exists trg_profiles_updated_at
on public.profiles;

create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();


drop trigger if exists trg_vehicle_categories_updated_at
on public.vehicle_categories;

create trigger trg_vehicle_categories_updated_at
before update on public.vehicle_categories
for each row execute function public.set_updated_at();


drop trigger if exists trg_vehicles_updated_at
on public.vehicles;

create trigger trg_vehicles_updated_at
before update on public.vehicles
for each row execute function public.set_updated_at();


drop trigger if exists trg_vehicle_documents_updated_at
on public.vehicle_documents;

create trigger trg_vehicle_documents_updated_at
before update on public.vehicle_documents
for each row execute function public.set_updated_at();


drop trigger if exists trg_drivers_updated_at
on public.drivers;

create trigger trg_drivers_updated_at
before update on public.drivers
for each row execute function public.set_updated_at();


drop trigger if exists trg_driver_documents_updated_at
on public.driver_documents;

create trigger trg_driver_documents_updated_at
before update on public.driver_documents
for each row execute function public.set_updated_at();


drop trigger if exists trg_service_areas_updated_at
on public.service_areas;

create trigger trg_service_areas_updated_at
before update on public.service_areas
for each row execute function public.set_updated_at();


drop trigger if exists trg_pricing_rules_updated_at
on public.pricing_rules;

create trigger trg_pricing_rules_updated_at
before update on public.pricing_rules
for each row execute function public.set_updated_at();


drop trigger if exists trg_payments_updated_at
on public.payments;

create trigger trg_payments_updated_at
before update on public.payments
for each row execute function public.set_updated_at();


drop trigger if exists trg_payouts_updated_at
on public.payouts;

create trigger trg_payouts_updated_at
before update on public.payouts
for each row execute function public.set_updated_at();


drop trigger if exists trg_payout_transactions_updated_at
on public.payout_transactions;

create trigger trg_payout_transactions_updated_at
before update on public.payout_transactions
for each row execute function public.set_updated_at();


drop trigger if exists trg_events_updated_at
on public.events;

create trigger trg_events_updated_at
before update on public.events
for each row execute function public.set_updated_at();


drop trigger if exists trg_event_booking_items_updated_at
on public.event_booking_items;

create trigger trg_event_booking_items_updated_at
before update on public.event_booking_items
for each row execute function public.set_updated_at();


drop trigger if exists trg_device_tokens_updated_at
on public.device_tokens;

create trigger trg_device_tokens_updated_at
before update on public.device_tokens
for each row execute function public.set_updated_at();


drop trigger if exists trg_reviews_updated_at
on public.reviews;

create trigger trg_reviews_updated_at
before update on public.reviews
for each row execute function public.set_updated_at();


drop trigger if exists trg_coupons_updated_at
on public.coupons;

create trigger trg_coupons_updated_at
before update on public.coupons
for each row execute function public.set_updated_at();


drop trigger if exists trg_support_tickets_updated_at
on public.support_tickets;

create trigger trg_support_tickets_updated_at
before update on public.support_tickets
for each row execute function public.set_updated_at();


-- ============================================================
-- 40. ROLE CHECK FUNCTION
-- SECURITY DEFINER is used so RLS does not recursively query
-- user_roles through itself.
-- ============================================================

create or replace function public.has_role(
  requested_role public.user_role
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = auth.uid()
      and role = requested_role
  );
$$;


-- ============================================================
-- 41. ADMIN CHECK FUNCTION
-- ============================================================

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = auth.uid()
      and role in (
        'ADMIN',
        'SUPER_ADMIN',
        'FINANCE',
        'SUPPORT',
        'VERIFICATION'
      )
  );
$$;


-- ============================================================
-- 42. AUTO-CREATE PROFILE AFTER AUTH SIGNUP
-- ============================================================

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
    email
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email
  )
  on conflict (id) do nothing;

  return new;
end;
$$;


drop trigger if exists on_auth_user_created
on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();


-- ============================================================
-- 43. INDEXES
-- ============================================================

create index if not exists idx_user_roles_user_id
on public.user_roles(user_id);

create index if not exists idx_vehicles_owner_id
on public.vehicles(owner_id);

create index if not exists idx_vehicles_category_id
on public.vehicles(category_id);

create index if not exists idx_vehicles_status
on public.vehicles(verification_status, availability_status);

create index if not exists idx_vehicle_images_vehicle_id
on public.vehicle_images(vehicle_id);

create index if not exists idx_vehicle_documents_vehicle_id
on public.vehicle_documents(vehicle_id);

create index if not exists idx_vehicle_documents_expiry
on public.vehicle_documents(expires_at);

create index if not exists idx_drivers_profile_id
on public.drivers(profile_id);

create index if not exists idx_drivers_online_status
on public.drivers(online_status);

create index if not exists idx_driver_documents_driver_id
on public.driver_documents(driver_id);

create index if not exists idx_driver_documents_expiry
on public.driver_documents(expires_at);

create index if not exists idx_assignment_vehicle
on public.driver_vehicle_assignments(vehicle_id);

create index if not exists idx_assignment_driver
on public.driver_vehicle_assignments(driver_id);

create index if not exists idx_service_areas_parent
on public.service_areas(parent_area_id);

create index if not exists idx_pricing_rules_lookup
on public.pricing_rules(
  service_area_id,
  vehicle_category_id,
  booking_type,
  is_active
);

create index if not exists idx_fare_quotes_customer
on public.fare_quotes(customer_id);

create index if not exists idx_fare_quotes_expiry
on public.fare_quotes(expires_at);

create index if not exists idx_bookings_customer
on public.bookings(customer_id);

create index if not exists idx_bookings_driver
on public.bookings(driver_id);

create index if not exists idx_bookings_vehicle
on public.bookings(vehicle_id);

create index if not exists idx_bookings_status
on public.bookings(booking_status);

create index if not exists idx_bookings_scheduled_at
on public.bookings(scheduled_at);

create index if not exists idx_bookings_created_at
on public.bookings(created_at);

create index if not exists idx_booking_history_booking
on public.booking_status_history(booking_id);

create index if not exists idx_payments_booking
on public.payments(booking_id);

create index if not exists idx_payments_customer
on public.payments(customer_id);

create index if not exists idx_payments_status
on public.payments(status);

create index if not exists idx_payment_events_payment
on public.payment_events(payment_id);

create index if not exists idx_refunds_booking
on public.refunds(booking_id);

create index if not exists idx_earnings_driver
on public.driver_earnings(driver_id);

create index if not exists idx_earnings_status
on public.driver_earnings(settlement_status);

create index if not exists idx_payouts_owner
on public.payouts(owner_id);

create index if not exists idx_payouts_status
on public.payouts(status);

create index if not exists idx_current_locations_updated
on public.driver_current_locations(updated_at);

create index if not exists idx_ride_locations_booking
on public.ride_location_events(booking_id);

create index if not exists idx_ride_locations_recorded
on public.ride_location_events(recorded_at);

create index if not exists idx_events_customer
on public.events(customer_id);

create index if not exists idx_events_date
on public.events(event_date);

create index if not exists idx_event_items_event
on public.event_booking_items(event_id);

create index if not exists idx_event_items_category
on public.event_booking_items(vehicle_category_id);

create index if not exists idx_event_assignments_item
on public.event_item_assignments(event_booking_item_id);

create index if not exists idx_event_assignments_vehicle
on public.event_item_assignments(vehicle_id);

create index if not exists idx_notifications_user
on public.notifications(user_id);

create index if not exists idx_notifications_unread
on public.notifications(user_id, is_read);

create index if not exists idx_device_tokens_user
on public.device_tokens(user_id);

create index if not exists idx_ratings_booking
on public.ratings(booking_id);

create index if not exists idx_ratings_to_user
on public.ratings(to_user_id);

create index if not exists idx_coupon_redemptions_coupon
on public.coupon_redemptions(coupon_id);

create index if not exists idx_coupon_redemptions_user
on public.coupon_redemptions(user_id);

create index if not exists idx_support_tickets_user
on public.support_tickets(user_id);

create index if not exists idx_support_tickets_status
on public.support_tickets(status);

create index if not exists idx_support_messages_ticket
on public.support_messages(ticket_id);

create index if not exists idx_audit_logs_actor
on public.audit_logs(actor_user_id);

create index if not exists idx_audit_logs_entity
on public.audit_logs(entity_type, entity_id);

create index if not exists idx_audit_logs_created
on public.audit_logs(created_at);


-- ============================================================
-- 44. ENABLE ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.vehicle_categories enable row level security;
alter table public.vehicles enable row level security;
alter table public.vehicle_images enable row level security;
alter table public.vehicle_documents enable row level security;
alter table public.drivers enable row level security;
alter table public.driver_documents enable row level security;
alter table public.driver_vehicle_assignments enable row level security;
alter table public.service_areas enable row level security;
alter table public.pricing_rules enable row level security;
alter table public.fare_quotes enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_status_history enable row level security;
alter table public.payments enable row level security;
alter table public.payment_events enable row level security;
alter table public.refunds enable row level security;
alter table public.driver_earnings enable row level security;
alter table public.payouts enable row level security;
alter table public.payout_transactions enable row level security;
alter table public.driver_current_locations enable row level security;
alter table public.ride_location_events enable row level security;
alter table public.events enable row level security;
alter table public.event_booking_items enable row level security;
alter table public.event_item_assignments enable row level security;
alter table public.notifications enable row level security;
alter table public.device_tokens enable row level security;
alter table public.ratings enable row level security;
alter table public.reviews enable row level security;
alter table public.coupons enable row level security;
alter table public.coupon_redemptions enable row level security;
alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;
alter table public.audit_logs enable row level security;


-- ============================================================
-- 45. PROFILE POLICIES
-- ============================================================

drop policy if exists profiles_select_own
on public.profiles;

create policy profiles_select_own
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
  or public.is_admin()
);


drop policy if exists profiles_update_own
on public.profiles;

create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());


-- ============================================================
-- 46. USER ROLE POLICIES
-- ============================================================

drop policy if exists user_roles_select_own
on public.user_roles;

create policy user_roles_select_own
on public.user_roles
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_admin()
);


-- ============================================================
-- 47. VEHICLE CATEGORY POLICIES
-- ============================================================

drop policy if exists vehicle_categories_select_active
on public.vehicle_categories;

create policy vehicle_categories_select_active
on public.vehicle_categories
for select
to authenticated
using (
  is_active = true
  or public.is_admin()
);


drop policy if exists vehicle_categories_admin_insert
on public.vehicle_categories;

create policy vehicle_categories_admin_insert
on public.vehicle_categories
for insert
to authenticated
with check (
  public.is_admin()
);


drop policy if exists vehicle_categories_admin_update
on public.vehicle_categories;

create policy vehicle_categories_admin_update
on public.vehicle_categories
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());


-- ============================================================
-- 48. VEHICLE POLICIES
-- ============================================================

drop policy if exists vehicles_owner_select
on public.vehicles;

create policy vehicles_owner_select
on public.vehicles
for select
to authenticated
using (
  owner_id = auth.uid()
  or public.is_admin()
  or (
    verification_status = 'APPROVED'
    and is_active = true
  )
);


drop policy if exists vehicles_owner_insert
on public.vehicles;

create policy vehicles_owner_insert
on public.vehicles
for insert
to authenticated
with check (
  owner_id = auth.uid()
);


drop policy if exists vehicles_owner_update
on public.vehicles;

create policy vehicles_owner_update
on public.vehicles
for update
to authenticated
using (
  owner_id = auth.uid()
  or public.is_admin()
)
with check (
  owner_id = auth.uid()
  or public.is_admin()
);


-- ============================================================
-- 49. VEHICLE IMAGE POLICIES
-- ============================================================

drop policy if exists vehicle_images_select
on public.vehicle_images;

create policy vehicle_images_select
on public.vehicle_images
for select
to authenticated
using (
  exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and (
        v.owner_id = auth.uid()
        or public.is_admin()
        or (
          v.verification_status = 'APPROVED'
          and v.is_active = true
        )
      )
  )
);


drop policy if exists vehicle_images_owner_insert
on public.vehicle_images;

create policy vehicle_images_owner_insert
on public.vehicle_images
for insert
to authenticated
with check (
  exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and (
        v.owner_id = auth.uid()
        or public.is_admin()
      )
  )
);


-- ============================================================
-- 50. VEHICLE DOCUMENT POLICIES
-- ============================================================

drop policy if exists vehicle_documents_owner_select
on public.vehicle_documents;

create policy vehicle_documents_owner_select
on public.vehicle_documents
for select
to authenticated
using (
  exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and (
        v.owner_id = auth.uid()
        or public.is_admin()
      )
  )
);


drop policy if exists vehicle_documents_owner_insert
on public.vehicle_documents;

create policy vehicle_documents_owner_insert
on public.vehicle_documents
for insert
to authenticated
with check (
  exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and v.owner_id = auth.uid()
  )
  or public.is_admin()
);


-- ============================================================
-- 51. DRIVER POLICIES
-- ============================================================

drop policy if exists drivers_select
on public.drivers;

create policy drivers_select
on public.drivers
for select
to authenticated
using (
  profile_id = auth.uid()
  or public.is_admin()
  or verification_status = 'APPROVED'
);


drop policy if exists drivers_insert
on public.drivers;

create policy drivers_insert
on public.drivers
for insert
to authenticated
with check (
  profile_id = auth.uid()
  or public.is_admin()
);


drop policy if exists drivers_update
on public.drivers;

create policy drivers_update
on public.drivers
for update
to authenticated
using (
  profile_id = auth.uid()
  or public.is_admin()
)
with check (
  profile_id = auth.uid()
  or public.is_admin()
);


-- ============================================================
-- 52. DRIVER DOCUMENT POLICIES
-- ============================================================

drop policy if exists driver_documents_select
on public.driver_documents;

create policy driver_documents_select
on public.driver_documents
for select
to authenticated
using (
  exists (
    select 1
    from public.drivers d
    where d.id = driver_id
      and (
        d.profile_id = auth.uid()
        or public.is_admin()
      )
  )
);


drop policy if exists driver_documents_insert
on public.driver_documents;

create policy driver_documents_insert
on public.driver_documents
for insert
to authenticated
with check (
  exists (
    select 1
    from public.drivers d
    where d.id = driver_id
      and d.profile_id = auth.uid()
  )
  or public.is_admin()
);


-- ============================================================
-- 53. DRIVER-VEHICLE ASSIGNMENT POLICIES
-- ============================================================

drop policy if exists assignments_select
on public.driver_vehicle_assignments;

create policy assignments_select
on public.driver_vehicle_assignments
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.drivers d
    where d.id = driver_id
      and d.profile_id = auth.uid()
  )
  or exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and v.owner_id = auth.uid()
  )
);


-- ============================================================
-- 54. SERVICE AREA POLICIES
-- ============================================================

drop policy if exists service_areas_select_active
on public.service_areas;

create policy service_areas_select_active
on public.service_areas
for select
to authenticated
using (
  is_active = true
  or public.is_admin()
);


drop policy if exists service_areas_admin_insert
on public.service_areas;

create policy service_areas_admin_insert
on public.service_areas
for insert
to authenticated
with check (public.is_admin());


drop policy if exists service_areas_admin_update
on public.service_areas;

create policy service_areas_admin_update
on public.service_areas
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());


-- ============================================================
-- 55. PRICING POLICY
-- ============================================================

drop policy if exists pricing_rules_select
on public.pricing_rules;

create policy pricing_rules_select
on public.pricing_rules
for select
to authenticated
using (
  (
    is_active = true
    and effective_from <= now()
    and (
      effective_until is null
      or effective_until > now()
    )
  )
  or public.is_admin()
);


drop policy if exists pricing_rules_admin_insert
on public.pricing_rules;

create policy pricing_rules_admin_insert
on public.pricing_rules
for insert
to authenticated
with check (public.is_admin());


drop policy if exists pricing_rules_admin_update
on public.pricing_rules;

create policy pricing_rules_admin_update
on public.pricing_rules
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());


-- ============================================================
-- 56. FARE QUOTE POLICIES
-- ============================================================

drop policy if exists fare_quotes_customer_select
on public.fare_quotes;

create policy fare_quotes_customer_select
on public.fare_quotes
for select
to authenticated
using (
  customer_id = auth.uid()
  or public.is_admin()
);


-- ============================================================
-- 57. BOOKING POLICIES
-- ============================================================

drop policy if exists bookings_customer_select
on public.bookings;

create policy bookings_customer_select
on public.bookings
for select
to authenticated
using (
  customer_id = auth.uid()
  or public.is_admin()
  or exists (
    select 1
    from public.drivers d
    where d.id = driver_id
      and d.profile_id = auth.uid()
  )
  or exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and v.owner_id = auth.uid()
  )
);


drop policy if exists bookings_customer_insert
on public.bookings;

create policy bookings_customer_insert
on public.bookings
for insert
to authenticated
with check (
  customer_id = auth.uid()
);


-- ============================================================
-- 58. BOOKING HISTORY
-- ============================================================

drop policy if exists booking_history_select
on public.booking_status_history;

create policy booking_history_select
on public.booking_status_history
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.bookings b
    where b.id = booking_id
      and (
        b.customer_id = auth.uid()
        or exists (
          select 1
          from public.drivers d
          where d.id = b.driver_id
            and d.profile_id = auth.uid()
        )
      )
  )
);


-- ============================================================
-- 59. PAYMENT POLICIES
-- ============================================================

drop policy if exists payments_customer_select
on public.payments;

create policy payments_customer_select
on public.payments
for select
to authenticated
using (
  customer_id = auth.uid()
  or public.is_admin()
);


-- ============================================================
-- 60. PAYMENT EVENTS
-- ============================================================

drop policy if exists payment_events_admin_select
on public.payment_events;

create policy payment_events_admin_select
on public.payment_events
for select
to authenticated
using (public.is_admin());


-- ============================================================
-- 61. REFUND POLICIES
-- ============================================================

drop policy if exists refunds_customer_select
on public.refunds;

create policy refunds_customer_select
on public.refunds
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.bookings b
    where b.id = booking_id
      and b.customer_id = auth.uid()
  )
);


-- ============================================================
-- 62. DRIVER EARNINGS
-- ============================================================

drop policy if exists driver_earnings_select
on public.driver_earnings;

create policy driver_earnings_select
on public.driver_earnings
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.drivers d
    where d.id = driver_id
      and d.profile_id = auth.uid()
  )
);


-- ============================================================
-- 63. PAYOUT POLICIES
-- ============================================================

drop policy if exists payouts_owner_select
on public.payouts;

create policy payouts_owner_select
on public.payouts
for select
to authenticated
using (
  owner_id = auth.uid()
  or public.is_admin()
);


drop policy if exists payouts_owner_insert
on public.payouts;

create policy payouts_owner_insert
on public.payouts
for insert
to authenticated
with check (
  owner_id = auth.uid()
);


-- ============================================================
-- 64. DRIVER CURRENT LOCATION
-- ============================================================

drop policy if exists driver_current_locations_select
on public.driver_current_locations;

create policy driver_current_locations_select
on public.driver_current_locations
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.drivers d
    where d.id = driver_id
      and d.profile_id = auth.uid()
  )
  or exists (
    select 1
    from public.bookings b
    where b.driver_id = driver_id
      and b.customer_id = auth.uid()
      and b.booking_status in (
        'DRIVER_ASSIGNED',
        'DRIVER_ACCEPTED',
        'DRIVER_ARRIVING',
        'DRIVER_ARRIVED',
        'RIDE_STARTED'
      )
  )
);


-- ============================================================
-- 65. RIDE LOCATION EVENTS
-- ============================================================

drop policy if exists ride_location_events_select
on public.ride_location_events;

create policy ride_location_events_select
on public.ride_location_events
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.drivers d
    where d.id = driver_id
      and d.profile_id = auth.uid()
  )
  or exists (
    select 1
    from public.bookings b
    where b.id = booking_id
      and b.customer_id = auth.uid()
  )
);


-- ============================================================
-- 66. EVENT POLICIES
-- ============================================================

drop policy if exists events_customer_select
on public.events;

create policy events_customer_select
on public.events
for select
to authenticated
using (
  customer_id = auth.uid()
  or public.is_admin()
);


drop policy if exists events_customer_insert
on public.events;

create policy events_customer_insert
on public.events
for insert
to authenticated
with check (
  customer_id = auth.uid()
);


-- ============================================================
-- 67. EVENT ITEM POLICIES
-- ============================================================

drop policy if exists event_items_select
on public.event_booking_items;

create policy event_items_select
on public.event_booking_items
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.events e
    where e.id = event_id
      and e.customer_id = auth.uid()
  )
);


-- ============================================================
-- 68. EVENT ASSIGNMENT POLICIES
-- ============================================================

drop policy if exists event_assignments_select
on public.event_item_assignments;

create policy event_assignments_select
on public.event_item_assignments
for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1
    from public.event_booking_items ebi
    join public.events e
      on e.id = ebi.event_id
    where ebi.id = event_booking_item_id
      and e.customer_id = auth.uid()
  )
  or exists (
    select 1
    from public.drivers d
    where d.id = driver_id
      and d.profile_id = auth.uid()
  )
);


-- ============================================================
-- 69. NOTIFICATION POLICIES
-- ============================================================

drop policy if exists notifications_select_own
on public.notifications;

create policy notifications_select_own
on public.notifications
for select
to authenticated
using (
  user_id = auth.uid()
);


drop policy if exists notifications_update_own
on public.notifications;

create policy notifications_update_own
on public.notifications
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);


-- ============================================================
-- 70. DEVICE TOKEN POLICIES
-- ============================================================

drop policy if exists device_tokens_own_select
on public.device_tokens;

create policy device_tokens_own_select
on public.device_tokens
for select
to authenticated
using (
  user_id = auth.uid()
);


drop policy if exists device_tokens_own_insert
on public.device_tokens;

create policy device_tokens_own_insert
on public.device_tokens
for insert
to authenticated
with check (
  user_id = auth.uid()
);


drop policy if exists device_tokens_own_update
on public.device_tokens;

create policy device_tokens_own_update
on public.device_tokens
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);


-- ============================================================
-- 71. RATINGS
-- ============================================================

drop policy if exists ratings_select
on public.ratings;

create policy ratings_select
on public.ratings
for select
to authenticated
using (
  from_user_id = auth.uid()
  or to_user_id = auth.uid()
  or public.is_admin()
);


drop policy if exists ratings_insert
on public.ratings;

create policy ratings_insert
on public.ratings
for insert
to authenticated
with check (
  from_user_id = auth.uid()
);


-- ============================================================
-- 72. REVIEWS
-- ============================================================

drop policy if exists reviews_select
on public.reviews;

create policy reviews_select
on public.reviews
for select
to authenticated
using (
  status = 'PUBLISHED'
  or public.is_admin()
);


drop policy if exists reviews_update
on public.reviews;

create policy reviews_update
on public.reviews
for update
to authenticated
using (
  public.is_admin()
)
with check (
  public.is_admin()
);


-- ============================================================
-- 73. COUPONS
-- ============================================================

drop policy if exists coupons_select_active
on public.coupons;

create policy coupons_select_active
on public.coupons
for select
to authenticated
using (
  (
    is_active = true
    and valid_from <= now()
    and valid_until >= now()
  )
  or public.is_admin()
);


drop policy if exists coupons_admin_insert
on public.coupons;

create policy coupons_admin_insert
on public.coupons
for insert
to authenticated
with check (public.is_admin());


drop policy if exists coupons_admin_update
on public.coupons;

create policy coupons_admin_update
on public.coupons
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());


-- ============================================================
-- 74. COUPON REDEMPTIONS
-- ============================================================

drop policy if exists coupon_redemptions_own_select
on public.coupon_redemptions;

create policy coupon_redemptions_own_select
on public.coupon_redemptions
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_admin()
);


-- ============================================================
-- 75. SUPPORT TICKETS
-- ============================================================

drop policy if exists support_tickets_select
on public.support_tickets;

create policy support_tickets_select
on public.support_tickets
for select
to authenticated
using (
  user_id = auth.uid()
  or assigned_to = auth.uid()
  or public.is_admin()
);


drop policy if exists support_tickets_insert
on public.support_tickets;

create policy support_tickets_insert
on public.support_tickets
for insert
to authenticated
with check (
  user_id = auth.uid()
);


-- ============================================================
-- 76. SUPPORT MESSAGES
-- ============================================================

drop policy if exists support_messages_select
on public.support_messages;

create policy support_messages_select
on public.support_messages
for select
to authenticated
using (
  public.is_admin()
  or sender_id = auth.uid()
  or exists (
    select 1
    from public.support_tickets st
    where st.id = ticket_id
      and (
        st.user_id = auth.uid()
        or st.assigned_to = auth.uid()
      )
  )
);


drop policy if exists support_messages_insert
on public.support_messages;

create policy support_messages_insert
on public.support_messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
);


-- ============================================================
-- 77. AUDIT LOGS
-- ============================================================

drop policy if exists audit_logs_admin_select
on public.audit_logs;

create policy audit_logs_admin_select
on public.audit_logs
for select
to authenticated
using (
  public.is_admin()
);


-- ============================================================
-- 78. DEFAULT PRIVILEGES
-- ============================================================

revoke all on all tables
in schema public
from anon;

grant usage on schema public
to authenticated;

grant select, insert, update, delete
on all tables
in schema public
to authenticated;

grant usage, select
on all sequences
in schema public
to authenticated;


-- ============================================================
-- 79. FUNCTION PRIVILEGES
-- ============================================================

revoke all on function public.has_role(public.user_role)
from public;

grant execute
on function public.has_role(public.user_role)
to authenticated;

revoke all on function public.is_admin()
from public;

grant execute
on function public.is_admin()
to authenticated;


-- ============================================================
-- 80. FINAL SCHEMA COMPLETE
-- ============================================================

commit;