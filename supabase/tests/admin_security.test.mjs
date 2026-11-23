import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

// Synthetic accounts and an in-memory database only; never connects to Supabase.
const dir = fileURLToPath(new URL('../migrations', import.meta.url));
const db = new PGlite();
let passed = 0, failed = 0;
const check = (name, condition, detail = '') => {
  if (condition) { passed++; console.log('PASS', name); }
  else { failed++; console.error('FAIL', name, detail); }
};

await db.exec(`
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
  create schema auth;
  create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb not null default '{}'::jsonb);
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  grant usage on schema auth, public to anon, authenticated, service_role;
  grant execute on function auth.uid() to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`);
for (const file of fs.readdirSync(dir).filter(name => name.endsWith('.sql')).sort()) {
  const sql = fs.readFileSync(`${dir}/${file}`, 'utf8').replace(/create extension if not exists pgcrypto;/, '');
  await db.exec(sql);
}

const member = 'a0000000-0000-0000-0000-000000000001';
const chapterAdmin = 'a0000000-0000-0000-0000-000000000002';
const otherAdmin = 'a0000000-0000-0000-0000-000000000003';
const national = 'a0000000-0000-0000-0000-000000000004';
const chapter = 'b0000000-0000-0000-0000-000000000001';
const otherChapter = 'b0000000-0000-0000-0000-000000000002';
await db.exec(`
  insert into public.chapters (id, name, city) values
    ('${chapter}', 'Test chapter', 'Test'), ('${otherChapter}', 'Other chapter', 'Test');
  insert into auth.users (id, email) values
    ('${member}', 'member@example.test'), ('${chapterAdmin}', 'chapter@example.test'),
    ('${otherAdmin}', 'other@example.test'), ('${national}', 'national@example.test');
  update public.profiles set role = 'member', membership_status = 'approved';
  update public.profiles set chapter_id = '${chapter}' where id in ('${member}', '${chapterAdmin}');
  update public.profiles set role = 'chapter_admin' where id = '${chapterAdmin}';
  update public.profiles set chapter_id = '${otherChapter}', role = 'chapter_admin' where id = '${otherAdmin}';
  update public.profiles set role = 'national_admin' where id = '${national}';
`);

async function as(user, sql) {
  await db.exec(`select set_config('request.jwt.claim.sub', '${user ?? ''}', false); set role ${user ? 'authenticated' : 'anon'}`);
  try { return await db.query(sql); } finally { await db.exec('reset role'); }
}
async function count(name, user, sql, expected) {
  try {
    const result = await as(user, sql);
    const actual = /^\s*select/i.test(sql) || /returning/i.test(sql) ? result.rows.length : result.affectedRows;
    check(name, actual === expected, `expected ${expected}, got ${actual}`);
  } catch (error) { check(name, false, error.message); }
}
async function rejects(name, user, sql) {
  try { await as(user, sql); check(name, false, 'expected a permission error'); }
  catch { check(name, true); }
}

await rejects('member cannot promote themselves', member, `update public.profiles set role='national_admin' where id='${member}'`);
await count('member fails admin capability check', member, `select public.admin_phase4_ready() where public.admin_phase4_ready()`, 0);
await count('chapter admin passes admin capability check', chapterAdmin, `select public.admin_phase4_ready() where public.admin_phase4_ready()`, 1);
await rejects('anonymous cannot check admin capability', null, `select public.admin_phase4_ready()`);
await count('member cannot update a chapter', member, `update public.chapters set description='no' where id='${chapter}' returning id`, 0);
await count('chapter admin can update assigned chapter', chapterAdmin, `update public.chapters set description='updated' where id='${chapter}' returning id`, 1);
await count('chapter admin cannot update another chapter', chapterAdmin, `update public.chapters set description='no' where id='${otherChapter}' returning id`, 0);
await count('chapter admin cannot change another member role', chapterAdmin, `update public.profiles set role='chapter_admin' where id='${member}' returning id`, 0);
await rejects('chapter admin cannot deactivate their chapter', chapterAdmin, `update public.chapters set is_active=false where id='${chapter}'`);
await count('chapter admin cannot delete their chapter', chapterAdmin, `delete from public.chapters where id='${chapter}' returning id`, 0);
await rejects('chapter admin cannot create chapters', chapterAdmin, `insert into public.chapters (name, city) values ('Not authorized', 'Test')`);
await count('national admin can update any chapter', national, `update public.chapters set description='national' where id='${otherChapter}' returning id`, 1);
await rejects('chapter admin cannot publish global announcement', chapterAdmin, `insert into public.posts (author_id, kind, body) values ('${chapterAdmin}', 'announcement', 'Global')`);
await rejects('national admin cannot impersonate another author', national, `insert into public.posts (author_id, kind, body) values ('${member}', 'announcement', 'Spoof')`);
await count('national admin can publish as themselves', national, `insert into public.posts (author_id, kind, body) values ('${national}', 'announcement', 'Official') returning id`, 1);
await rejects('member cannot publish news', member, `insert into public.news_articles (author_id,title,summary,body) values ('${member}','Title','Summary','Body')`);
await count('national admin can create news draft', national, `insert into public.news_articles (author_id,title,summary,body) values ('${national}','Title','Summary','Body') returning id`, 1);
await count('national news change is audited', national, `select id from public.administrative_activity where resource_type='news_articles' and action='insert' and actor_id='${national}'`, 1);
await count('national announcement is audited', national, `select id from public.administrative_activity where resource_type='posts' and action='insert' and actor_id='${national}'`, 1);
await count('national admin can read news draft', national, `select id from public.news_articles where not is_published`, 1);
await count('member cannot read news draft', member, `select id from public.news_articles where not is_published`, 0);
await count('chapter admin sees their chapter audit', chapterAdmin, `select id from public.administrative_activity where resource_id='${chapter}' and actor_id='${chapterAdmin}' and action='update'`, 1);
await count('other chapter admin cannot see that audit', otherAdmin, `select id from public.administrative_activity where resource_id='${chapter}'`, 0);
await count('member cannot read audit', member, `select id from public.administrative_activity`, 0);
await rejects('member cannot forge audit records', member, `insert into public.administrative_activity (action,resource_type,resource_id) values ('update','chapters','${chapter}')`);
await rejects('national admin cannot modify audit', national, `update public.administrative_activity set action='forged'`);
await rejects('national admin cannot delete audit', national, `delete from public.administrative_activity`);
// Fixture approval (guest -> member), chapter assignment, and promotion are each audited.
await count('national admin sees membership, chapter, and role changes', national, `select id from public.administrative_activity where resource_type='profiles' and resource_id='${chapterAdmin}'`, 3);

console.log(`\n${passed} passed, ${failed} failed`);
await db.close();
process.exit(failed ? 1 : 0);
