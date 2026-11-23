create extension if not exists pgcrypto;

create type public.app_role as enum ('guest', 'member', 'mentor', 'chapter_admin', 'national_admin');
create type public.event_category as enum ('national', 'chapter', 'mentorship', 'professional_development', 'networking', 'scholarship', 'community_service', 'conference', 'social');

create table public.chapters (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    short_name text,
    description text,
    city text not null,
    state text,
    country text not null default 'US',
    latitude double precision,
    longitude double precision,
    installation text,
    email text,
    phone text,
    website text,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint chapters_coordinates_pair check ((latitude is null and longitude is null) or (latitude is not null and longitude is not null))
);

create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    first_name text not null,
    last_name text not null,
    email text not null,
    role public.app_role not null default 'member',
    chapter_id uuid references public.chapters(id) on delete set null,
    bio text,
    profile_image_path text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.events (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    description text,
    category public.event_category not null,
    chapter_id uuid references public.chapters(id) on delete set null,
    starts_at timestamptz not null,
    ends_at timestamptz,
    timezone text not null default 'UTC',
    venue_name text,
    address text,
    latitude double precision,
    longitude double precision,
    registration_required boolean not null default false,
    capacity integer,
    registration_deadline timestamptz,
    is_published boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint events_date_order check (ends_at is null or ends_at >= starts_at),
    constraint events_capacity_positive check (capacity is null or capacity > 0),
    constraint events_registration_deadline check (registration_deadline is null or registration_deadline <= starts_at)
);

create table public.event_registrations (
    id uuid primary key default gen_random_uuid(),
    event_id uuid not null references public.events(id) on delete cascade,
    profile_id uuid not null references public.profiles(id) on delete cascade,
    created_at timestamptz not null default now(),
    unique (event_id, profile_id)
);

create index chapters_location_idx on public.chapters (state, city) where is_active = true;
create index events_upcoming_idx on public.events (starts_at) where is_published = true;
create index event_registrations_profile_idx on public.event_registrations (profile_id, created_at desc);

alter table public.chapters enable row level security;
alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.event_registrations enable row level security;

create policy "public can read active chapters" on public.chapters for select using (is_active = true);
create policy "public can read published events" on public.events for select using (is_published = true);
create policy "members can read their profile" on public.profiles for select to authenticated using (id = auth.uid());
create policy "members can update their profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "members can read their registrations" on public.event_registrations for select to authenticated using (profile_id = auth.uid());
create policy "members can register themselves" on public.event_registrations for insert to authenticated with check (profile_id = auth.uid());
create policy "members can cancel their registrations" on public.event_registrations for delete to authenticated using (profile_id = auth.uid());
