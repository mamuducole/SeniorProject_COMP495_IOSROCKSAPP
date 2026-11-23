-- 008_profile_creation.sql
-- Automatically create a public profile whenever a Supabase Auth user is created.
-- This closes the missing-profile blocker for sign-up and restores role lookups
-- after email confirmation and session restoration.

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    email_address text;
    first_name text;
    last_name text;
begin
    email_address := coalesce(new.email, '');
    first_name := nullif(trim(coalesce(new.raw_user_meta_data ->> 'first_name', '')), '');
    last_name := nullif(trim(coalesce(new.raw_user_meta_data ->> 'last_name', '')), '');

    if first_name is null then
        first_name := nullif(split_part(email_address, '@', 1), '');
    end if;
    if first_name is null then
        first_name := 'ROCKS';
    end if;
    if last_name is null then
        last_name := 'Member';
    end if;

    insert into public.profiles (
        id,
        first_name,
        last_name,
        email,
        role
    )
    values (
        new.id,
        first_name,
        last_name,
        email_address,
        'member'
    )
    on conflict (id) do nothing;

    return new;
end;
$$;

comment on function public.handle_new_auth_user() is
    'Security-definer trigger for auth.users inserts. Creates an ordinary member profile and never elevates roles.';

revoke all on function public.handle_new_auth_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_auth_user();

-- Backfill profiles for accounts that were created before this trigger existed.
insert into public.profiles (id, first_name, last_name, email, role)
select
    u.id,
    coalesce(
        nullif(trim(u.raw_user_meta_data ->> 'first_name'), ''),
        nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
        'ROCKS'
    ),
    coalesce(
        nullif(trim(u.raw_user_meta_data ->> 'last_name'), ''),
        'Member'
    ),
    coalesce(u.email, ''),
    'member'
from auth.users u
where not exists (
    select 1
    from public.profiles p
    where p.id = u.id
);
