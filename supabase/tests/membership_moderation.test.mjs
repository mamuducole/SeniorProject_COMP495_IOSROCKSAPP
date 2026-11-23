import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

// Migration 012: membership approval, applicant restrictions, moderation, notification
// guard, and account deletion. Uses a throwaway in-memory Postgres with Supabase stand-ins.
// Never point this at a real project. Run: node supabase/tests/membership_moderation.test.mjs
const dir = fileURLToPath(new URL('../migrations', import.meta.url));
const db = new PGlite();
let pass = 0, fail = 0;
const ok = (name, cond, extra = '') => { if (cond) { pass++; console.log('PASS', name); } else { fail++; console.log('FAIL', name, extra); } };

await db.exec(`
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
  create schema auth;
  create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb not null default '{}'::jsonb);
  create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema auth to anon, authenticated, service_role;
  grant execute on function auth.uid() to anon, authenticated, service_role;
  grant usage on schema public to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`);
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.sql')).sort()) {
  await db.exec(fs.readFileSync(`${dir}/${f}`, 'utf8').replace(/create extension if not exists pgcrypto;/, ''));
}

async function as(uid, sql) {
  await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false); set role ${uid ? 'authenticated' : 'anon'};`);
  try { return await db.query(sql); } finally { await db.exec('reset role;'); }
}
async function rejects(name, uid, sql) {
  try { const r = await as(uid, sql); ok(name, false, `expected error, got ${r.affectedRows ?? r.rows.length} rows`); }
  catch { ok(name, true); }
}
async function rows(name, uid, sql, n) {
  try { const r = await as(uid, sql); const c = /^\s*(select|with)/i.test(sql) || /returning/i.test(sql) ? r.rows.length : (r.affectedRows ?? 0); ok(name, c === n, `got ${c}, expected ${n}`); return r; }
  catch (e) { ok(name, false, e.message); }
}
const one = async (sql) => (await db.query(sql)).rows[0];

const chapter = '10000000-0000-0000-0000-000000000001';
const otherChapter = '10000000-0000-0000-0000-000000000002';
const closedChapter = '10000000-0000-0000-0000-000000000003';
const member = 'a0000000-0000-0000-0000-000000000001';
const author = 'a0000000-0000-0000-0000-000000000002';
const chapterAdmin = 'a0000000-0000-0000-0000-000000000003';
const national = 'a0000000-0000-0000-0000-000000000004';
const applicant = 'a0000000-0000-0000-0000-000000000005';
const otherApplicant = 'a0000000-0000-0000-0000-000000000006';
const sneaky = 'a0000000-0000-0000-0000-000000000007';
const noTerms = 'a0000000-0000-0000-0000-000000000008';

await db.exec(`
  insert into public.chapters (id, name, city, is_active) values
    ('${chapter}', 'Synthetic chapter', 'Test', true),
    ('${otherChapter}', 'Other synthetic chapter', 'Test', true),
    ('${closedChapter}', 'Inactive synthetic chapter', 'Test', false);
  insert into auth.users (id, email, raw_user_meta_data) values
    ('${member}', 'member@example.test', '{"first_name":"Mia","last_name":"Member"}'),
    ('${author}', 'author@example.test', '{"first_name":"Avery","last_name":"Author"}'),
    ('${chapterAdmin}', 'chapter@example.test', '{}'),
    ('${national}', 'national@example.test', '{}');
  update public.profiles set role = 'member', membership_status = 'approved';
  update public.profiles set role = 'chapter_admin', chapter_id = '${chapter}' where id = '${chapterAdmin}';
  update public.profiles set role = 'national_admin' where id = '${national}';
`);

// Registration trigger -------------------------------------------------------------
await db.exec(`
  insert into auth.users (id, email, raw_user_meta_data) values
    ('${applicant}', 'applicant@example.test', '{"first_name":" Ada ","last_name":"Applicant","requested_chapter_id":"${chapter}","terms_accepted":"true","terms_version":"registration-ack-v1"}'),
    ('${otherApplicant}', 'other.applicant@example.test', '{"first_name":"Omar","last_name":"Other","requested_chapter_id":"${otherChapter}","terms_accepted":"true","terms_version":"registration-ack-v1"}'),
    ('${sneaky}', 'sneaky@example.test', '{"first_name":"Sam","role":"national_admin","membership_status":"approved","requested_chapter_id":"${closedChapter}","terms_accepted":"true"}'),
    ('${noTerms}', 'noterms@example.test', '{"requested_chapter_id":"not-a-uuid"}');
`);
let p = await one(`select * from public.profiles where id='${applicant}'`);
ok('signup creates a pending guest applicant', p.role === 'guest' && p.membership_status === 'pending');
ok('signup trims names and stores requested chapter', p.first_name === 'Ada' && p.requested_chapter_id === chapter && p.chapter_id === null);
ok('signup records terms acknowledgment and version', p.terms_accepted_at !== null && p.terms_version === 'registration-ack-v1');
p = await one(`select * from public.profiles where id='${sneaky}'`);
ok('signup metadata cannot request role or approval', p.role === 'guest' && p.membership_status === 'pending');
ok('signup ignores inactive requested chapter', p.requested_chapter_id === null);
ok('acknowledgment without a version is not recorded', p.terms_accepted_at === null);
p = await one(`select * from public.profiles where id='${noTerms}'`);
ok('malformed requested chapter is ignored and default names applied', p.requested_chapter_id === null && p.first_name === 'noterms' && p.last_name === 'Member' && p.terms_accepted_at === null);

let failed = false;
try { await db.exec(`update public.profiles set role='member' where id='${noTerms}'`); } catch { failed = true; }
ok('database rejects a non-guest role without approval', failed);

// Applicant restrictions -----------------------------------------------------------
const post = (await as(author, `insert into public.posts (author_id, kind, body) values ('${author}','member','Synthetic post') returning id`)).rows[0].id;
const comment = (await as(member, `insert into public.post_comments (post_id, author_id, body) values ('${post}','${member}','Synthetic comment') returning id`)).rows[0].id;
await as(member, `insert into public.post_likes (post_id, profile_id) values ('${post}','${member}')`);
await as(author, `insert into public.mentorship_profiles (profile_id, directory_visible, is_accepting, specialties) values ('${author}', true, true, '{Leadership}')`);

await rows('applicant reads own profile', applicant, `select id from public.profiles`, 1);
await rows('applicant cannot read posts', applicant, `select id from public.posts`, 0);
await rows('applicant cannot read comments', applicant, `select id from public.post_comments`, 0);
await rows('applicant cannot read likes', applicant, `select post_id from public.post_likes`, 0);
await rows('applicant sees only self in attribution view', applicant, `select id from public.member_public_profiles`, 1);
await rejects('applicant cannot post', applicant, `insert into public.posts (author_id, kind, body) values ('${applicant}','member','Hi')`);
await rejects('applicant cannot approve themselves', applicant, `update public.profiles set membership_status='approved', role='member' where id='${applicant}'`);
await rejects('applicant cannot change status alone', applicant, `update public.profiles set membership_status='approved' where id='${applicant}'`);
await rejects('applicant cannot change requested chapter', applicant, `update public.profiles set requested_chapter_id='${otherChapter}' where id='${applicant}'`);
await rejects('applicant cannot forge terms acceptance', applicant, `update public.profiles set terms_version='forged' where id='${applicant}'`);
await rows('applicant can edit own name', applicant, `update public.profiles set first_name='Adaline' where id='${applicant}'`, 1);
await rejects('applicant cannot list applications', applicant, `select * from public.admin_list_membership_applications()`);
await rejects('applicant cannot report content', applicant, `insert into public.content_reports (reporter_id, post_id, reason) values ('${applicant}','${post}','spam')`);
await rejects('applicant cannot request mentorship', applicant, `select public.mentorship_send_request('${author}', 'Hello')`);
await rows('approved member can request the same mentor (control)', member, `select public.mentorship_send_request('${author}', 'Hello')`, 1);
await rows('approved member sees approved members only', member, `select id from public.member_public_profiles`, 4);

// Membership review ----------------------------------------------------------------
await rejects('member cannot list applications', member, `select * from public.admin_list_membership_applications()`);
await rejects('member cannot approve an applicant', member, `select public.admin_review_membership('${applicant}', 'approve')`);
await rejects('anonymous cannot review membership', null, `select public.admin_review_membership('${applicant}', 'approve')`);
let r = await rows('chapter admin lists only applicants for their chapter', chapterAdmin, `select profile_id, email, requested_chapter_name from public.admin_list_membership_applications()`, 1);
ok('chapter admin listing includes contact email and chapter name', r?.rows[0]?.email === 'applicant@example.test' && r?.rows[0]?.requested_chapter_name === 'Synthetic chapter');
await rejects('chapter admin cannot review an applicant for another chapter', chapterAdmin, `select public.admin_review_membership('${otherApplicant}', 'approve')`);
await rejects('chapter admin cannot review applicant with no chapter', chapterAdmin, `select public.admin_review_membership('${sneaky}', 'approve')`);
await rejects('unknown decision rejected', chapterAdmin, `select public.admin_review_membership('${applicant}', 'promote')`);
await rejects('administrator cannot review themselves', national, `select public.admin_review_membership('${national}', 'suspend')`);
await rejects('administrator accounts are outside membership review', national, `select public.admin_review_membership('${chapterAdmin}', 'suspend')`);

await as(chapterAdmin, `select public.admin_review_membership('${applicant}', 'approve')`);
p = await one(`select * from public.profiles where id='${applicant}'`);
ok('approval grants member role, status, and requested chapter', p.role === 'member' && p.membership_status === 'approved' && p.chapter_id === chapter);
ok('approval records reviewer', p.membership_reviewed_by === chapterAdmin && p.membership_reviewed_at !== null);
await rows('approved applicant receives a notification', applicant, `select id from public.notifications where title='Membership update'`, 1);
await rows('approved applicant can now read posts', applicant, `select id from public.posts`, 1);
await rejects('already-approved member cannot be approved again', chapterAdmin, `select public.admin_review_membership('${applicant}', 'approve')`);
await rows('chapter admin sees membership audit for their chapter', chapterAdmin, `select id from public.administrative_activity where resource_type='profiles' and resource_id='${applicant}'`, 1);

await rows('national admin lists all remaining applicants', national, `select profile_id from public.admin_list_membership_applications()`, 3);
await as(national, `select public.admin_review_membership('${sneaky}', 'decline')`);
p = await one(`select role, membership_status from public.profiles where id='${sneaky}'`);
ok('declined applicant remains a guest', p.role === 'guest' && p.membership_status === 'declined');
await rejects('declined application cannot be declined again', national, `select public.admin_review_membership('${sneaky}', 'decline')`);
await rows('national admin can list declined applications', national, `select profile_id from public.admin_list_membership_applications('declined')`, 1);

await as(national, `select public.admin_review_membership('${author}', 'suspend')`);
p = await one(`select role, membership_status from public.profiles where id='${author}'`);
ok('suspension removes member access', p.role === 'guest' && p.membership_status === 'suspended');
ok('suspension hides mentor directory profile', (await one(`select directory_visible from public.mentorship_profiles where profile_id='${author}'`)).directory_visible === false);
await rejects('suspended member cannot post', author, `insert into public.posts (author_id, kind, body) values ('${author}','member','Still here')`);
await rows('suspended member cannot read the board', author, `select id from public.posts`, 0);
await as(national, `select public.admin_review_membership('${author}', 'approve')`);
ok('suspended member can be reinstated', (await one(`select membership_status from public.profiles where id='${author}'`)).membership_status === 'approved');

// Reports and moderation -----------------------------------------------------------
await rows('approved member can report a post', member, `insert into public.content_reports (reporter_id, post_id, reason, details) values ('${member}','${post}','spam','Synthetic report') returning id`, 1);
await rejects('duplicate open report rejected', member, `insert into public.content_reports (reporter_id, post_id, reason) values ('${member}','${post}','other')`);
await rejects('report needs exactly one target', member, `insert into public.content_reports (reporter_id, post_id, comment_id, reason) values ('${member}','${post}','${comment}','spam')`);
await rejects('report reason must be known', member, `insert into public.content_reports (reporter_id, comment_id, reason) values ('${member}','${comment}','dislike')`);
await rejects('member cannot report as someone else', member, `insert into public.content_reports (reporter_id, comment_id, reason) values ('${applicant}','${comment}','spam')`);
await rejects('member cannot file a pre-resolved report', member, `insert into public.content_reports (reporter_id, comment_id, reason, status) values ('${member}','${comment}','spam','dismissed')`);
await rows('approved member can report a comment', applicant, `insert into public.content_reports (reporter_id, comment_id, reason) values ('${applicant}','${comment}','harassment') returning id`, 1);
await rows('reporter sees only own reports', member, `select id from public.content_reports`, 1);
await rows('reporter cannot update reports', member, `update public.content_reports set status='dismissed'`, 0);
await rejects('member cannot list moderation queue', member, `select * from public.admin_list_open_reports()`);
await rejects('chapter admin cannot list moderation queue', chapterAdmin, `select * from public.admin_list_open_reports()`);
r = await rows('national admin lists open reports', national, `select * from public.admin_list_open_reports()`, 2);
ok('moderation queue includes content and author', r?.rows.some(x => x.content === 'Synthetic post' && x.author_name === 'Avery Author'));
const commentReport = r?.rows.find(x => x.comment_id === comment)?.report_id;
await rejects('cannot resolve a report back to open', national, `select public.admin_resolve_report('${commentReport}', 'open')`);
await as(national, `select public.admin_resolve_report('${commentReport}', 'dismissed')`);
ok('report resolution recorded', (await one(`select status, resolved_by from public.content_reports where id='${commentReport}'`)).resolved_by === national);
await rows('resolution is audited', national, `select id from public.administrative_activity where resource_type='content_reports' and resource_id='${commentReport}'`, 1);

await rows('member cannot delete another member post', member, `delete from public.posts where id='${post}'`, 0);
await rows('chapter admin cannot delete member posts', chapterAdmin, `delete from public.posts where id='${post}'`, 0);
await rows('national admin can remove a comment', national, `delete from public.post_comments where id='${comment}' returning id`, 1);
await rows('national admin can remove a post', national, `delete from public.posts where id='${post}' returning id`, 1);
await rows('moderated post removal is audited', national, `select id from public.administrative_activity where resource_type='posts' and resource_id='${post}'`, 1);
await rows('moderated comment removal is audited', national, `select id from public.administrative_activity where resource_type='post_comments' and resource_id='${comment}'`, 1);
await rows('removing a post closes its reports', national, `select id from public.content_reports where post_id='${post}'`, 0);
const own = (await as(member, `insert into public.posts (author_id, kind, body) values ('${member}','member','Own post') returning id`)).rows[0].id;
await as(member, `delete from public.posts where id='${own}'`);
await rows('author self-deletion is not logged as moderation', national, `select id from public.administrative_activity where resource_id='${own}'`, 0);

// Notifications --------------------------------------------------------------------
const note = (await db.query(`select id from public.notifications where profile_id='${applicant}' limit 1`)).rows[0].id;
await rows('member can mark own notification read', applicant, `update public.notifications set is_read=true where id='${note}'`, 1);
await rejects('member cannot rewrite notification content', applicant, `update public.notifications set title='Forged' where id='${note}'`);
await rows('member cannot mark another member notification read', member, `update public.notifications set is_read=false where id='${note}'`, 0);

// Account deletion -----------------------------------------------------------------
await rejects('anonymous cannot delete an account', null, `select public.delete_own_account()`);
await rejects('last national administrator cannot delete their account', national, `select public.delete_own_account()`);
await as(member, `insert into public.posts (author_id, kind, body) values ('${member}','member','Before deletion')`);
await as(member, `select public.delete_own_account()`);
ok('account deletion removes auth user and profile',
  (await one(`select count(*)::int c from auth.users where id='${member}'`)).c === 0
  && (await one(`select count(*)::int c from public.profiles where id='${member}'`)).c === 0);
ok('account deletion removes member content', (await one(`select count(*)::int c from public.posts where author_id='${member}'`)).c === 0);
ok('other accounts are untouched', (await one(`select count(*)::int c from public.profiles`)).c === 7);
ok('audit history survives account deletion', (await one(`select count(*)::int c from public.administrative_activity`)).c > 0);

// Privileges -----------------------------------------------------------------------
for (const fn of ['admin_list_membership_applications(public.membership_status)', 'admin_review_membership(uuid,text)', 'admin_list_open_reports()', 'admin_resolve_report(uuid,public.content_report_status)', 'delete_own_account()', 'is_approved_member()']) {
  const g = await one(`select has_function_privilege('anon', 'public.${fn}', 'execute') a, has_function_privilege('authenticated', 'public.${fn}', 'execute') b`);
  ok(`${fn}: anon denied, authenticated allowed`, g.a === false && g.b === true);
}
ok('anon has no content report privileges', (await one(`select has_table_privilege('anon', 'public.content_reports', 'select') s`)).s === false);
await rejects('anonymous cannot read reports', null, `select * from public.content_reports`);

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
