import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

// Applies every migration to a throwaway in-memory Postgres (PGlite) with stand-ins for
// Supabase's auth schema and API roles, then exercises the Community Board RLS policies.
// Never point this at a real project. Run: npm install --no-save @electric-sql/pglite && node supabase/tests/community_board_rls.test.mjs
const dir = fileURLToPath(new URL('../migrations', import.meta.url));
const db = new PGlite();
let pass = 0, fail = 0;
const ok = (name, cond, extra='') => { if (cond) { pass++; console.log('PASS', name); } else { fail++; console.log('FAIL', name, extra); } };

// Supabase stand-ins: roles, auth.uid(), auth.users, default grants.
const supabaseStandIns = `
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
  create schema auth;
  create table auth.users (
    id uuid primary key,
    email text,
    raw_user_meta_data jsonb not null default '{}'::jsonb
  );
  create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema auth to anon, authenticated, service_role;
  grant execute on function auth.uid() to anon, authenticated, service_role;
  grant usage on schema public to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`;
await db.exec(supabaseStandIns);
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.sql')).sort()) {
  let sql = fs.readFileSync(`${dir}/${f}`, 'utf8').replace(/create extension if not exists pgcrypto;/, '');
  try { await db.exec(sql); console.log('applied', f); } catch (e) { console.log('MIGRATION FAILED', f, e.message); process.exit(1); }
}
// Re-applying already-deployed 007 and 008 must be idempotent. Check on a separate
// database so re-running older definitions cannot mask later migrations below.
{
  const replay = new PGlite();
  await replay.exec(supabaseStandIns);
  for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.sql') && f < '009').sort()) {
    await replay.exec(fs.readFileSync(`${dir}/${f}`, 'utf8').replace(/create extension if not exists pgcrypto;/, ''));
  }
  try { await replay.exec(fs.readFileSync(`${dir}/007_community_board_security.sql`, 'utf8')); ok('007 is re-runnable', true); } catch (e) { ok('007 is re-runnable', false, e.message); }
  try { await replay.exec(fs.readFileSync(`${dir}/008_profile_creation.sql`, 'utf8')); ok('008 is re-runnable', true); } catch (e) { ok('008 is re-runnable', false, e.message); }
  await replay.close();
}

const A='a0000000-0000-0000-0000-00000000000a', B='b0000000-0000-0000-0000-00000000000b', G='c0000000-0000-0000-0000-00000000000c', N='d0000000-0000-0000-0000-00000000000d';
await db.exec(`
  insert into auth.users (id, email, raw_user_meta_data) values
   ('${A}','alice@private.test','{"first_name":"Alice","last_name":"Able"}'),
   ('${B}','bob@private.test','{"first_name":"Bob","last_name":"Baker"}'),
   ('${G}','gina@private.test','{"first_name":"Gina","last_name":"Guest"}'),
   ('${N}','nate@private.test','{"first_name":"Nate","last_name":"National"}');
  insert into public.profiles (id, first_name, last_name, email, role, membership_status) values
   ('${A}','Alice','Able','alice@private.test','member','approved'),
   ('${B}','Bob','Baker','bob@private.test','member','approved'),
   ('${G}','Gina','Guest','gina@private.test','guest','pending'),
   ('${N}','Nate','National','nate@private.test','national_admin','approved')
   on conflict (id) do update set
     first_name = excluded.first_name,
     last_name = excluded.last_name,
     email = excluded.email,
     role = excluded.role,
     membership_status = excluded.membership_status;
`);

async function as(uid, sql, params=[]) {
  await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false); set role ${uid ? 'authenticated' : 'anon'};`);
  try { return await db.query(sql, params); } finally { await db.exec('reset role;'); }
}
async function rejects(name, uid, sql) {
  try { const r = await as(uid, sql); ok(name, false, `expected error, got ${r.affectedRows ?? r.rows.length} rows`); }
  catch (e) { ok(name, true); }
}
async function affects(name, uid, sql, n) {
  try { const r = await as(uid, sql); const c = /^\s*select/i.test(sql) || /returning/i.test(sql) ? r.rows.length : (r.affectedRows ?? 0); ok(name, c === n, `affected ${c}, expected ${n}`); }
  catch (e) { ok(name, false, e.message); }
}

// New-auth-user trigger behavior.
const NEW = 'e0000000-0000-0000-0000-00000000000e';
await db.exec(`
  insert into auth.users (id, email, raw_user_meta_data)
  values ('${NEW}','new.member@private.test','{"first_name":"New","last_name":"Member"}');
`);
let profile = await db.query(`select first_name, last_name, email, role, membership_status from public.profiles where id='${NEW}'`);
ok('auth trigger creates a pending, non-privileged applicant profile (012)',
  profile.rows.length === 1
  && profile.rows[0].first_name === 'New'
  && profile.rows[0].last_name === 'Member'
  && profile.rows[0].email === 'new.member@private.test'
  && profile.rows[0].role === 'guest'
  && profile.rows[0].membership_status === 'pending');

// Role / profile security
await rejects('member cannot self-promote to national_admin', A, `update public.profiles set role='national_admin' where id='${A}'`);
await rejects('member cannot change own chapter', A, `update public.profiles set chapter_id=(select id from public.chapters limit 1) where id='${A}'`);
await rejects('member cannot change own email copy', A, `update public.profiles set email='x@y.z' where id='${A}'`);
await affects('member can still edit own bio', A, `update public.profiles set bio='Hello' where id='${A}'`, 1);
await affects('member cannot edit another profile', A, `update public.profiles set bio='pwned' where id='${B}'`, 0);
await affects('member reads only own full profile row', A, `select * from public.profiles`, 1);
await affects('approved member sees only approved members (self + B + N) via public view (012)', A, `select id from public.member_public_profiles`, 3);
await db.exec(`update public.profiles set bio='Synthetic biography', chapter_id=(select id from public.chapters limit 1) where id='${B}'`);
let privateProfile = await as(A, `select bio, chapter_id from public.member_public_profiles where id='${B}'`);
ok('other member cannot read private biography or unshared chapter', privateProfile.rows[0].bio === null && privateProfile.rows[0].chapter_id === null);
privateProfile = await as(B, `select bio, chapter_id from public.member_public_profiles where id='${B}'`);
ok('owner can read own biography and chapter', privateProfile.rows[0].bio === 'Synthetic biography' && privateProfile.rows[0].chapter_id !== null);
await db.exec(`insert into public.mentorship_profiles (profile_id, directory_visible, share_chapter) values ('${B}', true, true)`);
privateProfile = await as(A, `select bio, chapter_id from public.member_public_profiles where id='${B}'`);
ok('mentor consent does not expose chapter in general attribution view', privateProfile.rows[0].bio === null && privateProfile.rows[0].chapter_id === null);
let directoryChapter = await as(A, `select chapter_id from public.mentor_directory_chapters where id='${B}'`);
ok('non-guest can see explicitly shared mentor chapter in directory', directoryChapter.rows.length === 1 && directoryChapter.rows[0].chapter_id !== null);
directoryChapter = await as(G, `select chapter_id from public.mentor_directory_chapters where id='${B}'`);
ok('guest cannot see chapter shared only in mentor directory', directoryChapter.rows.length === 0);
await rejects('anonymous cannot read mentor directory chapters', null, `select * from public.mentor_directory_chapters`);
await db.exec(`update public.mentorship_profiles set share_chapter=false where profile_id='${B}'`);
directoryChapter = await as(A, `select chapter_id from public.mentor_directory_chapters where id='${B}'`);
ok('revoked mentor chapter sharing takes effect', directoryChapter.rows.length === 0);
await db.exec(`update public.mentorship_profiles set share_chapter=true, directory_visible=false where profile_id='${B}'`);
directoryChapter = await as(A, `select chapter_id from public.mentor_directory_chapters where id='${B}'`);
ok('hidden mentor does not share chapter even when sharing flag remains set', directoryChapter.rows.length === 0);
await rejects('public view does not expose email', A, `select email from public.member_public_profiles`);
await rejects('anon cannot read public view', null, `select id from public.member_public_profiles`);
try { await db.exec(`set role service_role; update public.profiles set role='mentor' where id='${B}'; reset role;`); const q = await db.query(`select role from public.profiles where id='${B}'`); ok('service role can still assign roles', q.rows[0].role === 'mentor'); } catch (e) { await db.exec('reset role'); ok('service role can still assign roles', false, e.message); }
await db.exec(`update public.profiles set bio='admin note' where id='${B}'`);

const EVENT='f0000000-0000-0000-0000-00000000000f';
const PUBLISHED_EVENT='f0000000-0000-0000-0000-000000000010';
await db.exec(`insert into public.events (id,title,category,starts_at,is_published) values ('${EVENT}','Synthetic unpublished event','national',now(),false), ('${PUBLISHED_EVENT}','Synthetic published event','national',now(),true)`);
await rejects('guest cannot register for an unpublished event', G, `insert into public.event_registrations (event_id,profile_id) values ('${EVENT}','${G}')`);
await rejects('member registration remains disabled pending approval', A, `insert into public.event_registrations (event_id,profile_id) values ('${EVENT}','${A}')`);
await rejects('member cannot register for a published event pending approval', A, `insert into public.event_registrations (event_id,profile_id) values ('${PUBLISHED_EVENT}','${A}')`);
await rejects('admin cannot bypass disabled event registration', N, `insert into public.event_registrations (event_id,profile_id) values ('${PUBLISHED_EVENT}','${N}')`);
await db.exec(`insert into public.event_registrations (event_id,profile_id) values ('${EVENT}','${A}')`);
await affects('member can cancel an existing registration', A, `delete from public.event_registrations where event_id='${EVENT}' and profile_id='${A}' returning id`, 1);

// Posts
let r = await as(A, `insert into public.posts (author_id, kind, body) values ('${A}','member','Hello ROCKS') returning id`);
const P = r.rows[0].id; ok('member can create own post', !!P);
await rejects('member cannot post as someone else', A, `insert into public.posts (author_id, kind, body) values ('${B}','member','Spoof')`);
await rejects('member cannot publish announcement', A, `insert into public.posts (author_id, kind, body) values ('${A}','announcement','Official?')`);
await affects('national admin can publish announcement', N, `insert into public.posts (author_id, kind, body) values ('${N}','announcement','Official')`, 1);
await rejects('guest cannot post', G, `insert into public.posts (author_id, kind, body) values ('${G}','member','Guest post')`);
await rejects('empty post body rejected', A, `insert into public.posts (author_id, kind, body) values ('${A}','member','   ')`);
await rejects('overlong post body rejected', A, `insert into public.posts (author_id, kind, body) values ('${A}','member',repeat('x',2001))`);
await affects('pending applicant cannot read posts (012)', G, `select id from public.posts`, 0);
await affects('approved member can read posts', B, `select id from public.posts`, 2);

await affects('author can edit own post', A, `update public.posts set body='Edited body' where id='${P}' returning edited_at`, 1);
r = await db.query(`select edited_at from public.posts where id='${P}'`); ok('edit sets edited_at', r.rows[0].edited_at !== null);
await affects('other member cannot edit post (0 rows)', B, `update public.posts set body='Hijack' where id='${P}'`, 0);
await rejects('author cannot change post kind', A, `update public.posts set kind='announcement' where id='${P}'`);
await rejects('author cannot reassign post author', A, `update public.posts set author_id='${B}' where id='${P}'`);

// Likes
await affects('member can like', B, `insert into public.post_likes (post_id, profile_id) values ('${P}','${B}') on conflict (post_id, profile_id) do nothing`, 1);
await affects('duplicate like ignored (on conflict do nothing)', B, `insert into public.post_likes (post_id, profile_id) values ('${P}','${B}') on conflict (post_id, profile_id) do nothing`, 0);
r = await db.query(`select count(*)::int c from public.post_likes where post_id='${P}'`); ok('like count stays 1', r.rows[0].c === 1);
await rejects('member cannot like on behalf of another', A, `insert into public.post_likes (post_id, profile_id) values ('${P}','${B}')`);
await rejects('guest cannot like', G, `insert into public.post_likes (post_id, profile_id) values ('${P}','${G}')`);
await affects("other member cannot remove someone else's like", A, `delete from public.post_likes where post_id='${P}' and profile_id='${B}'`, 0);
await affects('member can unlike', B, `delete from public.post_likes where post_id='${P}' and profile_id='${B}'`, 1);

// Comments
r = await as(B, `insert into public.post_comments (post_id, author_id, body) values ('${P}','${B}','Nice!') returning id`);
const C = r.rows[0].id; ok('member can comment', !!C);
await rejects('member cannot comment as another', A, `insert into public.post_comments (post_id, author_id, body) values ('${P}','${B}','Spoof')`);
await rejects('guest cannot comment', G, `insert into public.post_comments (post_id, author_id, body) values ('${P}','${G}','Hi')`);
await rejects('overlong comment rejected', B, `insert into public.post_comments (post_id, author_id, body) values ('${P}','${B}',repeat('x',1001))`);
await affects("post author cannot delete another member's comment", A, `delete from public.post_comments where id='${C}' returning id`, 0);
await affects('comment author can delete own comment', B, `delete from public.post_comments where id='${C}' returning id`, 1);

// Deleting posts
await affects('other member cannot delete post', B, `delete from public.posts where id='${P}' returning id`, 0);
await as(B, `insert into public.post_comments (post_id, author_id, body) values ('${P}','${B}','Again')`);
await affects('author can delete own post', A, `delete from public.posts where id='${P}' returning id`, 1);
r = await db.query(`select count(*)::int c from public.post_comments where post_id='${P}'`); ok('comments cascade with post', r.rows[0].c === 0);

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
