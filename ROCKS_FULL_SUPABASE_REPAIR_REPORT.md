# ROCKS Connect — Full Supabase Repair Report

Date: 2026-11-23 · Branch: `main` · Checkpoints: `1c4d83b` (before work), `c8b15f8` (validated repairs) · Not deployed or published.

## 1. Executive summary

ROCKS Connect's security was in better shape than its functionality. Migrations 001–011 were already deployed to the configured staging project and had closed the earlier self-promotion and profile-email exposure. The main gaps were in the app's workflows:

- Registration was hard-disabled in the client.
- There was no membership-approval concept. Every signup became a full `member`.
- Mentorship and the Admin Dashboard were reachable only in Debug builds with a manual flag.
- A decoding bug broke community, events, profile, and mentorship attribution in live mode.
- There was no reporting, moderation, profile editing, or account deletion.

This work adds forward-only migration **012** and the matching iOS changes:

- Registration with server-enforced pending membership and email confirmation.
- Scoped administrator approval, decline, and suspension, all audited.
- Applicants are blocked from member data.
- Content reporting and national moderation.
- Profile editing and in-app account deletion.
- Notification fixes.
- Server enforcement replaces the Debug-only gates.

All local test suites pass. The new migration has **not** been applied to Supabase, so the new workflows are implemented but not yet live-verified. The app is **not production-ready**. See sections 27–29.

## 2. Original problems found

| # | Severity | Problem |
|---|---|---|
| 1 | P0 | Any signup, including direct API signup, received the `member` role through migration 008's trigger. Organizational membership was never verified. |
| 2 | P0 | Any authenticated account could read every post, comment and like, and enumerate all member names, roles and ranks through `member_public_profiles`. |
| 3 | P1 | `SupabaseFetchHelper.chapterNames()` selected only `id, name` but decoded into `ChapterRow`, which requires `is_active`. Every live call that attributes authors failed: community feed, post create/comment, events, own profile (`currentMember`), and mentorship. Confirmed against live response shape. |
| 4 | P1 | `SupabaseAuthService.signUp` always threw "registration unavailable". |
| 5 | P1 | Mentorship and the Admin Dashboard were gated by `MENTORSHIP_STAGING_ENABLED`/`ADMIN_STAGING_ENABLED`. Both flags were ignored in Release, so these features could never work for members. |
| 6 | P1 | No in-app account deletion, which App Store guideline 5.1.1(v) requires for apps with signup. |
| 7 | P1 | No way to report or moderate user content. App Store guideline 1.2 requires this for UGC. |
| 8 | P2 | "Mark all read" marked notifications read locally even when the server rejected it (false success). There was no single mark-read, and tapping a notification never marked it read. |
| 9 | P2 | Members could rewrite the title and body of their own notification rows. The update policy checked ownership only. |
| 10 | P2 | No profile editing. |
| 11 | P3 | Missing indexes for author/profile lookups and the full notification list. |

## 3. Root causes

- Earlier phases deliberately blocked registration and gated features until a membership policy existed. Your brief now supplies that policy: non-privileged default role, no automatic approval, and email confirmation.
- Issue 3 is a model reuse error. Partial selects reused a full-row DTO with non-optional fields, and mocks bypassed that code path, so tests never caught it.
- Issue 8 came from optimistic UI with no rollback.

## 4. Supabase connection status

| Item | Finding |
|---|---|
| Environment | **Real hosted Supabase project, development/staging.** It contains the dev seed records, and you confirmed it is staging. |
| URL/key source | Ignored `Config.Development.xcconfig`, included by `Config.Development.xcconfig.example`, then injected into Info.plist. URL form is `https://<ref>.supabase.co`. The key is a **publishable** (`sb_publishable_…`) key; no secret or service-role key is present. |
| Release config | `Config.example.xcconfig` has empty values. A Release build falls back to `UnavailableAuthService`/`UnavailableRepositories` and never to demo data. Supply Release values through your build pipeline. |
| SDK | supabase-swift 2.55.2 with a standard `SupabaseClient` init. |
| Connectivity | Verified live with read-only REST/Auth calls. |
| Deployed schema | Migrations 001–011 are present. 012 is absent (its RPCs and table return 404). |
| Session persistence | SDK Keychain storage with `emitLocalSessionAsInitialSession: true`. The app checks `session.isExpired` and never authorizes an expired session. This is the SDK's documented opt-in and resolves the earlier warning. |
| Diagnostics | Missing configuration surfaces as "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY…" without exposing values. |

## 5. Authentication status — IMPLEMENTED BUT NOT LIVE-VERIFIED (partially verified)

Live-verified:

- The wrong-password response returns `invalid_credentials`, which the app maps to "The email or password is incorrect."

Implemented, not live-verified:

- A successful login. No confirmed staging account was available.
- Session restoration, sign-out, and expired-session handling. These are unchanged and mock-tested.

Changed:

- Login now reads `role` **and** `membership_status`; unknown values fail closed.
- Non-approved accounts see a branded status screen with Check Status, Sign Out, and Delete Account, not the member tabs.

## 6. Registration status — IMPLEMENTED BUT NOT LIVE-VERIFIED

What registration collects:

- First and last name, email, password, and password confirmation.
- An optional chapter, loaded live from `chapters` (15 active on staging).
- A required acknowledgment: "I confirm this information is accurate and agree that The ROCKS, Inc. may use it to review my membership and operate ROCKS Connect." The version string is `registration-ack-v1`.

What happens on signup:

- The app calls `auth.signUp` with metadata and `redirectTo: org.rocksinc.rocks://auth-callback`.
- The 012 trigger creates exactly one profile (`on conflict do nothing`) with:
  - role `guest` and status `pending`
  - a validated requested chapter (active chapters only)
  - the acknowledgment timestamp and version only when accepted and versioned
- Metadata cannot set role or status (tested).
- With confirmations on, the app shows "Check your email" and does not reveal whether the address already exists.
- Error messages are mapped and never show raw server text.

Live check: the signup endpoint returned `validation_failed` for a malformed email, which the app maps. No account was created.

**Blocked:** rocksinc.org publishes no Terms or Privacy Policy, so none are linked. `TERMS_URL`/`PRIVACY_POLICY_URL` build settings are ready for approved documents.

## 7. Password recovery status — IMPLEMENTED BUT NOT LIVE-VERIFIED

Unchanged from the prior phase: PKCE request → `org.rocksinc.rocks://recovery` → new password + confirmation → `auth.update` → forced sign-out → Sign In. No reset email was sent during this work. The full flow requires a confirmed staging account, working SMTP, and an allow-listed redirect (section 26).

## 8. Session restoration status — IMPLEMENTED; mock-verified, live-unverified

- Restores and validates the session on launch and on return to the foreground.
- Refresh and network failures do not authenticate.
- Interrupted recovery sessions are closed.
- Confirmation links that arrive during restore are queued and applied afterward.
- Simulator launch restored a persisted local demo session correctly.

## 9. Database schema status

All app tables exist on staging. Migration 012 adds:

- `membership_status` enum, plus these columns on `profiles`: `membership_status`, `requested_chapter_id`, `terms_accepted_at`, `terms_version`, `membership_reviewed_at`, `membership_reviewed_by`
- the `profiles_membership_role_consistent` check constraint
- `content_reports` with a one-target constraint, a reason list, and one open report per reporter and target
- functions: `is_approved_member`, `admin_list_membership_applications`, `admin_review_membership`, `admin_list_open_reports`, `admin_resolve_report`, `delete_own_account`
- triggers: notification update guard, comment-moderation and report audit
- indexes on profile review, report queue, notifications, and post/like/comment author

Tables listed in the brief that **do not exist**, which the app also does not use: saved posts, following, replies, publications, announcements (a separate table), and `audit_logs`. The existing audit table is `administrative_activity`.

Backfill (your decision): existing non-guest profiles become `approved`; existing guests become `pending`.

## 10. Security findings

| Check | Status |
|---|---|
| Members cannot promote themselves | VERIFIED (local DB tests). Guard from 007, extended in 012. |
| Members cannot approve themselves or change status, requested chapter, or acknowledgment | VERIFIED (local DB tests) |
| Database rejects a non-guest role without approval | VERIFIED (local, constraint) |
| Applicants cannot read posts, comments, likes, or the member list | VERIFIED (local) |
| Private profile rows (email) owner-only | VERIFIED (local and existing tests); anon reads 0 rows live |
| Chapter admins limited to their chapter (chapters and applications) | VERIFIED (local) |
| Members cannot run admin operations (list, review, moderation queue) | VERIFIED (local) |
| Members cannot edit or delete others' posts and comments; chapter admins cannot moderate posts | VERIFIED (local) |
| Mentorship data visible to participants only; applicants cannot request mentorship | VERIFIED (local) |
| Audit log not writable, editable, or deletable by any API role | VERIFIED (local) |
| Anonymous access to new functions revoked | VERIFIED (local privilege checks) |
| Live RLS of migration 012 | **BLOCKED** until 012 is applied to staging |

Residual risks:

- Approved members can still see each other's names, roles, and ranks. A consent policy is pending.
- Supabase's default open signup remains on. That is acceptable because signups are now inert until approved, but consider CAPTCHA (section 26).

## 11. Row Level Security validation

Local PGlite with Supabase role stand-ins, applying all migrations 001–012:

| Suite | Result |
|---|---|
| `admin_security.test.mjs` | 28 passed, 0 failed |
| `community_board_rls.test.mjs` | 56 passed, 0 failed |
| `mentorship_rls.test.mjs` | 30 passed, 0 failed |
| `membership_moderation.test.mjs` (new) | 90 passed, 0 failed |
| **Total** | **204 passed, 0 failed** |

Intentional assertion changes in the existing suites, each because of new security behavior:

- New signups are `guest`/`pending`, not `member`.
- Applicants cannot read posts, where guests previously could.
- The attribution view lists approved members only.
- One audit count increased because fixture approvals are now audited.

Fixtures now create approved members explicitly. The 007/008 re-run checks moved to a separate throwaway database so they cannot mask later migrations.

## 12. Storage configuration — INCOMPLETE

- The app expects a public bucket `rocks-public` for `profile_image_path`, `posts.image_path`, and `events.image_path`. **The bucket does not exist** on staging ("Bucket not found"), so those images fall back to placeholders.
- The app contains **no upload code** for avatars, post images, publication covers, or PDFs.
- No buckets or storage policies were created. That requires dashboard/service access and a design decision (section 26).

## 13. Community Board

| Feature | Status |
|---|---|
| Display posts; create, edit, and delete own posts; like/unlike; comment; delete own comment | IMPLEMENTED BUT NOT LIVE-VERIFIED (previously broken live by issue 3; fixed; RLS verified locally) |
| Report post or comment (5 reasons, duplicate-safe, confirmation only on success) | IMPLEMENTED BUT NOT LIVE-VERIFIED (requires 012) |
| National-admin removal of any post/comment, moderation queue, dismiss | IMPLEMENTED BUT NOT LIVE-VERIFIED (requires 012) |
| Replies to comments, saved posts, chapter feed filter, following feed | INCOMPLETE (no schema or UI; not invented) |
| Image posts | INCOMPLETE (no upload or bucket) |

## 14. Mentorship — IMPLEMENTED BUT NOT LIVE-VERIFIED

- Directory, profiles, become/hide mentor, request/accept/decline/cancel, connections, goals with progress history, check-ins, and the notifications produced by those functions are now reachable in all builds.
- Server rules are migration 009 plus 012's approval requirement.
- Live mode shows no invented mentors.
- There are no mentorship records on staging, so this has not been exercised live.

## 15. Member Directory — BLOCKED

The screen intentionally lists no members until ROCKS approves a member-consent model. It still offers search UI, the official ClubExpress directory link, and opted-in mentors. Exposing every approved member without consent was judged unsafe.

## 16. Chapters and Events

| Feature | Status |
|---|---|
| Chapters directory, search, detail | VERIFIED WORKING offline (bundled verified list, unit-tested). The live table is used for registration and admin. |
| Admin chapter edits (scoped) | IMPLEMENTED BUT NOT LIVE-VERIFIED |
| Events tab, calendar, upcoming/past, detail, official links | VERIFIED WORKING offline (bundled verified calendar, unit-tested) |
| Local event reminders | IMPLEMENTED; the authorized-scheduling test is skipped on the simulator (permission) |
| Live `events` table | Not displayed. The staging rows are fictional dev seeds; the app deliberately shows the verified calendar. |
| Admin event publishing, event registration | INCOMPLETE (no admin UI; 011 disabled registration inserts) |

## 17. PDF Reader — INCOMPLETE

The PDFKit reader, saved publications, and reading-progress code exist and are unit-tested. The bundled catalog is empty, and there is no publications table, storage, or admin publishing. No PDFs were invented.

## 18. Notifications

| Feature | Status |
|---|---|
| Inbox, unread count, navigation by route | IMPLEMENTED BUT NOT LIVE-VERIFIED |
| Single mark-read on tap; mark-all with rollback on failure | IMPLEMENTED; unit-tested |
| Content changes blocked server-side (read flag only) | VERIFIED (local DB) |
| Records from mentorship and membership decisions | VERIFIED (local DB) |
| Remote push delivery | INCOMPLETE. These are database records only; there is no APNs. |
| Admin announcements | INCOMPLETE (no UI; national admins may insert announcement posts via RLS) |

## 19. Admin Dashboard — IMPLEMENTED BUT NOT LIVE-VERIFIED

- Visible to chapter and national admins in live builds.
- Membership review: Pending, Approved, Suspended, and Declined lists, with approve, decline, and suspend behind confirmation dialogs. The scope comes from the server.
- National moderation queue: remove content or dismiss.
- Scoped chapter edits and an audit feed.
- Not included: member role management, event publishing, news publishing, and announcements.

## 20. Profile & Settings

| Feature | Status |
|---|---|
| Profile display | IMPLEMENTED BUT NOT LIVE-VERIFIED (was broken live by issue 3) |
| Edit name, rank/title, biography (persisted; validated) | IMPLEMENTED BUT NOT LIVE-VERIFIED |
| Delete account (confirmation; cascades content; audit kept; last national admin protected) | IMPLEMENTED; RPC VERIFIED locally; **hosted permission to delete `auth.users` must be confirmed on staging** |
| Appearance | Follows the system light/dark setting, verified on the simulator. There is no in-app toggle. |
| Notification preferences | INCOMPLETE |
| Sign-out | IMPLEMENTED (mock-tested) |

## 21. Files modified

- **App:** `AppEnvironment.swift`, `AppState.swift`, `ROCKSApp.swift`, `RootView.swift` (adds `MembershipStatusView`), `Info.plist`
- **Models and repositories:** `User.swift`, `ChapterRepository.swift`, `FeedRepository.swift`, `MemberRepository.swift`, `NotificationRepository.swift`
- **Services:** `AuthService.swift`, `SupabaseAuthService.swift`, `SupabaseRepositories.swift`
- **View models:** `AuthViewModel.swift`, `FeedViewModel.swift`, `NotificationsViewModel.swift`
- **Views:** `CommunityView.swift`, `ExploreMenuView.swift` (Admin Dashboard), `HomeView.swift`, `LoginView.swift` (registration), `NotificationsView.swift`, `ProfileView.swift` (adds `EditProfileView`)
- **Tests:** `ROCKSTests.swift`, `FeatureViewModelTests.swift`, `CommunityBoardTests.swift`, `supabase/tests/*.mjs`
- **Config:** `Config.example.xcconfig`, `Config.Development.xcconfig.example`, `project.pbxproj` (removed one dead Info.plist key)
- **Docs:** `README.md`
- **MJ App Demo:** not modified. It is a standalone static site with no Supabase, API, or credential references (checked).

## 22. Migrations created

`supabase/migrations/012_membership_approval_and_moderation.sql`. It is forward-only, tested locally, and **not applied to any project**.

## 23–24. Tests run and results

| Run | Result |
|---|---|
| Xcode Debug build + XCTest (iPhone 16 simulator, iOS 18.6, arm64) | **77 executed: 76 passed, 1 skipped, 0 failed**. Baseline before changes: 67 (66 passed, 1 skipped). |
| Skipped test | `testNativeNotificationSchedulingWhenAuthorized` (simulator notification permission not granted) |
| Xcode Release build | **Succeeded** |
| Database RLS suites | **204 passed, 0 failed** (section 11) |
| Live staging, non-mutating | 6 checks passed: invalid-credentials code; signup validation code; 15 chapters for registration; `{id,name}` response shape; 012 absent; anon reads 0 rows from 5 private tables |

New XCTests cover:

- the registration acknowledgment gate and the request payload
- non-network rejection without acknowledgment
- non-revealing registration errors
- the member-access rule
- pending-applicant routing
- confirmation-link validation
- the chapter decode regression
- profile validation
- report duplicate handling and no false success
- moderator-only removal
- notification rollback

Two old tests asserted the removed staging flags. They now assert that a signed-in session is required, checked before any network call.

## 25. Simulator results

- The Debug build installs and launches.
- Branding, the Home dashboard, and the 5-tab navigation render correctly in light and dark mode.
- Screens were captured with `simctl`. Computer Use was not authorized, so no taps or form entry were performed.

**Outstanding visual and manual tests:** registration form, status screen, admin dashboard, report dialog, edit profile, account deletion, VoiceOver and Dynamic Type, and a physical device.

## 26. Manual Supabase dashboard steps required (staging first)

1. **Apply migration 012.** Use SQL Editor → paste `012_membership_approval_and_moderation.sql` → run. Applying it fixes signups going straight to `member`. Check existing roles first, because the new constraint requires every non-guest to be approved (the backfill handles this).
2. **Redirect URLs.** Under Authentication → URL Configuration, add `org.rocksinc.rocks://auth-callback` and `org.rocksinc.rocks://recovery`.
3. **Email delivery.** Configure custom SMTP under Authentication → SMTP. The default sender reaches project team addresses only. Confirm the confirmation and recovery templates use `{{ .ConfirmationURL }}`.
4. **First national administrator.** Create one with SQL Editor:
   `update profiles set role='national_admin', membership_status='approved' where email='<admin email>';`
   Assign chapter admins the same way with their `chapter_id`.
5. **Account deletion.** As a synthetic user, call `delete_own_account` and confirm the hosted `postgres` role can delete from `auth.users`. If it cannot, move deletion to an Edge Function that uses the service key server-side.
6. **Abuse protection.** Optionally enable CAPTCHA (Authentication → Bot protection). This would also need app support.
7. **Storage.** If avatars and post images are wanted, create `rocks-public` with size and MIME limits and owner-scoped upload policies. Keep any PDFs in a separate private bucket.
8. **End-to-end test** with synthetic accounts: register → confirm email → pending screen → admin approves → member features → report → moderate → edit profile → delete account. Then run password recovery.
9. **Release configuration.** Provide Release `SUPABASE_URL`/`SUPABASE_ANON_KEY` through CI secrets, not committed files.

## 27. Remaining bugs and blockers

- **BLOCKED:** migration 012 is not applied; there is no confirmed staging account, no SMTP, and no approved Terms/Privacy documents; the member-directory consent policy is undecided.
- **INCOMPLETE:**
  - storage and uploads
  - publications backend and PDFs
  - admin event, news, and announcement publishing
  - push notifications
  - notification preferences
  - replies, saved posts, following, and the chapter feed
  - event registration
- **Behavior to note:**
  - Suspending a `mentor` and reinstating them returns the account as `member`.
  - Deleting your own account logs other members' comments on your posts as removed comments in the audit feed.
- **Load testing:** not performed. Claims of support for about 2,500 users are unverified. Queries are bounded (feed limit 50, admin lists 200) and indexed.

## 28. Estimated application completion

About **65%** of the brief's scope. Core auth, membership, community, mentorship, admin, and profile flows are implemented and locally tested. Live verification, storage, publications, publishing tools, and push are missing.

## 29. Production-readiness assessment

**Not production-ready.** The critical membership and access vulnerability is fixed in code and in local tests, but not yet on any server. No essential workflow has been verified end to end against Supabase. Legal documents, SMTP, and device testing are outstanding.

## 30. Recommended next actions

1. Complete the steps in section 26 on staging. Then I can run the synthetic end-to-end and live RLS checks.
2. Approve the Terms and Privacy documents and the member-directory consent model.
3. Decide on storage and publications scope. Then implement uploads and the publications table, with private PDFs.
4. Add admin publishing for events, news, and announcements. Consider APNs push.
5. Run device, accessibility, and load testing before any production migration request.
