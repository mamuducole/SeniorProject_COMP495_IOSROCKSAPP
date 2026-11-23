-- 012_membership_approval_and_moderation.sql
-- Forward-only. Test in staging with synthetic accounts before requesting production approval.
--
-- * Membership approval: new accounts are created as role 'guest' + status 'pending'.
--   A constraint keeps "approved" equivalent to "role <> 'guest'", so every existing
--   policy and RPC that excludes guests now excludes unapproved accounts as well.
--   Existing non-guest profiles are backfilled as approved (owner decision); existing
--   guest profiles become pending.
-- * Unapproved accounts can no longer read the community board or the member
--   attribution view.
-- * Administrators review applications through checked, audited functions.
-- * Members can report posts/comments; national administrators moderate.
-- * Members can delete their own account.

-- Membership status ---------------------------------------------------------------

create type public.membership_status as enum ('pending', 'approved', 'declined', 'suspended');

alter table public.profiles
    add column membership_status public.membership_status not null default 'pending',
    add column requested_chapter_id uuid references public.chapters(id) on delete set null,
    add column terms_accepted_at timestamptz,
    add column terms_version text,
    add column membership_reviewed_at timestamptz,
    add column membership_reviewed_by uuid references public.profiles(id) on delete set null;

update public.profiles set membership_status = 'approved' where role <> 'guest';

alter table public.profiles
    add constraint profiles_membership_role_consistent
    check ((membership_status = 'approved') = (role <> 'guest'));

comment on column public.profiles.membership_status is
    'Organizational membership review state. Only approved members have a non-guest role.';
comment on column public.profiles.requested_chapter_id is
    'Chapter chosen during registration. Assigned to chapter_id only when an administrator approves.';

create index profiles_membership_review_idx
    on public.profiles (membership_status, requested_chapter_id, created_at);

create function public.is_approved_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.membership_status = 'approved' and p.role <> 'guest'
    )
$$;
revoke all on function public.is_approved_member() from public, anon;
grant execute on function public.is_approved_member() to authenticated;

-- Registration --------------------------------------------------------------------

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
    email_address text := coalesce(new.email, '');
    given_name text;
    family_name text;
    chapter_text text;
    chapter uuid;
    accepted boolean;
    version text;
begin
    given_name := left(nullif(trim(coalesce(metadata ->> 'first_name', '')), ''), 80);
    family_name := left(nullif(trim(coalesce(metadata ->> 'last_name', '')), ''), 80);
    if given_name is null then
        given_name := coalesce(nullif(split_part(email_address, '@', 1), ''), 'ROCKS');
    end if;
    if family_name is null then
        family_name := 'Member';
    end if;

    chapter_text := metadata ->> 'requested_chapter_id';
    if chapter_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        select c.id into chapter from public.chapters c
        where c.id = chapter_text::uuid and c.is_active;
    end if;

    accepted := lower(coalesce(metadata ->> 'terms_accepted', '')) = 'true';
    version := left(nullif(trim(coalesce(metadata ->> 'terms_version', '')), ''), 40);

    insert into public.profiles (
        id, first_name, last_name, email, role, membership_status,
        requested_chapter_id, terms_accepted_at, terms_version
    )
    values (
        new.id, given_name, family_name, email_address, 'guest', 'pending',
        chapter,
        case when accepted and version is not null then now() end,
        case when accepted then version end
    )
    on conflict (id) do nothing;

    return new;
end;
$$;

comment on function public.handle_new_auth_user() is
    'Creates a pending guest profile for each new Auth user. Never approves membership or elevates roles.';
revoke all on function public.handle_new_auth_user() from public, anon, authenticated;

create or replace function public.guard_profile_privileged_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if current_user not in ('authenticated', 'anon') then
        return new;
    end if;

    if tg_op = 'INSERT' then
        if new.role <> 'guest' or new.membership_status <> 'pending' then
            raise exception 'Members cannot assign themselves a role or membership status.'
                using errcode = '42501';
        end if;
    elsif new.id is distinct from old.id
        or new.role is distinct from old.role
        or new.chapter_id is distinct from old.chapter_id
        or new.email is distinct from old.email
        or new.membership_status is distinct from old.membership_status
        or new.requested_chapter_id is distinct from old.requested_chapter_id
        or new.terms_accepted_at is distinct from old.terms_accepted_at
        or new.terms_version is distinct from old.terms_version
        or new.membership_reviewed_at is distinct from old.membership_reviewed_at
        or new.membership_reviewed_by is distinct from old.membership_reviewed_by
        or new.created_at is distinct from old.created_at then
        raise exception 'Only administrators can change membership, role, chapter, or email.'
            using errcode = '42501';
    end if;

    new.updated_at := now();
    return new;
end;
$$;

-- Read access for unapproved accounts ---------------------------------------------

drop policy if exists "members can read posts" on public.posts;
create policy "approved members can read posts" on public.posts
    for select to authenticated using (public.is_approved_member());

drop policy if exists "members can read likes" on public.post_likes;
create policy "approved members can read likes" on public.post_likes
    for select to authenticated using (public.is_approved_member());

drop policy if exists "members can read comments" on public.post_comments;
create policy "approved members can read comments" on public.post_comments
    for select to authenticated using (public.is_approved_member());

create or replace view public.member_public_profiles
with (security_barrier = true)
as
select
    p.id,
    p.first_name,
    p.last_name,
    p.role,
    p.rank_title,
    case when p.id = auth.uid() then p.chapter_id else null end as chapter_id,
    case when p.id = auth.uid() then p.bio else null end as bio,
    p.profile_image_path
from public.profiles p
where p.id = auth.uid()
   or (p.membership_status = 'approved' and public.is_approved_member());

comment on view public.member_public_profiles is
    'Attribution view. Approved members see other approved members; biography and chapter are visible only to their owner.';
revoke all on public.member_public_profiles from public, anon;
grant select on public.member_public_profiles to authenticated;

-- Membership administration -------------------------------------------------------

create function public.admin_list_membership_applications(
    p_status public.membership_status default 'pending'
)
returns table (
    profile_id uuid,
    first_name text,
    last_name text,
    email text,
    requested_chapter_id uuid,
    requested_chapter_name text,
    status public.membership_status,
    terms_accepted_at timestamptz,
    terms_version text,
    created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_role public.app_role;
    v_chapter uuid;
begin
    select me.role, me.chapter_id into v_role, v_chapter
    from public.profiles me
    where me.id = auth.uid() and me.membership_status = 'approved';

    if v_role is null or v_role not in ('chapter_admin', 'national_admin') then
        raise exception 'Administrator access required' using errcode = '42501';
    end if;

    return query
    select p.id, p.first_name, p.last_name, p.email, p.requested_chapter_id, c.name,
           p.membership_status, p.terms_accepted_at, p.terms_version, p.created_at
    from public.profiles p
    left join public.chapters c on c.id = p.requested_chapter_id
    where p.membership_status = p_status
      and p.id <> auth.uid()
      and p.role not in ('chapter_admin', 'national_admin')
      and (v_role = 'national_admin'
           or (v_chapter is not null and coalesce(p.requested_chapter_id, p.chapter_id) = v_chapter))
    order by p.created_at
    limit 200;
end;
$$;

create function public.admin_review_membership(p_profile_id uuid, p_decision text)
returns public.membership_status
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_role public.app_role;
    v_chapter uuid;
    v_target public.profiles%rowtype;
    v_new public.membership_status;
begin
    select me.role, me.chapter_id into v_role, v_chapter
    from public.profiles me
    where me.id = auth.uid() and me.membership_status = 'approved';

    if v_role is null or v_role not in ('chapter_admin', 'national_admin') then
        raise exception 'Administrator access required' using errcode = '42501';
    end if;
    if p_profile_id is null or p_profile_id = auth.uid() then
        raise exception 'Administrators cannot review their own membership' using errcode = '42501';
    end if;

    select * into v_target from public.profiles where id = p_profile_id for update;
    if not found
        or v_target.role in ('chapter_admin', 'national_admin')
        or (v_role = 'chapter_admin' and (v_chapter is null
            or coalesce(v_target.requested_chapter_id, v_target.chapter_id) is distinct from v_chapter)) then
        raise exception 'Member not found or outside your administrative scope' using errcode = '42501';
    end if;

    v_new := case p_decision
        when 'approve' then 'approved'::public.membership_status
        when 'decline' then 'declined'::public.membership_status
        when 'suspend' then 'suspended'::public.membership_status
    end;
    if v_new is null then
        raise exception 'Unknown membership decision' using errcode = '22023';
    end if;
    if (v_new = 'approved' and v_target.membership_status = 'approved')
        or (v_new = 'declined' and v_target.membership_status <> 'pending')
        or (v_new = 'suspended' and v_target.membership_status <> 'approved') then
        raise exception 'That decision does not apply to this membership status' using errcode = '22023';
    end if;

    update public.profiles set
        membership_status = v_new,
        role = case
            when v_new = 'approved' then case when v_target.role = 'guest' then 'member'::public.app_role else v_target.role end
            else 'guest'::public.app_role
        end,
        chapter_id = case
            when v_new = 'approved' then coalesce(v_target.chapter_id, v_target.requested_chapter_id)
            else v_target.chapter_id
        end,
        membership_reviewed_at = now(),
        membership_reviewed_by = auth.uid()
    where id = p_profile_id;

    if v_new <> 'approved' then
        update public.mentorship_profiles set directory_visible = false where profile_id = p_profile_id;
    end if;

    insert into public.notifications (profile_id, title, body)
    values (
        p_profile_id,
        'Membership update',
        case v_new
            when 'approved' then 'Your ROCKS Connect membership was approved.'
            when 'declined' then 'Your ROCKS Connect membership application was not approved.'
            else 'Your ROCKS Connect membership access was suspended.'
        end
    );
    return v_new;
end;
$$;

-- Moderation ----------------------------------------------------------------------

create type public.content_report_status as enum ('open', 'resolved', 'dismissed');

create table public.content_reports (
    id uuid primary key default gen_random_uuid(),
    reporter_id uuid not null references public.profiles(id) on delete cascade,
    post_id uuid references public.posts(id) on delete cascade,
    comment_id uuid references public.post_comments(id) on delete cascade,
    reason text not null,
    details text,
    status public.content_report_status not null default 'open',
    created_at timestamptz not null default now(),
    resolved_at timestamptz,
    resolved_by uuid references public.profiles(id) on delete set null,
    constraint content_reports_one_target check ((post_id is null) <> (comment_id is null)),
    constraint content_reports_reason check (reason in ('spam', 'harassment', 'inappropriate', 'misinformation', 'other')),
    constraint content_reports_details_length check (details is null or char_length(details) <= 500)
);

create unique index content_reports_one_open_per_reporter
    on public.content_reports (reporter_id, coalesce(post_id, comment_id))
    where status = 'open';
create index content_reports_queue_idx on public.content_reports (status, created_at desc);

alter table public.content_reports enable row level security;
revoke all on public.content_reports from public, anon;
grant select, insert on public.content_reports to authenticated;

create policy "approved members can report content" on public.content_reports
    for insert to authenticated
    with check (
        reporter_id = auth.uid()
        and status = 'open'
        and resolved_at is null
        and resolved_by is null
        and public.is_approved_member()
    );

create policy "reporters and national administrators can read reports" on public.content_reports
    for select to authenticated
    using (
        reporter_id = auth.uid()
        or exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.role = 'national_admin' and p.membership_status = 'approved'
        )
    );

create policy "national administrators can remove posts" on public.posts
    for delete to authenticated
    using (exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role = 'national_admin' and p.membership_status = 'approved'
    ));

create policy "national administrators can remove comments" on public.post_comments
    for delete to authenticated
    using (exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role = 'national_admin' and p.membership_status = 'approved'
    ));

create function public.admin_list_open_reports()
returns table (
    report_id uuid,
    post_id uuid,
    comment_id uuid,
    reason text,
    details text,
    reported_at timestamptz,
    content text,
    author_name text,
    report_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if not exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role = 'national_admin' and p.membership_status = 'approved'
    ) then
        raise exception 'National administrator access required' using errcode = '42501';
    end if;

    return query
    select r.id, r.post_id, r.comment_id, r.reason, r.details, r.created_at,
           left(coalesce(po.body, co.body), 500),
           a.first_name || ' ' || a.last_name,
           count(*) over (partition by coalesce(r.post_id, r.comment_id))
    from public.content_reports r
    left join public.posts po on po.id = r.post_id
    left join public.post_comments co on co.id = r.comment_id
    left join public.profiles a on a.id = coalesce(po.author_id, co.author_id)
    where r.status = 'open'
    order by r.created_at
    limit 200;
end;
$$;

create function public.admin_resolve_report(p_report_id uuid, p_status public.content_report_status)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if not exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role = 'national_admin' and p.membership_status = 'approved'
    ) then
        raise exception 'National administrator access required' using errcode = '42501';
    end if;
    if p_status is null or p_status = 'open' then
        raise exception 'Choose resolved or dismissed' using errcode = '22023';
    end if;
    update public.content_reports
    set status = p_status, resolved_at = now(), resolved_by = auth.uid()
    where id = p_report_id and status = 'open';
    if not found then
        raise exception 'Open report not found' using errcode = '22023';
    end if;
end;
$$;

-- Notifications: members may only change the read flag ----------------------------

create function public.guard_notification_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if current_user in ('authenticated', 'anon')
        and (new.id is distinct from old.id
            or new.profile_id is distinct from old.profile_id
            or new.title is distinct from old.title
            or new.body is distinct from old.body
            or new.route is distinct from old.route
            or new.created_at is distinct from old.created_at) then
        raise exception 'Only the read state of a notification can be changed.' using errcode = '42501';
    end if;
    return new;
end;
$$;

create trigger guard_notification_update
    before update on public.notifications
    for each row execute function public.guard_notification_update();

create index notifications_profile_created_idx on public.notifications (profile_id, created_at desc);

-- Account deletion ----------------------------------------------------------------

create function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Authentication required' using errcode = '42501';
    end if;
    if exists (select 1 from public.profiles where id = v_uid and role = 'national_admin')
        and not exists (
            select 1 from public.profiles
            where role = 'national_admin' and membership_status = 'approved' and id <> v_uid
        ) then
        raise exception 'The last national administrator cannot delete this account' using errcode = '42501';
    end if;
    delete from auth.users where id = v_uid;
end;
$$;

-- Audit ---------------------------------------------------------------------------

create or replace function public.record_administrative_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    target_id uuid;
    scope_chapter uuid;
begin
    if tg_table_name = 'profiles' then
        if tg_op <> 'UPDATE' or (new.role is not distinct from old.role
            and new.chapter_id is not distinct from old.chapter_id
            and new.membership_status is not distinct from old.membership_status) then
            return coalesce(new, old);
        end if;
        target_id := new.id;
        scope_chapter := coalesce(new.chapter_id, new.requested_chapter_id);
    elsif tg_table_name = 'posts' then
        -- Member posts are audited only when removed by someone other than the author.
        if coalesce(new.kind, old.kind) = 'member'
            and not (tg_op = 'DELETE' and old.author_id is distinct from auth.uid()) then
            return coalesce(new, old);
        end if;
        target_id := coalesce(new.id, old.id);
    elsif tg_table_name = 'post_comments' then
        if not (tg_op = 'DELETE' and old.author_id is distinct from auth.uid()) then
            return coalesce(new, old);
        end if;
        target_id := old.id;
    elsif tg_table_name = 'chapters' then
        target_id := coalesce(new.id, old.id);
        scope_chapter := target_id;
    elsif tg_table_name = 'events' then
        target_id := coalesce(new.id, old.id);
        if tg_op = 'UPDATE' and new.chapter_id is distinct from old.chapter_id then
            scope_chapter := null;
        else
            scope_chapter := coalesce(new.chapter_id, old.chapter_id);
        end if;
    else
        target_id := coalesce(new.id, old.id);
    end if;

    insert into public.administrative_activity
        (actor_id, action, resource_type, resource_id, chapter_id)
    values (auth.uid(), lower(tg_op), tg_table_name, target_id, scope_chapter);
    return coalesce(new, old);
end;
$$;
revoke all on function public.record_administrative_activity() from public, anon, authenticated;

create trigger audit_moderated_comments after delete on public.post_comments
    for each row execute function public.record_administrative_activity();
create trigger audit_content_reports after update on public.content_reports
    for each row execute function public.record_administrative_activity();

-- Feed performance ----------------------------------------------------------------

create index if not exists posts_author_idx on public.posts (author_id);
create index if not exists post_likes_profile_idx on public.post_likes (profile_id);
create index if not exists post_comments_author_idx on public.post_comments (author_id);

-- Function grants -----------------------------------------------------------------

revoke all on function public.admin_list_membership_applications(public.membership_status) from public, anon;
revoke all on function public.admin_review_membership(uuid, text) from public, anon;
revoke all on function public.admin_list_open_reports() from public, anon;
revoke all on function public.admin_resolve_report(uuid, public.content_report_status) from public, anon;
revoke all on function public.delete_own_account() from public, anon;
revoke all on function public.guard_notification_update() from public, anon, authenticated;
grant execute on function public.admin_list_membership_applications(public.membership_status) to authenticated;
grant execute on function public.admin_review_membership(uuid, text) to authenticated;
grant execute on function public.admin_list_open_reports() to authenticated;
grant execute on function public.admin_resolve_report(uuid, public.content_report_status) to authenticated;
grant execute on function public.delete_own_account() to authenticated;
