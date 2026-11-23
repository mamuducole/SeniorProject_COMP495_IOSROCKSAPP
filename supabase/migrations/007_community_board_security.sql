-- 007_community_board_security.sql
-- Community Board (ROCKS Connect Phase 1) hardening.
--
-- * Stops members from escalating their own role/chapter through the profile UPDATE policy.
-- * Replaces the "read every profile column" policy with a view that omits private
--   columns (email), so feed attribution and the directory no longer expose member emails.
-- * Restricts feed writes to non-guest members, adds author-only post editing,
--   and bounds post/comment length.
--
-- Apply to a development or staging project and run the verification checklist in
-- README.md before applying to production.

-- Profile privilege guard ------------------------------------------------------

create or replace function public.guard_profile_privileged_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    -- API requests run as the authenticated/anon roles; dashboard, migrations, and
    -- service-role tooling remain able to administer roles and chapters.
    if current_user not in ('authenticated', 'anon') then
        return new;
    end if;

    if tg_op = 'INSERT' then
        if new.role not in ('guest', 'member') then
            raise exception 'Members cannot assign themselves an elevated role.'
                using errcode = '42501';
        end if;
    elsif new.id is distinct from old.id
        or new.role is distinct from old.role
        or new.chapter_id is distinct from old.chapter_id
        or new.email is distinct from old.email then
        raise exception 'Only administrators can change a member''s role, chapter, or email.'
            using errcode = '42501';
    end if;

    return new;
end;
$$;

drop trigger if exists guard_profile_privileged_columns on public.profiles;
create trigger guard_profile_privileged_columns
    before insert or update on public.profiles
    for each row execute function public.guard_profile_privileged_columns();

-- Profile visibility -----------------------------------------------------------

-- Previously every authenticated user could select every column (including email)
-- of every profile. Members keep full access to their own row via
-- "members can read their profile" (001); everyone else goes through this view.
drop policy if exists "members can read member directory" on public.profiles;

create or replace view public.member_public_profiles
with (security_barrier = true)
as
select
    id,
    first_name,
    last_name,
    role,
    rank_title,
    chapter_id,
    bio,
    profile_image_path
from public.profiles;

comment on view public.member_public_profiles is
    'Non-private member attribution for the feed, directory, and mentorship. Never add email or contact columns.';

revoke all on public.member_public_profiles from public, anon;
grant select on public.member_public_profiles to authenticated;

-- Community feed ---------------------------------------------------------------

alter table public.posts add column if not exists edited_at timestamptz;

alter table public.posts drop constraint if exists posts_body_length;
alter table public.posts
    add constraint posts_body_length check (char_length(btrim(body)) between 1 and 2000) not valid;

alter table public.post_comments drop constraint if exists post_comments_body_length;
alter table public.post_comments
    add constraint post_comments_body_length check (char_length(btrim(body)) between 1 and 1000) not valid;

create or replace function public.guard_post_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if current_user in ('authenticated', 'anon')
        and (new.id is distinct from old.id
            or new.author_id is distinct from old.author_id
            or new.kind is distinct from old.kind
            or new.image_path is distinct from old.image_path
            or new.created_at is distinct from old.created_at) then
        raise exception 'Only the text of a post can be edited.'
            using errcode = '42501';
    end if;

    if new.body is distinct from old.body then
        new.edited_at := now();
    else
        new.edited_at := old.edited_at;
    end if;

    return new;
end;
$$;

drop trigger if exists guard_post_update on public.posts;
create trigger guard_post_update
    before update on public.posts
    for each row execute function public.guard_post_update();

-- Guests can read but not write to the board.
drop policy if exists "members can create member posts" on public.posts;
create policy "members can create member posts" on public.posts for insert to authenticated
    with check (
        author_id = auth.uid()
        and kind = 'member'
        and exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.role <> 'guest'
        )
    );

drop policy if exists "authors can edit their member posts" on public.posts;
create policy "authors can edit their member posts" on public.posts for update to authenticated
    using (author_id = auth.uid() and kind = 'member')
    with check (author_id = auth.uid() and kind = 'member');

drop policy if exists "members can like" on public.post_likes;
create policy "members can like" on public.post_likes for insert to authenticated
    with check (
        profile_id = auth.uid()
        and exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.role <> 'guest'
        )
    );

drop policy if exists "members can comment" on public.post_comments;
create policy "members can comment" on public.post_comments for insert to authenticated
    with check (
        author_id = auth.uid()
        and exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.role <> 'guest'
        )
    );
