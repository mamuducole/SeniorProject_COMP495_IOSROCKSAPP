import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const db = new PGlite();
const dir = fileURLToPath(new URL('../migrations', import.meta.url));
let passed = 0, failed = 0;
function check(name, condition) {
  if (condition) { passed++; console.log('PASS', name); }
  else { failed++; console.error('FAIL', name); }
}

await db.exec(`
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
  create schema auth;
  create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb not null default '{}');
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  grant usage on schema auth, public to anon, authenticated, service_role;
  grant execute on function auth.uid() to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`);
for (const name of fs.readdirSync(dir).filter(name => name.endsWith('.sql')).sort()) {
  await db.exec(fs.readFileSync(`${dir}/${name}`, 'utf8').replace(/create extension if not exists pgcrypto;/, ''));
}

const mentee = 'a0000000-0000-0000-0000-000000000001';
const mentor = 'a0000000-0000-0000-0000-000000000002';
const other = 'a0000000-0000-0000-0000-000000000003';
const guest = 'a0000000-0000-0000-0000-000000000004';
await db.exec(`
  insert into auth.users (id, email) values
    ('${mentee}', 'mentee@example.test'), ('${mentor}', 'mentor@example.test'),
    ('${other}', 'other@example.test'), ('${guest}', 'guest@example.test');
  update public.profiles set role = 'member', membership_status = 'approved' where id <> '${guest}';
`);
async function as(user, query) {
  await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${user ?? ''}', false); set role ${user ? 'authenticated' : 'anon'}`);
  try { return await db.query(query); } finally { await db.exec('reset role'); }
}
async function denied(name, user, query) {
  try { await as(user, query); check(name, false); } catch { check(name, true); }
}
async function count(name, user, query, expected) {
  try { const result = await as(user, query); check(name, result.rows.length === expected); }
  catch (error) { console.error(error.message); check(name, false); }
}

await as(mentor, `insert into public.mentorship_profiles (profile_id, specialties) values ('${mentor}', array['Leadership'])`);
await count('unconsented mentor hidden', mentee, 'select * from public.mentorship_profiles', 0);
await denied('cannot request hidden mentor', mentee, `select public.mentorship_send_request('${mentor}', 'Hello')`);
await as(mentor, `update public.mentorship_profiles set directory_visible = true where profile_id = '${mentor}'`);
await as(mentee, `insert into public.mentorship_profiles (profile_id, specialties, directory_visible) values ('${mentee}', array['Career'], true)`);
await count('opted-in mentor visible', other, `select * from public.mentorship_profiles where profile_id = '${mentor}'`, 1);
await count('guest cannot browse mentor directory', guest, 'select * from public.mentorship_profiles', 0);
await denied('guest cannot become a mentor', guest, `insert into public.mentorship_profiles (profile_id, directory_visible) values ('${guest}', true)`);
await denied('guest cannot request', guest, `select public.mentorship_send_request('${mentor}', 'Hello')`);
await denied('anonymous cannot call request function', null, `select public.mentorship_send_request('${mentor}', 'Hello')`);
await denied('direct request insert is blocked', mentee, `insert into public.mentorship_requests (mentee_id, mentor_id) values ('${mentee}', '${mentor}')`);
await denied('direct connection insert is blocked', mentor, `insert into public.mentorship_connections (mentor_id, mentee_id) values ('${mentor}', '${other}')`);
const sent = await as(mentee, `select public.mentorship_send_request('${mentor}', 'Hello') as id`);
const request = sent.rows[0].id;
await denied('duplicate pending request rejected', mentee, `select public.mentorship_send_request('${mentor}', 'Again')`);
await denied('reverse duplicate pending request rejected', mentor, `select public.mentorship_send_request('${mentee}', 'Again')`);
await denied('unrelated member cannot accept', other, `select public.mentorship_respond_request('${request}', true)`);
await denied('mentee cannot accept own request', mentee, `select public.mentorship_respond_request('${request}', true)`);
await count('unrelated member cannot read request', other, 'select * from public.mentorship_requests', 0);
await as(mentor, `select public.mentorship_respond_request('${request}', true)`);
const connection = (await as(mentee, 'select id from public.mentorship_connections')).rows[0].id;
check('acceptance creates connection', !!connection);
await denied('active connection prevents a new request', mentee, `select public.mentorship_send_request('${mentor}', 'Again')`);
await denied('active connection prevents a reverse request', mentor, `select public.mentorship_send_request('${mentee}', 'Again')`);
const legacyRequest = (await db.query(`insert into public.mentorship_requests (mentee_id, mentor_id, message) values ('${mentee}', '${mentor}', 'Legacy') returning id`)).rows[0].id;
await denied('legacy pending request cannot create a duplicate connection', mentor, `select public.mentorship_respond_request('${legacyRequest}', true)`);
await db.exec(`delete from public.mentorship_requests where id = '${legacyRequest}'`);
await denied('outsider cannot add goal', other, `insert into public.mentorship_goals (connection_id, title) values ('${connection}', 'Private')`);
const goal = (await as(mentee, `insert into public.mentorship_goals (connection_id, title) values ('${connection}', 'Plan') returning id`)).rows[0].id;
await as(mentor, `update public.mentorship_goals set progress_percent = 50 where id = '${goal}'`);
await count('participants see progress history', mentee, 'select * from public.mentorship_goal_progress', 2);
await count('outsider cannot read progress history', other, 'select * from public.mentorship_goal_progress', 0);
await denied('participants cannot forge progress history', mentee, `insert into public.mentorship_goal_progress (goal_id, progress_percent) values ('${goal}', 99)`);
await as(mentor, `insert into public.mentorship_check_ins (connection_id, note, meeting_at, next_steps) values ('${connection}', 'Private note', now() + interval '1 day', 'Follow up')`);
await count('outsider cannot read private check-in', other, 'select * from public.mentorship_check_ins', 0);
await count('recipient sees request and goal notifications', mentor, 'select * from public.notifications', 2);
await count('mentee sees acceptance, goal and scheduled check-in notifications', mentee, 'select * from public.notifications', 3);
await denied('outsider cannot end mentorship', other, `select public.mentorship_end_connection('${connection}')`);
await as(mentee, `select public.mentorship_end_connection('${connection}')`);
await denied('ended mentorship cannot add check-in', mentor, `insert into public.mentorship_check_ins (connection_id, note, meeting_at) values ('${connection}', 'No', now())`);
const nextRequest = (await as(mentee, `select public.mentorship_send_request('${mentor}', 'Another') as id`)).rows[0].id;
await denied('mentor cannot cancel outgoing request', mentor, `select public.mentorship_cancel_request('${nextRequest}')`);
await as(mentee, `select public.mentorship_cancel_request('${nextRequest}')`);
await count('cancelled request removed', mentee, `select * from public.mentorship_requests where id = '${nextRequest}'`, 0);
const declined = (await as(mentee, `select public.mentorship_send_request('${mentor}', 'Try again') as id`)).rows[0].id;
await as(mentor, `select public.mentorship_respond_request('${declined}', false)`);
await denied('request cannot be answered twice', mentor, `select public.mentorship_respond_request('${declined}', true)`);
console.log(`\n${passed} passed, ${failed} failed`);
await db.close();
process.exit(failed ? 1 : 0);
