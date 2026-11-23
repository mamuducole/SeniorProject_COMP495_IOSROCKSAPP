-- 002_redesign_features.sql
-- Tables backing the redesigned app: community feed, mentorship, notifications,
-- scholarships, and richer member/event surfaces.

-- Extra profile attribute used across the feed, directory, and mentorship cards.
alter table public.profiles add column if not exists rank_title text;
alter table public.events add column if not exists image_path text;

create type public.post_kind as enum ('member', 'announcement', 'scholarship', 'program');
create type public.mentorship_request_status as enum ('pending', 'accepted', 'declined');
create type public.mentorship_connection_status as enum ('active', 'completed', 'paused');

-- Community feed ---------------------------------------------------------------

create table public.posts (
    id uuid primary key default gen_random_uuid(),
    author_id uuid not null references public.profiles(id) on delete cascade,
    kind public.post_kind not null default 'member',
    body text not null,
    image_path text,
    created_at timestamptz not null default now()
);

create table public.post_likes (
    post_id uuid not null references public.posts(id) on delete cascade,
    profile_id uuid not null references public.profiles(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (post_id, profile_id)
);

create table public.post_comments (
    id uuid primary key default gen_random_uuid(),
    post_id uuid not null references public.posts(id) on delete cascade,
    author_id uuid not null references public.profiles(id) on delete cascade,
    body text not null,
    created_at timestamptz not null default now()
);

-- Mentorship -------------------------------------------------------------------

create table public.mentorship_profiles (
    profile_id uuid primary key references public.profiles(id) on delete cascade,
    specialties text[] not null default '{}',
    mentoring_bio text,
    is_accepting boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.mentorship_requests (
    id uuid primary key default gen_random_uuid(),
    mentee_id uuid not null references public.profiles(id) on delete cascade,
    mentor_id uuid not null references public.profiles(id) on delete cascade,
    message text,
    status public.mentorship_request_status not null default 'pending',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint mentorship_requests_distinct_pair check (mentee_id <> mentor_id)
);

create table public.mentorship_connections (
    id uuid primary key default gen_random_uuid(),
    mentor_id uuid not null references public.profiles(id) on delete cascade,
    mentee_id uuid not null references public.profiles(id) on delete cascade,
    status public.mentorship_connection_status not null default 'active',
    started_at timestamptz not null default now(),
    unique (mentor_id, mentee_id)
);

create table public.mentorship_goals (
    id uuid primary key default gen_random_uuid(),
    connection_id uuid not null references public.mentorship_connections(id) on delete cascade,
    title text not null,
    is_complete boolean not null default false,
    due_date date,
    created_at timestamptz not null default now()
);

create table public.mentorship_check_ins (
    id uuid primary key default gen_random_uuid(),
    connection_id uuid not null references public.mentorship_connections(id) on delete cascade,
    note text not null,
    meeting_at timestamptz not null,
    created_at timestamptz not null default now()
);

-- Notifications & scholarships -------------------------------------------------

create table public.notifications (
    id uuid primary key default gen_random_uuid(),
    profile_id uuid not null references public.profiles(id) on delete cascade,
    title text not null,
    body text,
    route text,
    is_read boolean not null default false,
    created_at timestamptz not null default now()
);

create table public.scholarships (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    summary text,
    award_amount text,
    deadline timestamptz not null,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
);

-- Indexes ----------------------------------------------------------------------

create index posts_feed_idx on public.posts (created_at desc);
create index post_comments_post_idx on public.post_comments (post_id, created_at);
create index mentorship_requests_mentee_idx on public.mentorship_requests (mentee_id, created_at desc);
create index mentorship_requests_mentor_idx on public.mentorship_requests (mentor_id, status);
create index mentorship_connections_member_idx on public.mentorship_connections (mentee_id, status);
create index notifications_profile_unread_idx on public.notifications (profile_id, created_at desc) where is_read = false;
create index scholarships_deadline_idx on public.scholarships (deadline) where is_active = true;

-- Row level security -----------------------------------------------------------

alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.mentorship_profiles enable row level security;
alter table public.mentorship_requests enable row level security;
alter table public.mentorship_connections enable row level security;
alter table public.mentorship_goals enable row level security;
alter table public.mentorship_check_ins enable row level security;
alter table public.notifications enable row level security;
alter table public.scholarships enable row level security;

-- Feed: members read everything; members author their own member posts.
-- Announcement/scholarship/program posts are authored by chapter/national admins.
create policy "members can read posts" on public.posts for select to authenticated using (true);
create policy "members can create member posts" on public.posts for insert to authenticated
    with check (author_id = auth.uid() and kind = 'member');
create policy "authors can delete their posts" on public.posts for delete to authenticated
    using (author_id = auth.uid());
create policy "admins can publish announcements" on public.posts for insert to authenticated
    with check (
        kind in ('announcement', 'scholarship', 'program')
        and exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.role in ('chapter_admin', 'national_admin')
        )
    );

create policy "members can read likes" on public.post_likes for select to authenticated using (true);
create policy "members can like" on public.post_likes for insert to authenticated
    with check (profile_id = auth.uid());
create policy "members can unlike" on public.post_likes for delete to authenticated
    using (profile_id = auth.uid());

create policy "members can read comments" on public.post_comments for select to authenticated using (true);
create policy "members can comment" on public.post_comments for insert to authenticated
    with check (author_id = auth.uid());
create policy "authors can delete their comments" on public.post_comments for delete to authenticated
    using (author_id = auth.uid());

-- Mentorship: directory of mentors is visible to members; requests/connections
-- are only visible to the two people involved.
create policy "members can read mentor profiles" on public.mentorship_profiles for select to authenticated using (true);
create policy "members manage their mentor profile" on public.mentorship_profiles for insert to authenticated
    with check (profile_id = auth.uid());
create policy "members update their mentor profile" on public.mentorship_profiles for update to authenticated
    using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy "participants can read requests" on public.mentorship_requests for select to authenticated
    using (mentee_id = auth.uid() or mentor_id = auth.uid());
create policy "members can request mentorship" on public.mentorship_requests for insert to authenticated
    with check (mentee_id = auth.uid());
create policy "mentors can respond to requests" on public.mentorship_requests for update to authenticated
    using (mentor_id = auth.uid()) with check (mentor_id = auth.uid());

create policy "participants can read connections" on public.mentorship_connections for select to authenticated
    using (mentee_id = auth.uid() or mentor_id = auth.uid());
create policy "mentors can create connections" on public.mentorship_connections for insert to authenticated
    with check (mentor_id = auth.uid());
create policy "participants can update connections" on public.mentorship_connections for update to authenticated
    using (mentee_id = auth.uid() or mentor_id = auth.uid())
    with check (mentee_id = auth.uid() or mentor_id = auth.uid());

create policy "participants can read goals" on public.mentorship_goals for select to authenticated
    using (exists (
        select 1 from public.mentorship_connections c
        where c.id = connection_id and (c.mentee_id = auth.uid() or c.mentor_id = auth.uid())
    ));
create policy "participants can manage goals" on public.mentorship_goals for insert to authenticated
    with check (exists (
        select 1 from public.mentorship_connections c
        where c.id = connection_id and (c.mentee_id = auth.uid() or c.mentor_id = auth.uid())
    ));
create policy "participants can update goals" on public.mentorship_goals for update to authenticated
    using (exists (
        select 1 from public.mentorship_connections c
        where c.id = connection_id and (c.mentee_id = auth.uid() or c.mentor_id = auth.uid())
    ));

create policy "participants can read check-ins" on public.mentorship_check_ins for select to authenticated
    using (exists (
        select 1 from public.mentorship_connections c
        where c.id = connection_id and (c.mentee_id = auth.uid() or c.mentor_id = auth.uid())
    ));
create policy "participants can add check-ins" on public.mentorship_check_ins for insert to authenticated
    with check (exists (
        select 1 from public.mentorship_connections c
        where c.id = connection_id and (c.mentee_id = auth.uid() or c.mentor_id = auth.uid())
    ));

-- Notifications are private to the recipient.
create policy "members can read their notifications" on public.notifications for select to authenticated
    using (profile_id = auth.uid());
create policy "members can mark notifications read" on public.notifications for update to authenticated
    using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- Scholarships are visible to members.
create policy "members can read scholarships" on public.scholarships for select to authenticated
    using (is_active = true);

-- Members can read basic info of other members (directory, feed attribution).
create policy "members can read member directory" on public.profiles for select to authenticated using (true);
