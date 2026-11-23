-- Test with synthetic accounts in staging before requesting production approval.
-- Do not remove existing registrations; cancellation remains available.
drop policy if exists "members can register themselves" on public.event_registrations;

-- Directory consent does not grant chapter visibility in the general attribution view.
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
from public.profiles p;

comment on view public.member_public_profiles is
    'Attribution view: biography and chapter are visible only to their owner. Other attribution fields require a broader consent review.';

revoke all on public.member_public_profiles from public, anon;
grant select on public.member_public_profiles to authenticated;

create or replace view public.mentor_directory_chapters
with (security_barrier = true)
as
select p.id, p.chapter_id
from public.profiles p
join public.mentorship_profiles m on m.profile_id = p.id
where m.directory_visible and m.share_chapter
  and exists (
      select 1 from public.profiles viewer
      where viewer.id = auth.uid() and viewer.role <> 'guest'
  );

comment on view public.mentor_directory_chapters is
    'Chapter affiliations explicitly shared in the mentor directory with non-guest authenticated users.';
revoke all on public.mentor_directory_chapters from public, anon;
grant select on public.mentor_directory_chapters to authenticated;
