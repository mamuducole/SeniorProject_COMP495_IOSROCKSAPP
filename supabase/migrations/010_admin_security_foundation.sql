-- Phase 4 security foundation. Test in staging before any production deployment.
-- This does not implement membership verification or content publishing workflows.

create function public.admin_phase4_ready() returns boolean
language sql stable set search_path = ''
as $$
    select exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role in ('chapter_admin', 'national_admin')
    )
$$;
revoke all on function public.admin_phase4_ready() from public, anon;
grant execute on function public.admin_phase4_ready() to authenticated;

drop policy if exists "authorized administrators can manage chapters" on public.chapters;

create policy "administrators can read authorized chapters" on public.chapters
    for select to authenticated
    using (exists (
        select 1 from public.profiles p where p.id = auth.uid()
          and (p.role = 'national_admin' or (p.role = 'chapter_admin' and p.chapter_id = chapters.id))
    ));

create policy "national administrators can create chapters" on public.chapters
    for insert to authenticated
    with check (exists (
        select 1 from public.profiles p where p.id = auth.uid() and p.role = 'national_admin'
    ));

create policy "administrators can update authorized chapters" on public.chapters
    for update to authenticated
    using (exists (
        select 1 from public.profiles p where p.id = auth.uid()
          and (p.role = 'national_admin' or (p.role = 'chapter_admin' and p.chapter_id = chapters.id))
    ))
    with check (exists (
        select 1 from public.profiles p where p.id = auth.uid()
          and (p.role = 'national_admin' or (p.role = 'chapter_admin' and p.chapter_id = chapters.id))
    ));

create policy "national administrators can delete chapters" on public.chapters
    for delete to authenticated
    using (exists (
        select 1 from public.profiles p where p.id = auth.uid() and p.role = 'national_admin'
    ));

create function public.guard_chapter_activation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if current_user in ('authenticated', 'anon') and new.is_active is distinct from old.is_active
        and not exists (
            select 1 from public.profiles p where p.id = auth.uid() and p.role = 'national_admin'
        ) then
        raise exception 'Only national administrators can change chapter status' using errcode = '42501';
    end if;
    return new;
end;
$$;

create trigger guard_chapter_activation before update on public.chapters
    for each row execute function public.guard_chapter_activation();

-- Existing feed announcements have no chapter audience; chapter admins must not
-- publish them globally or impersonate another author.
drop policy if exists "admins can publish announcements" on public.posts;
create policy "national administrators can publish announcements" on public.posts
    for insert to authenticated
    with check (
        author_id = auth.uid()
        and kind in ('announcement', 'scholarship', 'program')
        and exists (
            select 1 from public.profiles p where p.id = auth.uid() and p.role = 'national_admin'
        )
    );

-- National admins need to see their drafts, not only published news.
create policy "national administrators can read news drafts" on public.news_articles
    for select to authenticated
    using (exists (
        select 1 from public.profiles p where p.id = auth.uid() and p.role = 'national_admin'
    ));

create table public.administrative_activity (
    id bigint generated always as identity primary key,
    actor_id uuid,
    action text not null,
    resource_type text not null,
    resource_id uuid not null,
    chapter_id uuid,
    occurred_at timestamptz not null default now()
);

alter table public.administrative_activity enable row level security;
revoke all on public.administrative_activity from public, anon, authenticated, service_role;
grant select on public.administrative_activity to authenticated;

create policy "administrators read scoped activity" on public.administrative_activity
    for select to authenticated
    using (exists (
        select 1 from public.profiles p where p.id = auth.uid()
          and (p.role = 'national_admin'
               or (p.role = 'chapter_admin' and administrative_activity.chapter_id is not null
                   and p.chapter_id = administrative_activity.chapter_id))
    ));

create index administrative_activity_time_idx on public.administrative_activity (occurred_at desc, id desc);
create index administrative_activity_chapter_idx on public.administrative_activity (chapter_id, occurred_at desc)
    where chapter_id is not null;

create function public.record_administrative_activity()
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
            and new.chapter_id is not distinct from old.chapter_id) then
            return coalesce(new, old);
        end if;
        target_id := new.id;
    elsif tg_table_name = 'posts' then
        if coalesce(new.kind, old.kind) = 'member' then return coalesce(new, old); end if;
        target_id := coalesce(new.id, old.id);
    elsif tg_table_name = 'chapters' then
        target_id := coalesce(new.id, old.id);
        scope_chapter := target_id;
    elsif tg_table_name = 'events' then
        target_id := coalesce(new.id, old.id);
        -- Moving an event between chapters is visible only to national admins.
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

create trigger audit_chapter_changes after insert or update or delete on public.chapters
    for each row execute function public.record_administrative_activity();
create trigger audit_profile_privileges after update on public.profiles
    for each row execute function public.record_administrative_activity();
create trigger audit_event_changes after insert or update or delete on public.events
    for each row execute function public.record_administrative_activity();
create trigger audit_news_changes after insert or update or delete on public.news_articles
    for each row execute function public.record_administrative_activity();
create trigger audit_official_posts after insert or update or delete on public.posts
    for each row execute function public.record_administrative_activity();
