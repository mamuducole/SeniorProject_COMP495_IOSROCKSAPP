# The ROCKS, Inc. iOS

Native SwiftUI iPhone application for The ROCKS, Inc., built for iOS 17+.

## Redesign (2026)

The app follows the "ROCKS Refresh" design language: deep navy/black, warm gold, off-white, and subtle gray — fully adaptive across dark and light appearance. Everything is built on a shared design system in `ROCKS/DesignSystem/` (`AppTheme.swift` tokens + `ROCKSComponents.swift` components), so cards, buttons, navigation, typography, icons, spacing, and colors stay consistent across screens.

**Navigation:** Home / Connect / Events / Learn / You. Connect contains the Community Board, mentorship, member and chapter directories, and More from ROCKS; Learn contains publications, scholarships, and program guides.

**Feature surfaces**
- **Home** — branded hero, member-count card, quick actions, upcoming events, and featured programs.
- **Learn** — publications and offline guides for leadership development, networking, leadership outreach, and community service, alongside scholarship resources.
- **Connect / More from ROCKS** — community and mentorship tools plus an offline directory for organization information, membership, chapters, events, and official resources.
- **Chapters** — searchable chapter list and map placeholder until verified coordinates are available.
- **Events** — verified upcoming and past events in list or monthly calendar views, with personal local reminders.
- **Profile** — member details and shortcuts to personal event, mentor, resource, and impact surfaces.

## Requirements

- macOS with Xcode 16 or later
- iOS 17 SDK
- Swift 5.9+ / Swift 6 compatible toolchain
- Supabase project for backend features

## Opening in Xcode

1. Copy `Config.example.xcconfig` to a local configuration file such as `Config.Development.xcconfig`.
2. Add development-only Supabase values to that local file. Put URL values in xcconfig form, for example `SUPABASE_URL = https:/$()/your-project.supabase.co`; URL slashes need this escape so xcconfig does not parse `//` as a comment. The app expands the configured values into its Info.plist at build time.
3. Open `ROCKS.xcodeproj` in Xcode.
4. Select an iPhone simulator or connected device and run the `ROCKS` scheme.

The Debug configuration explicitly enables local demo authentication. A successful demo login switches the entire app to local mock repositories; it does not create a Supabase session. Known donation, renewal, and chapter sign-up entry points are disabled in demo mode; other external website paths still need a complete manual review before demonstrations. Without Supabase configuration, regular account authentication and live data are unavailable. Never commit Supabase keys, payment URLs containing private tokens, service-role keys, or local configuration files.

**Registration requires migration 012.** The app submits first/last name, an optional requested chapter, and a versioned data-use acknowledgment to Supabase Auth. Migration 012's trigger creates a `guest` profile with `membership_status = pending`; a database constraint ties `approved` to a non-guest role, so pending, declined, and suspended accounts cannot read or write member data. Chapter and national administrators approve, decline, or suspend accounts from the Admin Dashboard. Signup confirmation emails redirect to `org.rocksinc.rocks://auth-callback`, which must be allow-listed under **Authentication → URL Configuration → Redirect URLs**. Optional `TERMS_URL` and `PRIVACY_POLICY_URL` build settings show approved legal documents during registration; none exist yet. Do not deploy the registration build before 012 is applied, or new signups receive the older trigger's `member` role.

Password recovery uses the PKCE redirect `org.rocksinc.rocks://recovery`. For an approved staging project, add this exact URL under **Authentication → URL Configuration → Redirect URLs**, configure email delivery, and test using a synthetic account. The request and link must be opened on the same device because the PKCE verifier is stored there. A recovery session is kept out of the dashboard and closed before returning to Sign In. Email delivery and recovery completion remain unverified until tested with staging.

## Local demo account

The Debug/simulator configuration enables the fixed demo credentials:

- Email: `demo@rocks.org`
- Password: `rocks1234`

Demo sessions are stored in the device Keychain and can be signed out normally. Demo access is compiled only when `DEMO_MODE_ENABLED` is explicitly added to the Swift compilation conditions and the Info.plist setting is enabled. The Release configuration disables it, excludes the password code at compile time, and has a build-phase validation that fails if the demo setting or compilation condition is enabled. Demo users have the ordinary member role, are clearly labeled as non-production, and all demo mutations use local repositories.

## Architecture

The app uses SwiftUI, MVVM, async/await, Codable models, and protocol-driven repositories/services. Supabase is the backend source of truth via `supabase-swift` (see `ROCKS/Services/SupabaseAuthService.swift` and `ROCKS/Services/SupabaseRepositories.swift`). Every repository has a mock implementation returned by `AppEnvironment.preview`; `AppEnvironment.makeLive()` selects Supabase implementations when credentials are present.

## Backend

Database migrations and seed data live in `supabase/`:
- `001_initial_schema.sql` — chapters, profiles, events, registrations.
- `002_redesign_features.sql` — community feed (posts, likes, comments), mentorship (profiles, requests, connections, goals, check-ins), notifications, scholarships, plus RLS policies.
- `007_community_board_security.sql` — Community Board hardening: blocks members from changing their own `role`/`chapter_id`/`email`, replaces the all-columns profile read policy with the email-free `member_public_profiles` view, adds author-only post editing (`edited_at`), limits writes to non-guest members, and bounds post/comment length. **The app now reads other members' profiles from `member_public_profiles`, so apply 007 before shipping a build containing it.**
- `008_profile_creation.sql` — creates an ordinary `member` profile for every new `auth.users` account and backfills existing auth users that do not yet have a profile.
- `009_mentorship_security.sql` — adds opt-in mentor visibility, participant-authorized request transitions, private goal progress, check-in actions, and database notification records.
- `011_profile_privacy_and_registration.sql` — restricts biography and chapter in the attribution view, exposes separately opted-in chapters in a mentor-directory view, and disables registration inserts while preserving cancellation.
- `012_membership_approval_and_moderation.sql` — locally tested, not deployed: membership status and admin review, applicant read restrictions, content reports and national moderation, notification guard, account deletion RPC, audit extension, feed indexes.

Review and test migrations using synthetic accounts on an approved development or staging project before considering deployment. Obtain approval before applying them; never apply untested migrations to production. Seed content must remain public/example data and must not contain private member information.

### Community Board (ROCKS Connect)

Open it from **Connect → Community Board**. Members can create, edit, and delete their own text posts; like/unlike; open a post to read and add comments; and delete their own comments. Guests can read but not write. Authorization is enforced by RLS; the UI only hides controls. Every write waits for Supabase to confirm it. A failed request shows an error and never pretends to succeed, and an edit or delete that RLS filters out is reported as "not permitted".

Policy tests run against a throwaway in-memory Postgres, never a real project:

```
npm install --no-save @electric-sql/pglite
node supabase/tests/community_board_rls.test.mjs
```

Before production, apply the migrations to a staging project, then sign in as two ordinary members and one guest and check: post/edit/delete own post; like, unlike, and like again; comment and delete own comment; that a member cannot edit or delete another member's post or comment; that a guest cannot write; and that `select email from profiles` returns only the caller's own row.

### Mentorship (Phase 3)

Open **Connect → Mentorship**, or follow the in-app mentorship link from CHAMP or the member directory. Demo mode uses fictional, in-memory data. Members explicitly opt into the mentor directory and can hide their listing; chapter sharing is separately optional. Matching uses the interest/goal terms entered while browsing, compares them with voluntarily shared mentor specialties, interests, and career field, and explains the overlap. Suggestions are not relationships.

Live mentorship no longer depends on a Debug-only client switch. Access is enforced by the server: migration 009's functions and policies require an approved (non-guest) member, and participants alone can read requests, connections, goals, and check-ins. Migration 009's unique indexes reject existing duplicate pending requests or active connections in either direction of a pair; resolve duplicates through an authorized data review before migrating. Do not apply migrations to production without staging verification and approval.

Migration 011 (deployed to the configured staging project) limits biography and chapter to the owner in the general attribution view and shares a mentor's chapter only when the directory and chapter-sharing options are both enabled. Migration 012 further limits the attribution view to approved members viewing other approved members. Names, roles, ranks and avatar paths remain visible to approved members; a member-consent policy for a full directory is still required, so the Member Directory screen lists no members. Notification records are not push notifications.

Run local database policy checks without a Supabase project:

```
node supabase/tests/mentorship_rls.test.mjs
```

The tests use `@electric-sql/pglite` as described above; they do not replace multi-user Supabase staging, privacy, and concurrency verification.

### Administrative backend (Phase 4 foundation)

**Not production-ready.** Migration `010_admin_security_foundation.sql` has only been exercised locally; do not apply it to production. An explicitly enabled Debug/staging dashboard supports editing a chapter's description, email and HTTPS website and viewing the latest 50 scoped administrative activity records. It does not update the current bundled member-facing chapter directory. It does not implement membership decisions, event/publication management, notifications for announcements, or moderation. No role-assignment workflow is provided.

Existing authentication creates a `member` profile, but that is not verification of official ROCKS membership. Until ROCKS confirms the authoritative membership source, administrators must use an independently approved manual verification process; the app neither approves membership nor treats an account as proof of membership. Do not copy real membership data into test accounts.

The Admin Dashboard appears for signed-in chapter and national administrators in live builds. Every operation is authorized by the server (migrations 010 and 012); the client does not grant access. Admin roles and chapter assignments must be provisioned by an authorized backend operator; the app does not bootstrap administrator accounts. Never include a service-role key in the app.

#### Architecture and permission inventory

The database contains chapters, profiles, events, event registrations, posts, likes, comments, mentorship profiles/requests/connections/goals/check-ins/progress, notifications, scholarships and news articles. Live repositories use Supabase for these models, but the currently displayed Chapters and Events screens use bundled data. Publications use an empty bundled catalog and the PDF reader; there is no publication table, upload, or private storage workflow. Auth supports Supabase and Debug-only demo sessions; members can delete their account in the app (migration 012). The notification inbox reads database records, not push delivery. Demo repositories use fictional local data.

The table below describes the **database policies after migration 010**, not future permissions. "Scoped" means the administrator's assigned `chapter_id`. The `mentor` role retains ordinary member access; `guest` is more restricted. The app dashboard is staging-only.

| Resource / operation | Member | Chapter admin | National admin |
| --- | --- | --- | --- |
| Own profile | Read/edit nonprivileged fields; no self-promotion | Same | Same; no in-app role assignment |
| Other full profiles / membership decisions | No; public attribution view remains broader than consent | No approval or management workflow | No approval or management workflow |
| Chapters | Read active | Read active and assigned; update assigned, but cannot create, delete or change activation | Read, create, update and delete |
| Events | Read published | Read published; no write policy | Read published; no write policy |
| News articles | Read published | Read published | Read drafts and create/update/delete articles |
| Publications / PDFs | Bundled/public files only | No publishing workflow | No publishing workflow |
| Community | Read and manage own posts, likes and comments | Same; cannot create global announcements | Same; may create official feed posts as self |
| Reports and moderation | No reporting workflow | No moderation workflow | No moderation workflow |
| Mentorship and notifications | Own/participant-scoped access | Same | Same; no broad private mentorship access |
| Administrative activity | No access | Read assigned-chapter records | Read all records; no API writes |

Migration 010 removes the former chapter-admin global announcement permission because feed posts have no chapter audience. It prevents announcement-author impersonation, narrows chapter deletion and activation, enables national admins to read news drafts, and adds append-only API audit records for chapter, role/chapter assignment, event, news and official-feed changes. Logs contain IDs, action and time, not content or credentials; privileged external operations may have no authenticated actor. Existing migration 009 may reject legacy duplicate active connections or pending requests and must be reviewed before staging. The existing public profile view's lack of per-field consent remains a production blocker.

Locally run:

```
node supabase/tests/admin_security.test.mjs
node supabase/tests/community_board_rls.test.mjs
node supabase/tests/mentorship_rls.test.mjs
```

These in-memory tests are not live Supabase, storage, multi-user concurrency, load, or UI tests. Audit indexes support recent and chapter-scoped reads; the dashboard caps results at 50. Existing feed and member directory reads are not paginated and need performance work. No new paid service is introduced; database/audit growth and any future storage or delivery costs depend on actual usage and the Supabase plan. No 2,500-concurrent-user capacity claim has been tested.

### Official events

The Events tab works entirely offline using bundled [`events.json`](ROCKS/Resources/events.json). No Supabase configuration, database migration, API, or network refresh is required. The file contains only the two event titles and dates verified on the [official November 2026 calendar](https://rocksinc.org/content.aspx?club_id=459944&page_id=4001) on November 17, 2026. Times, locations, hosts, and descriptions were not verified and are left null. Other tabs and their existing Supabase functionality are unchanged.

To update events:
- Edit `ROCKS/Resources/events.json`. Add or remove array entries; use `[]` for an empty calendar.
- Keep each event's UUID stable when editing; generate a new UUID for a new event.
- Supply `title`, `event_date` in `YYYY-MM-DD` form, and `source_url` pointing to the official ROCKS verification page.
- Optional `starts_at` and `ends_at` use ISO 8601 timestamps with seconds and a UTC offset (`Z` or `±HH:MM`). When supplying a start, also supply an IANA `time_zone`; the start must fall on `event_date` in that zone.
- Leave unverified `starts_at`, `ends_at`, `time_zone`, `location`, `host`, and `description` null or omit them. Never invent missing details.
- Build and distribute an app update after changes. **Bundled event changes require a rebuild/app update**; they do not sync remotely.

Upcoming includes the entire event day, even after a published start time; past events are shown newest first. Both list and monthly calendar use the same bundled records. Reminders persist on the device and use native iOS local notifications. Permission is requested only when the user chooses a reminder. Timed reminders use the event's time zone; date-only reminders use 9:00 AM in the device's local time zone. Opening Events or returning to it in the foreground reconciles saved reminders with the bundled calendar, including date changes delivered in an app update. Reminder times already in the past cannot be scheduled. iOS permits at most 64 pending notifications per app.

### News and publications

The News quick action and Resources → ROCKS News open the publications library and the existing sample news articles. The library uses the bundled `ROCKS/Resources/publications.json` catalog, which is currently empty: `ROCKS_REFRESH_Week_12_Future_of_Mentorship.pdf` was not present in the workspace. Do not add a record until the authorized PDF and its verified metadata are available.

To add a publication, place the authorized PDF in `ROCKS/Resources`, add it to the ROCKS target's Copy Bundle Resources in Xcode, and add an entry to `publications.json`. Each entry requires a stable UUID `id`, `title`, `description`, and at least one of `bundled_pdf` (the PDF filename) or `remote_url`. Optional fields are `issue`, `series` (use `ROCKS REFRESH` for that section), and `published_at` (ISO 8601 timestamp, such as `2024-01-01T00:00:00Z`, only when verified). Preserve IDs across updates to retain saved and reading progress. Catalog changes require an app update.

Remote URLs are for documents explicitly authorized for public distribution only. They must use HTTPS and cannot contain credentials, query strings, or fragments; the reader does not send Supabase credentials and rejects insecure redirects. Private/member-restricted PDFs require a separate authenticated authorization and delivery design; do not put private files, service-role keys, or signed URLs in the catalog. No database changes are made: the existing `news_articles` schema contains articles, not publication metadata or PDF access controls.

The PDF reader uses PDFKit, with bookmarks and last-page positions stored locally on the device. Remote files require network access; bundled files work offline. Publication covers are derived from the first page of bundled PDFs; remote documents show a placeholder until opened.

## Testing

Run `ROCKSTests` from Xcode, or from the command line:

```
xcodebuild test -project ROCKS.xcodeproj -scheme ROCKS -destination 'platform=iOS Simulator,name=iPhone 16,arch=arm64' ONLY_ACTIVE_ARCH=YES
```

The suite covers design-token contrast (WCAG), deep links, role permissions, event registration, demo authentication/session persistence and isolation, dashboard/events/feed/mentorship/notifications view models, and Community Board ownership/like/comment/error handling (`CommunityBoardTests`). Tests use mock repositories and must not require live Supabase credentials.

## Assets

`ROCKS/Assets.xcassets` contains the app icon and branding imagery. `Branding/rocksLogo` is the client-supplied emblem, preserved without editing. The app icon is still a generated placeholder and needs an approved, correctly sized icon before App Store submission.

## Configuration still required

- Supabase URL and anon key
- Official donation and membership hosted-checkout URLs
- Approved app icon and confirmation of usage rights for other branding imagery
- Legal/privacy/support URLs
- APNs credentials and notification categories (the notification center is database-driven today)
- Any documented membership or official content APIs

## Security boundary

Authorization must be enforced in Supabase Row Level Security policies. SwiftUI role checks are only presentation logic. Private scholarship documents must remain in private storage with owner/admin policies.
