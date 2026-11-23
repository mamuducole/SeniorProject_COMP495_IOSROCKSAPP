# ROCKS CONNECT — PHASE 5 BETA TESTING & CLIENT APPROVAL REPORT

Date: 22 November 2026

## 1. Executive summary

**Not ready for member beta or release.** Local synthetic database tests reproduced a profile-consent exposure and an authorization gap in event registrations. A forward-only migration addresses the reproduced biography/chapter and registration cases locally, but has not been applied to Supabase; the remaining attribution-consent and membership-verification issues still block real-member use. The requested publication is absent, live mentorship and administration are disabled in Release, and key administrative and moderation workflows do not exist.

The app built and its automated simulator tests passed, but those results do not establish end-to-end operation. No live Supabase project, real member data, visual simulator interaction, or physical device was tested. Computer Use most recently returned “client is not authorized to use this service”; it was not repeatedly retried.

The user approved initializing a local Git repository. Baseline checkpoint `1388671` was created before Phase 5 fixes. The subsequent fixes remain uncommitted in the working tree; no production data was accessed or changed, and no migration was applied to Supabase.

## 2. Scope and evidence

Evidence labels:

- **Tested locally**: a specific automated test passed in the simulator or isolated in-memory PostgreSQL. This is not a claim that the complete feature works end to end.
- **Implemented, unverified**: source code or a backend interface exists but its real operation has not been demonstrated.
- **Demo/static**: sample data, bundled content, or in-memory mock; not a live service.
- **Partial/broken/missing**: the requested capability is incomplete, a defect is evident, or no implementation was found.

Inspected the app root, navigation, authentication and session code; the source for Home, onboarding, login, profile, Explore, chapters, events, news, PDF reader, Community Board, mentorship, directory, notifications, programs, membership, donations and scholarships; repository interfaces and relevant Supabase implementations; role helpers; migrations 001–011; local RLS test harnesses; XCTest files; build configuration, bundled catalogs and branding documentation. Source and symbol searches covered the views and repositories more broadly. This is not an exhaustive manual interaction test of every control or a substitute for an independent security audit.

Files created: this report and `supabase/migrations/011_profile_privacy_and_registration.sql`. Files modified: `ROCKS/Services/SupabaseRepositories.swift`, `ROCKS/Views/HomeView.swift`, `DonateView.swift`, `ProfileView.swift`, `ChapterListView.swift`, `supabase/tests/community_board_rls.test.mjs` and `README.md`. No production data was accessed or changed; no migration was applied to Supabase.

## 3. Feature and navigation inventory

All destinations below are source-inspected; navigation and button taps were not visually exercised.

| Screen / path | Status and data source |
| --- | --- |
| Onboarding → login / registration | **Implemented, unverified** visually. Onboarding completion is local. Supabase login, signup, reset and restoration exist; live email confirmation/reset and token refresh were not tested. Demo login is Debug-only. Account deletion is missing. |
| Home | **Partial**. Static mission, program, membership, directory and news links exist. The notification bell now links to the existing inbox in source; its navigation has not been visually tested. Upcoming section does not display event cards. |
| Programs → program details, CHAMP, scholarship information | **Static/implemented, unverified**. Informational content and external official links; manual web interaction not tested. |
| Chapters → chapter/interest-group details | **Static**. Search and location matching have unit coverage. The visible directory reads bundled `Chapter.examples`, not administrator edits. External website/finder/join links are unverified. |
| Events → list/calendar → event detail → reminders | **Partial**. Bundled events and reminder calculations are covered by unit tests. Both bundled dates are past as of this report; no dynamic publishing or event source-link control is displayed. Native scheduling test skipped; no actual reminder was delivered. Event screens force dark appearance. |
| Profile → events, mentorship, scholarships, membership, directory, official links / sign out | **Implemented, unverified** visually. No account-deletion or complete settings workflow. Renewal and donation are disabled in demo; the CHAMP informational link remains accessible. |
| Explore → about, membership, resources, community, mentorship, directory, scholarships, media, donate, profile | **Implemented, unverified** visually. Admin entry is shown only for staging-enabled live admin sessions. |
| Community → compose, edit/delete, likes, post detail and comments | **Partial**. Mock behavior and local SQL authorization checks passed; live persistence and restart, API integration, and screen interaction were not tested. Replies to comments, following, chapter discussions, reporting, moderation, feed pagination and community notifications are missing. |
| News → library → publication detail → PDF reader | **Partial**. The production library catalog is empty and the requested Week 12 PDF is absent. Synthetic PDF parsing, saved state and filters have unit coverage; visual rendering/zoom and remote download are untested. News screen shows explicitly labelled sample articles rather than the live news repository. |
| Directory → official member portal / opted-in mentorship | **Partial**. The in-app member list is deliberately empty; member profiles and search cannot be verified against a real authorized directory. The proposed migration narrows biography/chapter access but the public-profile view still exposes other fields without an approved consent model (QA-001). |
| Mentorship → discovery, profile, requests, connections, goals, check-ins | **Demo/staging only**. Local mocks and isolated policy tests cover selected logic; live client/RPC integration and privacy in staging are unverified. Release explicitly disables the live mentorship repository. Matching compares voluntarily entered terms; it is not a confirmed relationship. |
| Notifications inbox | **Connected, visually unverified**. Home now links to the existing view. Records are not remote push. Notification deep links are incomplete (QA-004). |
| Admin dashboard → scoped chapter editor / activity | **Partial, staging-only**. Local RLS tests cover selected permissions and audit protection. Actual staging API operations, UI, and audit history have not been tested; Release disables the dashboard. Chapter database edits do not update the bundled directory. |
| Admin membership, events, publication upload, announcements, reports, moderation | **Missing**. No approval/rejection, account status/role assignment, event publishing, PDF storage/upload, announcement notification distribution, reporting or moderation workflow was found. |
| Scholarships | **Partial**. Official informational pages are static; a separate scholarship center has a Supabase repository and demo data. Neither live retrieval nor external application was tested. |
| Donate / membership | **Partial**. Official website handoff exists. Known demo donation and renewal controls are now disabled in source; manual coverage of external website paths is still required. |
| Media / resources / about | **Static/implemented, unverified**. Curated bundled assets and website links. |
| Android | **Missing/unverified**. No Android project was found in the workspace; no Android build or device test was run. |

### Source inventory of interactive controls

The following inventory records intended actions, not successful taps. Dynamic list entries represent one control per item.

- **Onboarding/login:** Skip, Next/Get Started, email/password input, Sign In, Create an Account, Forgot Password, reset confirmation, registration Create Account and Cancel.
- **Home:** notifications bell; Become a Member; Find a Mentor; Scholarships; Membership; Member Directory; News; Donate; Events See All; featured program cards.
- **Programs:** each program card; Learn More on Website.
- **Chapters:** search, clear search, each chapter/interest-group row, chapter website when present, official finder and membership links.
- **Events:** upcoming/past/reminders and list/calendar pickers; month previous/next and day buttons; event rows; Remind Me, timing choices, Remove Reminder and Cancel.
- **Profile:** My Events, Mentorship, Scholarships, Directory, Membership Details, Renew Membership, CHAMP, See All, membership/directory rows, Donate, About, Help and Sign Out.
- **Explore/resources:** directory cards and tab-switch buttons; Members Directory, Mentorship, Community, conditional Admin, Scholarships, Media, Donate and Profile; resource links and official external links.
- **Community:** compose prompt and toolbar button, feed refresh, post open/comment, like/unlike, own-post Edit/Delete with confirmation, composer Cancel/Post/Save, comment entry/send, own-comment Delete with confirmation, retry and error dismissal.
- **News/PDF:** publication search, issue/year filters, publication and news cards, Read/Continue, Save/Remove, reader Close, bookmark, previous/next page and retry; PDFKit scroll/zoom gestures require manual testing.
- **Mentorship:** refresh, CHAMP, Find/Become Mentor, hide profile, request accept/decline/cancel, connection and mentor cards, search/preferences/availability and field filters, request sheet/send, specialties add/remove, consent/availability/chapter toggles, join, connection end/confirm, goal add/save/progress menu, check-in log/date/save.
- **Admin:** chapter row, description/email/website fields, Save, refresh/retry; activity rows are informational.
- **Notifications:** Home bell, Mark all read and notification rows when a route exists. Routing requires visual and staging verification.
- **Membership, scholarships and donate:** renewal, join, CHAMP, eligibility/contact, scholarship application/details/announcements and donation-fund website buttons. Known demo payment/sign-up entry points are guarded; other external paths need review.

Search fields, system back buttons, alert confirmations, official-link sheet dismissal, standard text entry and keyboard behavior also require manual verification.

## 4. Build and automated tests

Xcode 16.4 resolved `supabase-swift` **2.55.2** and other package dependencies. A build/test using a fresh session-derived-data directory for iPhone 16 / iOS 18.6 succeeded:

| Suite | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| XCTest simulator suite | 57 | 0 | 1 |
| Local admin policy checks | 28 | 0 | 0 |
| Local Community Board policy checks | 55 | 0 | 0 |
| Local mentorship policy checks | 30 | 0 | 0 |

The skipped XCTest requires simulator notification authorization. The suite includes mocked authentication/session states, role helpers, Community Board actions and errors, mentor filtering and mocked actions, a generated two-page PDF, local publication state, event reminder calculations, and selected contrast values. It does **not** test actual Supabase token refresh or a real PDF's original layout.

Separate synthetic local probes reproduced QA-001 and QA-005 before the fixes; new local checks pass against migration 011. The post-fix Release iPhone simulator build and simulator test build both succeeded; the prior Release configuration check confirmed its demo, mentorship-staging and admin-staging flags were `NO`. Swift package cache update attempts reported `safe.bareRepository` errors but package resolution and the test build completed; Xcode also reported skipped App Intents metadata extraction. No compilation errors were reported. No physical device was tested, despite Xcode listing one as a destination.

Unexecuted: live signup/email confirmation/reset, expired/invalid real-session refresh and sign-out, Supabase client/RPC integration, persistence after app restart, real PDF/remote downloads, UI navigation, gestures, light/dark screenshots, accessibility/large text, network conditioning, actual local notification delivery, performance/load, Android and all missing workflows.

## 5. Bug inventory

Unless a status below says otherwise, defects remain open. “Source-inspected” means the control flow establishes the issue, but no visual or live backend reproduction was performed.

### QA-001 — P0: profile fields exposed without per-field consent

- **Surface:** database `member_public_profiles`, used for Community attribution and member/mentor data.
- **Reproduce:** in the isolated local schema, create synthetic accounts A and B; set B's biography and chapter without field consent; query the view as A.
- **Expected:** only fields B authorized for A are returned.
- **Actual:** A received both biography and chapter. No real account data was used.
- **Root cause:** [migration 007](supabase/migrations/007_community_board_security.sql) grants authenticated users access to a view containing those fields without consent filtering. Automatically created `member` profiles are not proof of ROCKS membership.
- **Correction:** design consent-aware attribution and authorization, preserve required post attribution without disclosing private fields, review migration compatibility, and verify in staging with synthetic roles. Do not enable real member testing meanwhile.
- **Status:** **partially mitigated locally, not deployed**. Migration 011 limits general-view biography/chapter to the owner, and separately exposes opted-in mentor chapters to non-guests; local checks verify consent, revocation and guest/anonymous denial. Other users' chapter affiliation no longer appears on Community posts. Names, roles, ranks and avatar paths remain broadly enumerable, and the `member` role is not verified membership. Obtain a consent/identity policy and independently review/test the complete exposure before real-member use. The mentor client now needs migration 011 for shared chapters; its existing capability check only verifies 009.

### QA-002 — P1: demo mode can open real donation and renewal destinations

- **Surface:** Home, Donate and Profile.
- **Reproduce:** source inspection: in demo, use Home Donate or Explore → Donate → a fund; Profile also exposes Renew Membership. Do **not** complete a real payment while testing.
- **Expected:** demo must prevent external payment/renewal actions as documented.
- **Actual:** those actions open the official website without a demo guard, although other demo screens disable similar actions.
- **Root cause:** [HomeView.swift](ROCKS/Views/HomeView.swift), [DonateView.swift](ROCKS/Views/DonateView.swift) and [ProfileView.swift](ROCKS/Views/ProfileView.swift) do not consistently check `isDemoUser`.
- **Correction:** consistently gate payment/renewal/external application actions in demo and add focused tests.
- **Status:** known Home/Donate/Profile donation and renewal controls and the chapter-detail sign-up control are disabled for demo users in source. No targeted UI automation or visual test verified these guards; other external website paths require review.

### QA-003 — P1: Home notifications button does nothing

- **Surface:** Home bell.
- **Reproduce:** inspect/tap the bell in an authenticated session.
- **Expected:** open the notifications inbox.
- **Actual:** the button closure is empty; no non-preview `NotificationsView` caller was found.
- **Root cause:** placeholder action in [HomeView.swift](ROCKS/Views/HomeView.swift).
- **Correction:** connect the existing inbox to Home navigation and test routing and failure states.
- **Status:** Home now uses a navigation link to the existing inbox; compilation and the general automated suite do not verify a tap or notification routing. Deep links remain incomplete (QA-004).

### QA-004 — P1: deep links are not end-to-end

- **Surface:** external links and notification routes.
- **Reproduce:** inspect built Info.plist and route handlers; attempt an event link on a simulator once UI testing is available.
- **Expected:** `rocks://` routes open the proper destination.
- **Actual:** the built plist has no `CFBundleURLTypes`; `onOpenURL` only records a route, the events screen has no pending event handler, and mentor routing requires the mentorship view to be active. A parser-only unit test passes.
- **Root cause:** missing URL registration and incomplete central routing.
- **Correction:** register an approved scheme, route after authentication and tab selection, and test cold/warm start and each destination.

### QA-005 — P1: guest can register for an unpublished event through the API

- **Surface:** `event_registrations` RLS.
- **Reproduce:** in local in-memory PostgreSQL, create a synthetic guest and unpublished event, then insert a registration as that guest.
- **Expected:** unapproved registration and unpublished-event access are denied.
- **Actual:** the insert succeeded.
- **Root cause:** [migration 001](supabase/migrations/001_initial_schema.sql) only requires `profile_id = auth.uid()`; it does not enforce role, publication or registration approval.
- **Correction:** decide whether registration is approved; if not, disable the backend path through a reviewed forward migration. If approved, enforce role, published status, event eligibility and cancellation rules server-side. Test in staging.
- **Status:** migration 011 removes the authenticated insert policy pending approval and leaves existing registrations and own-cancellation intact. Synthetic tests reject member and guest inserts and permit cancellation. This intentionally disables API registration for all authenticated users, is not deployed, and requires stakeholder review and synthetic staging verification before any application.

### QA-006 — P1: confirmed feed write may be reported as failed

- **Surface:** create post and comment.
- **Reproduce:** source-inspected failure path: allow the insert to succeed, then fail the subsequent author-profile fetch.
- **Expected:** distinguish a committed write from a failed insert and avoid duplicate retries.
- **Actual:** both operations wrap insert and profile lookup in one error handler; a later lookup failure is presented as a failed publish/comment even though the insert has committed.
- **Root cause:** sequential calls in [SupabaseRepositories.swift](ROCKS/Services/SupabaseRepositories.swift).
- **Correction:** return the committed result independently of optional attribution fetch, or implement an idempotent/transactional operation; add a regression test. Live failure injection has not been performed.

### QA-007 — P1: membership verification and account deletion are missing

- **Surface:** registration, profile and administration.
- **Reproduce:** create an auth account in a synthetic staging project, or inspect [migration 008](supabase/migrations/008_profile_creation.sql) and Profile.
- **Expected:** authentication must be separate from official membership approval, with a supported deletion process.
- **Actual:** signup creates a `member` role directly; no official membership verification, approval/status workflow or account-deletion action exists.
- **Root cause:** identity and membership lifecycle integration is incomplete.
- **Correction:** agree on the authoritative membership source and safe manual/integration boundary; implement server-enforced eligibility and a reviewed deletion workflow.

### QA-008 — P1: admin chapter updates do not reach the visible directory

- **Surface:** staging Admin → Chapters; Chapters tab.
- **Reproduce:** inspect the editor repository and `ChapterListView`.
- **Expected:** an approved chapter update appears in the member directory without a rebuild.
- **Actual:** admin edits the database while the tab uses bundled `Chapter.examples`.
- **Root cause:** disconnected content sources.
- **Correction:** integrate a verified, authorized remote source with an explicit offline/error policy and tests. No staging update was performed.

### QA-009 — P1: requested publication is unavailable

- **Surface:** News & Publications.
- **Reproduce:** inspect `ROCKS/Resources/publications.json` and workspace filenames.
- **Expected:** authorized Week 12 PDF is available and can be read.
- **Actual:** catalog is `[]`; the requested PDF was not found.
- **Root cause:** authorized asset and verified metadata have not been supplied.
- **Correction:** obtain the authorized file and metadata, add it to the target, and test original layout, offline use and page/zoom behavior. Do not fabricate content.

### QA-010 — P2: static sample news is shown rather than live news

- **Surface:** News.
- **Reproduce:** inspect `NewsView` and `NewsArticle.examples`.
- **Expected:** official published articles are loaded from the backend.
- **Actual:** source always displays labelled sample articles with relative dates; the live news repository is not used by this screen.
- **Root cause:** disconnected repository and static sample collection.
- **Correction:** connect verified published news with loading, empty and error states; retain sample data only in clearly identified demos.

### QA-011 — P2: feed stops at 50 posts and counts can be truncated

- **Surface:** Community feed/detail.
- **Reproduce:** inspect `fetchPosts` and `compose`; verify server row limits using synthetic staging data before measuring impact.
- **Expected:** older posts remain reachable and counts/comments are complete.
- **Actual:** only the newest 50 posts are fetched, with no next page. Likes/comments are fetched as raw rows without pagination or server-side aggregation; configured API row limits can truncate them.
- **Root cause:** fixed limit and unbounded related-row queries.
- **Correction:** add cursor pagination and authoritative aggregate/count queries with tests. This is a source-based risk; no load test was run.

### QA-012 — P2: event source links and current events unavailable in app

- **Surface:** Events.
- **Reproduce:** inspect the bundled catalog and event detail.
- **Expected:** users can open an event's verification source and see current verified events.
- **Actual:** detail has no source-link control; both bundled dates are past as of this report.
- **Root cause:** static catalog and unused `sourceURL` in detail.
- **Correction:** expose the verified source safely and establish an approved update process; do not invent events.

### QA-013 — P2: accessibility and branding need verification

- **Surface:** Events, Programs, Home and motion.
- **Reproduce:** source inspection; manual verification remains required.
- **Expected:** approved official logo, light/dark support, accessible controls and Reduce Motion.
- **Actual:** README identifies the bundled emblem and app icon as placeholders; Events and program detail force dark appearance. No explicit Reduce Motion handling was found for several animations; the Home bell is 38 points square.
- **Root cause:** unfinished asset approval and inconsistent appearance/accessibility design.
- **Correction:** obtain approved assets, test Dynamic Type, VoiceOver, Reduce Motion, contrast, safe areas, keyboard and touch targets on small/large devices in both appearances.

### QA-014 — P2: misleading password claim and potential session/profile race

- **Surface:** Membership copy and authentication state.
- **Reproduce:** inspect Membership text and Login; separately simulate delayed profile loading and rapid account changes in a future test.
- **Expected:** accurately distinguish official membership passwords from app authentication and never show a previous account's profile.
- **Actual:** Membership states the app never collects passwords, while Login has a password field. `AppState.authenticate` launches an untracked profile-fetch task; a late result could overwrite cleared or newer state. The race is **suspected from source**, not reproduced.
- **Root cause:** ambiguous copy and absence of an identity check/cancellation around the async result.
- **Correction:** clarify credential scope and add a deterministic delayed-repository regression test before changing session logic.

## 6. Backend and security findings

Local tests use synthetic accounts and PGlite stand-ins, not Supabase staging. They demonstrated author-only post/comment deletion, duplicate-like prevention, participant-only mentorship notes, selected chapter-scope restrictions and API audit-log protection. They do not prove deployed policy versions, concurrent behavior, storage policies, privileged operator integrity or production security.

The app config opts into the Supabase 2.55.2 initial-session behavior. The installed SDK source places the warning in the *other* branch, and a unit test checks the option; this is strong code evidence, **not** a live observation proving the warning has disappeared. Real expired-session refresh and failure behavior remain unverified.

The admin audit is not retroactive; privileged external activity can have a null actor, and a database owner can administer underlying tables. The local migration 009 unique indexes may reject legacy duplicates. Do not apply migrations without approval, a backup and staging verification.

## 7. UI, accessibility and performance

Only selected design-token contrast assertions ran. There were no visual inspections, screenshots, gesture tests, VoiceOver, Dynamic Type, keyboard, Reduce Motion, small/large screen or network-condition tests. External links were not opened. The approved official logo and motto need client confirmation; placeholder assets must not be presented as approved.

The feed has a 50-post cap and fetches raw related rows; the directory source is static and other queries have limited or no pagination. PDF downloads use in-memory data and have no measured file-size/memory envelope. Startup, memory, offline recovery, concurrency and load have not been measured. There is no evidence for 2,500 simultaneous active users or a production capacity estimate.

## 8. Beta testing plan

### Prerequisites and safe accounts

1. Establish a separate, explicitly identified Supabase staging project. Obtain approval before applying reviewed migrations; never point synthetic tests at production.
2. Resolve QA-001 and QA-005, test all RLS paths using synthetic member, guest, chapter admin A/B and national admin accounts, and independently review policy changes.
3. Use fake names, emails, chapters, content and PDFs with no personal data. Assign roles only through an authorized staging operator. Never distribute service-role credentials.
4. Manually verify demo external-payment safeguards and remaining external paths before any demonstration. Supply an authorized Week 12 PDF and approved logo/metadata before presenting them.
5. Prepare a supported iOS build, privacy/legal links, account deletion path, test instructions and an agreed feedback channel. Do not represent unimplemented features or demo records as live.

### Tester checklists

- **Member:** sign up/confirm, sign in/out, reset, restore sessions, validate errors and ownership; review consent and directory privacy.
- **Community:** create/edit/delete own post, like/unlike repeatedly, add/delete own comment, refresh/restart, try denied cross-account changes; identify missing report/reply features rather than simulate them.
- **Mentorship:** with staging enabled, opt in, discover/filter, request/accept/decline/cancel, manage connection/goals/check-ins, inspect notification records, and deny unrelated access. Do not assert remote push.
- **News/PDF:** use an authorized test file; verify original pages, pinch, scroll, page numbers, bookmarks, restart, offline bundled use, remote failure and invalid file handling.
- **Chapter admin:** verify assigned versus unrelated chapters, audit visibility and denied role promotion. Note that member-facing chapter updates are not integrated.
- **National admin:** verify scoped data and audit protection; mark membership, events, publication publishing, announcements and moderation as unavailable until implemented.
- **General:** test both appearances, small/large screens, VoiceOver, larger text, keyboard, Reduce Motion, airplane mode, error recovery and real-device reminders.

Feedback should go to a designated project owner through an approved private channel. Never include member details, credentials or session tokens. Record build/version, device/OS, synthetic role, environment, steps, expected and actual outcome, severity, time, screenshots only if free of sensitive data, and whether reproducible.

### Client demonstration script

Only after the prerequisites above: identify the build and explicitly label all synthetic data; show Home and the inbox only after its navigation is verified, Community using staging test data, the protected-directory informational screen, demo/staging mentorship, bundled Events, and the empty publication state. Show the PDF reader only after an authorized asset is supplied. Show staging chapter editing and audit only to authorized participants and explain that other admin workflows are absent. Do not enter real payment flows or suggest this is production-ready.

## 9. Readiness decision and actions before Phase 6

| Audience | Decision | Reason |
| --- | --- | --- |
| Internal developer testing | **Ready with limitations** | Local tests and demo work are possible; use synthetic data and avoid external payment actions. |
| ROCKS leadership demonstration | **Not ready** | Demo guards and notification entry require manual verification; approved logo/PDF and clear staged content are missing. |
| Small member beta | **Not ready** | Consent exposure, membership verification and staging authorization are unresolved. |
| Broader member beta | **Not ready** | Critical security, incomplete features, device/accessibility and load validation remain. |

Rough, subjective estimate: **40% of the requested cross-platform beta-readiness scope**; this is not a measured completion metric and does not imply Android support.

Before Phase 6: fix remaining P0/P1 issues and retest; confirm the official membership source and approved privacy model; independently review migration 011, obtain approval, and perform synthetic multi-user staging tests; complete the requested admin/moderation and publication workflows; supply approved assets; validate real devices, UI accessibility, network failure, persistence and capacity; obtain client sign-off. No app-store submission or production migration is authorized by this report.
