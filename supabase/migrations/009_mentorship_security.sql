-- Apply and test in staging before enabling the Phase 3 client against real data.
-- Existing mentor profiles remain private until their owners opt in.
alter table public.mentorship_profiles
    add column directory_visible boolean not null default false,
    add column share_chapter boolean not null default false,
    add column career_field text,
    add column career_background text,
    add column interests text[] not null default '{}';

alter table public.mentorship_goals
    add column milestones text[] not null default '{}',
    add column progress_percent integer not null default 0 check (progress_percent between 0 and 100);
update public.mentorship_goals set progress_percent = 100 where is_complete;
alter table public.mentorship_goals add constraint mentorship_goal_completion_consistent
    check (is_complete = (progress_percent = 100));
alter table public.mentorship_check_ins add column next_steps text;

create table public.mentorship_goal_progress (
    id uuid primary key default gen_random_uuid(),
    goal_id uuid not null references public.mentorship_goals(id) on delete cascade,
    progress_percent integer not null check (progress_percent between 0 and 100),
    recorded_at timestamptz not null default now()
);
insert into public.mentorship_goal_progress (goal_id, progress_percent)
select id, progress_percent from public.mentorship_goals;
alter table public.mentorship_goal_progress enable row level security;
create policy "participants can read goal progress" on public.mentorship_goal_progress
    for select to authenticated using (exists (
        select 1 from public.mentorship_goals g
        join public.mentorship_connections c on c.id = g.connection_id
        where g.id = goal_id and (c.mentor_id = auth.uid() or c.mentee_id = auth.uid())
    ));

create unique index mentorship_one_pending_request
    on public.mentorship_requests (least(mentee_id, mentor_id), greatest(mentee_id, mentor_id))
    where status = 'pending';
create unique index mentorship_one_active_connection
    on public.mentorship_connections (least(mentee_id, mentor_id), greatest(mentee_id, mentor_id))
    where status = 'active';

drop policy "members can read mentor profiles" on public.mentorship_profiles;
create policy "visible mentors and participants can read mentor profiles"
    on public.mentorship_profiles for select to authenticated
    using (
        (directory_visible and exists (
            select 1 from public.profiles where id = auth.uid() and role <> 'guest'
        )) or profile_id = auth.uid()
        or exists (
            select 1 from public.mentorship_requests r
            where r.mentor_id = mentorship_profiles.profile_id
              and (r.mentee_id = auth.uid() or r.mentor_id = auth.uid())
        )
        or exists (
            select 1 from public.mentorship_connections c
            where c.mentor_id = mentorship_profiles.profile_id
              and (c.mentee_id = auth.uid() or c.mentor_id = auth.uid())
        )
    );

drop policy "members manage their mentor profile" on public.mentorship_profiles;
create policy "members manage their mentor profile" on public.mentorship_profiles for insert to authenticated
    with check (profile_id = auth.uid() and exists (
        select 1 from public.profiles where id = auth.uid() and role <> 'guest'
    ));
drop policy "members update their mentor profile" on public.mentorship_profiles;
create policy "members update their mentor profile" on public.mentorship_profiles for update to authenticated
    using (profile_id = auth.uid())
    with check (profile_id = auth.uid() and exists (
        select 1 from public.profiles where id = auth.uid() and role <> 'guest'
    ));

-- Requests and connection transitions are performed only by checked functions.
drop policy "members can request mentorship" on public.mentorship_requests;
drop policy "mentors can respond to requests" on public.mentorship_requests;
drop policy "mentors can create connections" on public.mentorship_connections;
drop policy "participants can update connections" on public.mentorship_connections;

drop policy "participants can manage goals" on public.mentorship_goals;
create policy "active participants can add goals" on public.mentorship_goals for insert to authenticated
    with check (exists (
        select 1 from public.mentorship_connections c
        where c.id = connection_id and c.status = 'active'
          and (c.mentee_id = auth.uid() or c.mentor_id = auth.uid())
    ));
drop policy "participants can update goals" on public.mentorship_goals;
create policy "active participants can update goals" on public.mentorship_goals for update to authenticated
    using (exists (
        select 1 from public.mentorship_connections c
        where c.id = connection_id and c.status = 'active'
          and (c.mentee_id = auth.uid() or c.mentor_id = auth.uid())
    ))
    with check (exists (
        select 1 from public.mentorship_connections c
        where c.id = connection_id and c.status = 'active'
          and (c.mentee_id = auth.uid() or c.mentor_id = auth.uid())
    ));

drop policy "participants can add check-ins" on public.mentorship_check_ins;
create policy "active participants can add check-ins" on public.mentorship_check_ins for insert to authenticated
    with check (exists (
        select 1 from public.mentorship_connections c
        where c.id = connection_id and c.status = 'active'
          and (c.mentee_id = auth.uid() or c.mentor_id = auth.uid())
    ));

create function public.guard_mentorship_goal_connection()
returns trigger language plpgsql set search_path = '' as $$
begin
    if new.connection_id is distinct from old.connection_id then
        raise exception 'A goal cannot be moved to another connection' using errcode = '42501';
    end if;
    if new.progress_percent is distinct from old.progress_percent then
        new.is_complete := new.progress_percent = 100;
    elsif new.is_complete is distinct from old.is_complete then
        new.progress_percent := case when new.is_complete then 100 else 0 end;
    end if;
    return new;
end;
$$;
create trigger guard_mentorship_goal_connection before update on public.mentorship_goals
    for each row execute function public.guard_mentorship_goal_connection();

create function public.record_mentorship_goal_progress()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
    if tg_op = 'INSERT' or new.progress_percent is distinct from old.progress_percent then
        insert into public.mentorship_goal_progress (goal_id, progress_percent)
        values (new.id, new.progress_percent);
    end if;
    return new;
end;
$$;
create trigger record_mentorship_goal_progress after insert or update on public.mentorship_goals
    for each row execute function public.record_mentorship_goal_progress();

create function public.mentorship_phase3_ready() returns boolean
language sql stable set search_path = '' as $$ select auth.uid() is not null $$;

create function public.mentorship_send_request(p_mentor_id uuid, p_message text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_request uuid;
begin
    if v_uid is null or not exists (
        select 1 from public.profiles where id = v_uid and role <> 'guest'
    ) then raise exception 'Member authentication required' using errcode = '42501'; end if;
    if p_mentor_id = v_uid or not exists (
        select 1 from public.mentorship_profiles
        where profile_id = p_mentor_id and directory_visible and is_accepting
    ) then raise exception 'Mentor is unavailable' using errcode = '22023'; end if;
    if p_message is null or char_length(trim(p_message)) not between 1 and 1000 then
        raise exception 'Introduction must contain 1 to 1000 characters' using errcode = '22023';
    end if;
    perform pg_advisory_xact_lock(hashtextextended(
        least(v_uid, p_mentor_id)::text || ':' || greatest(v_uid, p_mentor_id)::text, 0
    ));
    if exists (
        select 1 from public.mentorship_connections
        where ((mentee_id = v_uid and mentor_id = p_mentor_id)
            or (mentor_id = v_uid and mentee_id = p_mentor_id)) and status = 'active'
    ) then raise exception 'Mentorship already active' using errcode = '23505'; end if;
    insert into public.mentorship_requests (mentee_id, mentor_id, message)
    values (v_uid, p_mentor_id, trim(p_message)) returning id into v_request;
    insert into public.notifications (profile_id, title, body)
    values (p_mentor_id, 'Mentorship request', 'You have received a mentorship request.');
    return v_request;
end;
$$;

create function public.mentorship_respond_request(p_request_id uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_request public.mentorship_requests%rowtype;
begin
    if auth.uid() is null or p_accept is null then
        raise exception 'Member authentication required' using errcode = '42501';
    end if;
    select * into v_request from public.mentorship_requests
    where id = p_request_id and mentor_id = auth.uid() and status = 'pending';
    if not found then raise exception 'Pending request not found or not permitted' using errcode = '42501'; end if;
    perform pg_advisory_xact_lock(hashtextextended(
        least(v_request.mentee_id, v_request.mentor_id)::text || ':' ||
        greatest(v_request.mentee_id, v_request.mentor_id)::text, 0
    ));
    select * into v_request from public.mentorship_requests
    where id = p_request_id and mentor_id = auth.uid() and status = 'pending' for update;
    if not found then raise exception 'Pending request not found or not permitted' using errcode = '42501'; end if;
    if p_accept and exists (
        select 1 from public.mentorship_connections c
        where c.status = 'active'
          and least(c.mentee_id, c.mentor_id) = least(v_request.mentee_id, v_request.mentor_id)
          and greatest(c.mentee_id, c.mentor_id) = greatest(v_request.mentee_id, v_request.mentor_id)
    ) then raise exception 'Mentorship already active' using errcode = '23505'; end if;
    update public.mentorship_requests
    set status = case when p_accept then 'accepted'::public.mentorship_request_status
                      else 'declined'::public.mentorship_request_status end,
        updated_at = now()
    where id = p_request_id;
    if p_accept then
        insert into public.mentorship_connections (mentor_id, mentee_id, status)
        values (v_request.mentor_id, v_request.mentee_id, 'active')
        on conflict (mentor_id, mentee_id) do update set status = 'active', started_at = now();
    end if;
    insert into public.notifications (profile_id, title, body)
    values (v_request.mentee_id, 'Mentorship request updated',
            case when p_accept then 'Your request was accepted.' else 'Your request was declined.' end);
end;
$$;

create function public.mentorship_cancel_request(p_request_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
    delete from public.mentorship_requests
    where id = p_request_id and mentee_id = auth.uid() and status = 'pending';
    if not found then raise exception 'Pending request not found or not permitted' using errcode = '42501'; end if;
end;
$$;

create function public.mentorship_end_connection(p_connection_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
    update public.mentorship_connections set status = 'completed'
    where id = p_connection_id and status = 'active'
      and (mentor_id = auth.uid() or mentee_id = auth.uid());
    if not found then raise exception 'Active connection not found or not permitted' using errcode = '42501'; end if;
end;
$$;

create function public.notify_mentorship_activity()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_recipient uuid;
begin
    select case when mentor_id = auth.uid() then mentee_id else mentor_id end
    into v_recipient from public.mentorship_connections
    where id = new.connection_id and (mentor_id = auth.uid() or mentee_id = auth.uid());
    if v_recipient is null then
        raise exception 'Connection participant required' using errcode = '42501';
    end if;
    if tg_table_name = 'mentorship_goals' then
        insert into public.notifications (profile_id, title, body)
        values (v_recipient, 'Mentorship goal updated', 'A goal in your mentorship was updated.');
    elsif new.meeting_at > now() then
        insert into public.notifications (profile_id, title, body)
        values (v_recipient, 'Mentorship check-in scheduled', 'A mentorship check-in was scheduled.');
    end if;
    return new;
end;
$$;
create trigger notify_mentorship_goal after insert or update on public.mentorship_goals
    for each row execute function public.notify_mentorship_activity();
create trigger notify_mentorship_check_in after insert on public.mentorship_check_ins
    for each row execute function public.notify_mentorship_activity();

revoke all on function public.mentorship_phase3_ready() from public, anon;
revoke all on function public.mentorship_send_request(uuid, text) from public, anon;
revoke all on function public.mentorship_respond_request(uuid, boolean) from public, anon;
revoke all on function public.mentorship_cancel_request(uuid) from public, anon;
revoke all on function public.mentorship_end_connection(uuid) from public, anon;
grant execute on function public.mentorship_phase3_ready() to authenticated;
grant execute on function public.mentorship_send_request(uuid, text) to authenticated;
grant execute on function public.mentorship_respond_request(uuid, boolean) to authenticated;
grant execute on function public.mentorship_cancel_request(uuid) to authenticated;
grant execute on function public.mentorship_end_connection(uuid) to authenticated;
