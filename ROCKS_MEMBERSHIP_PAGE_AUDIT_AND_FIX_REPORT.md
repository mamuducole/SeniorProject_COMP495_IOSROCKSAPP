# ROCKS Connect — Membership Page Audit & Fix Report

Date: 2026-11-23 · Builds on `fede195`. Nothing was deployed, no migration was applied, and no membership records were created or changed.

## 1. Membership page overview

`MembershipView` is a hub that hands members off to the official ROCKS membership system (ClubExpress on rocksinc.org). Joining, paying dues, renewing, choosing a membership type, and expiration dates all live there. The app only stores **ROCKS Connect access approval** (`profiles.membership_status`, migration 012). That approval is granted by app administrators and is **not** proof of paid or official ROCKS membership. The page now states this distinction explicitly.

## 2. Files inspected

- **Views:** `MembershipView.swift`, `ProfileView.swift`, `MemberDirectoryView.swift`, `MembersView.swift`, `ExploreMenuView.swift`, `HomeView.swift`, `ChapterListView.swift`, `CHAMPMentorshipView.swift`, `ResourcesView.swift`, `LoginView.swift` (registration)
- **App and services:** `RootView.swift` (status gate), `AuthService.swift`, `SupabaseAuthService.swift`, `SupabaseRepositories.swift`, `AppState.swift`, `AppEnvironment.swift`
- **Models and links:** `User.swift`, `OfficialLinks.swift`, `SafariView.swift`
- **Database:** migrations 001, 007, 008, 010, 011, 012
- **Tests:** `OfficialLinksTests.swift`, plus the Supabase test suites
- **Live check:** the official pages on rocksinc.org

## 3. Bugs discovered

| # | Pri | Bug |
|---|---|---|
| 1 | P0 | **Crash risk.** `officialLinkSheet` passed any URL to `SFSafariViewController`, which raises an uncatchable exception for non-http(s) URLs. Chapter websites come from the database and are admin-editable (`chapter.website`), with no server-side scheme check. HTTP payment pages would also have opened unencrypted. |
| 2 | P1 | The Membership page showed no account or membership status, though the app now stores one. Users could not tell app access apart from official membership. |
| 3 | P1 | **Dead end.** Pending, declined, and suspended accounts (who see the status screen, not the tabs) had no route to Join, Renew, or Contact. Those are the users who need it most. |
| 4 | P2 | Registration never explained that a ROCKS Connect account is not ROCKS membership, and offered no route to the official Join page. |
| 5 | P2 | "Join as a New Member" was buried as a link row among secondary links. The primary actions in the brief (Join and Renew) were not both prominent. |
| 6 | P3 | The page header used a generic shield symbol instead of the official ROCKS logo. |
| 7 | P3 | The Profile "Details" link to Membership was shorter than the 44-pt touch target. |
| 8 | Info | The `MEMBERSHIP_PAYMENT_URL` / `membershipPaymentURL` setting is loaded but used nowhere. It was left unused, not wired to a guessed URL (see section 16). |

No broken links, overlap, or navigation errors were found in the existing page. The back button returns to the presenting screen in both routes because Membership is pushed onto the caller's `NavigationStack`.

## 4. Root causes

- **Bug 1:** Shared helper with no URL validation. Callers trusted their sources.
- **Bugs 2–4:** The page was written before migration 012 introduced account approval. The status gate (also from 012) was built without membership actions.
- **Bugs 5–7:** Styling choices from earlier phases.

## 5. Bugs fixed

| # | Fix |
|---|---|
| 1 | Added `OfficialLinkPolicy.canOpen`: HTTPS with a host only, and no embedded credentials. Any other URL shows a branded "Link unavailable" sheet with Done, instead of crashing. Applies everywhere the sheet is used. |
| 2 | Added a "Your Account" card (`MembershipAccessSummary` / `MembershipAccessCard`) on Membership and You. It shows: approved / awaiting approval / not approved / suspended / demo; the chapter; and a note that dues, membership type, and renewal dates are managed in the official member account. A `guest` role is never displayed as approved, even if the data is inconsistent. |
| 3 | Added Join The ROCKS, Renew Membership, and Contact The ROCKS links to the status screen. |
| 4 | Added a "Not a ROCKS member yet? Join on rocksinc.org" link to registration. The existing footer already says an account does not grant membership. |
| 5 | Added a prominent bordered **Join The ROCKS** button beneath the gold **Renew Membership** button. Removed the duplicate Join row. Clarified the renew/join guidance text. |
| 6 | The header now shows the official `rocksLogo` asset, with a gold border. |
| 7 | The Details link has a minimum height of 44 pt. |

## 6. Membership navigation

| Entry point | Destination | Status |
|---|---|---|
| You → Membership "Details" | `MembershipView` (push) | IMPLEMENTED; compiles and renders |
| You → account list "Membership" | `MembershipView` (push) | IMPLEMENTED |
| Connect → More from ROCKS → Membership | `MembershipView` (push) | IMPLEMENTED |
| Pending / declined / suspended status screen | Official Join, Renew, Contact | IMPLEMENTED (new) |
| Registration | Official Join | IMPLEMENTED (new) |
| Chapter detail → "Become a Member" | Official Join | IMPLEMENTED (unchanged) |
| CHAMP Mentorship → Become a Member | Official Become a Member page | IMPLEMENTED (unchanged) |
| Resources → Membership Information | Official page | IMPLEMENTED (unchanged) |
| Home | No membership entry | Not added. Home had none and adding one would change the approved layout. |

There is still a single Membership page; no duplicates were created. Tap-through navigation was **not** performed on the simulator because Computer Use was not authorized.

## 7. Official URLs verified

Each URL was fetched on 2026-11-23 with an iPhone Safari user agent:

| Action | URL | Result | Label |
|---|---|---|---|
| Join / application / dues | `content.aspx?page_id=60&club_id=459944` | 200, "New Member Sign Up" with membership types and dues | EXTERNAL WEBSITE HANDOFF |
| Renew / existing member sign-in | `content.aspx?page_id=31&club_id=459944&action=login` | 200, Login page. **This is exactly the link the official Join page gives for "Already a member? Click here to login and renew your membership."** | EXTERNAL WEBSITE HANDOFF |
| Benefits & eligibility | `content.aspx?page_id=22&club_id=459944&module_id=793953` | 200, "Become a Member" | EXTERNAL WEBSITE HANDOFF |
| Membership information | `content.aspx?club_id=459944&module_id=123586&page_id=22` | 200, "Membership Information" | EXTERNAL WEBSITE HANDOFF |
| Contact | `content.aspx?page_id=4&club_id=459944` | 200, "Contact Us" | EXTERNAL WEBSITE HANDOFF |

- No URL was changed or invented, and none falls back to the homepage. A test now enforces this.
- Payment happens inside ClubExpress after Join or sign-in. There is no separate payment URL to verify.
- All links open in `SFSafariViewController` over HTTPS. Users return to the app with **Done**.
- Loading in an actual iPhone sheet was not exercised; see section 15.

## 8. Membership status integration

| Data | Stored by the app? | Authoritative source |
|---|---|---|
| Account ID | Yes (`profiles.id` = Auth user) | Supabase Auth |
| ROCKS Connect access status | Yes (`membership_status`, 012) | App administrators via `admin_review_membership` |
| Chapter affiliation | Yes (`chapter_id`; set on approval from `requested_chapter_id`) | App administrators |
| Membership type, expiration, renewal, dues/payment, official verification | **No** | Official ROCKS ClubExpress account |

No fields were added. Statuses, dates, and payment records are never invented. The app never claims a payment or renewal completed.

## 9. Supabase changes

None in this task. The schema was re-verified, and the existing migration 012 already provides status, approval, and chapter. Migration 012 is still **not applied** to staging.

## 10. Security checks

| Check | Result |
|---|---|
| Members cannot approve themselves or change status, role, chapter, or requested chapter | VERIFIED (local DB suite, 90/90) |
| Only scoped chapter or national administrators can approve, decline, or suspend; every decision is audited | VERIFIED (local DB suite) |
| Ordinary members cannot access admin membership functions | VERIFIED (local DB suites, 90/90 and 28/28) |
| An account without approval never gets member features or an "approved" label | VERIFIED (unit tests plus the server constraint) |
| No passwords or card data handled by the app | VERIFIED by inspection. All credentials and payments stay on rocksinc.org. |
| Unsafe and non-HTTPS links refused | VERIFIED (unit test) |
| Expired or invalid sessions do not grant member access | IMPLEMENTED (unchanged; mock-tested) |
| Live RLS on staging | BLOCKED until 012 is applied |

## 11. UI improvements

- Official logo in the header, with a gold-stroked card.
- Account status card.
- Clear primary (gold Renew) and secondary (gold-outlined Join) buttons.
- Concise guidance text.
- Accessible hints on new buttons and a 44-pt Details target.

Rendered checks of the real views, in a hosted window, all showed no clipping or overlap and correct black/gold styling in both appearances:

- iPhone SE width (375 pt), light mode, approved account
- iPhone 16 Pro Max width (440 pt), dark mode, approved account
- iPhone SE width, dark mode, pending status screen

Screenshots are saved in the session folder.

## 12. Files modified

- `ROCKS/DesignSystem/SafariView.swift`: link policy and unavailable-link sheet
- `ROCKS/Views/MembershipView.swift`: logo, account card, Join button, summary model
- `ROCKS/Views/ProfileView.swift`: account card and touch target
- `ROCKS/App/RootView.swift`: membership links on the status screen
- `ROCKS/Views/LoginView.swift`: Join link in registration
- `ROCKSTests/OfficialLinksTests.swift`: 3 new tests

## 13–14. Tests executed and results

| Run | Result |
|---|---|
| XCTest on iPhone 16 simulator (iOS 18.6) | **80 executed: 79 passed, 1 skipped, 0 failed**. The skip is the existing notification-permission test. |
| New tests | Link policy rejects HTTP, mailto, javascript, credential and hostless URLs. Membership actions use their verified destinations and never the homepage. The status summary never treats account creation, guest role, suspension, or demo as approved, and shows chapter and official-dues wording correctly. |
| Release build | Succeeded |
| Database suites | `membership_moderation` 90/90, `admin_security` 28/28 |
| Rendered screenshots | 3 layouts, as listed in section 11 (temporary test, removed afterward) |

## 15. Manual testing required

These were not performed: Computer Use was not authorized, and no real member account was used.

- Tapping through each entry point and back on a simulator and a physical iPhone.
- Opening each official link in the Safari sheet, then Done.
- Behaviour on a network failure: Safari shows its own error page, and Done returns to the app.
- Full Join and Renew flows, including payment. **External payment completion was not tested;** no sandbox exists.
- Live pending → approved transition after applying 012.
- VoiceOver and the largest Dynamic Type size.

## 16. Unresolved issues

- **BLOCKED:** live status verification, because migration 012 is not applied on staging.
- **INCOMPLETE:**
  - Official membership type, expiration, and renewal status cannot be shown. ClubExpress provides no integration to the app, so these are an external handoff by design.
  - Membership benefits are linked to the official page rather than restated; no verified benefits text is bundled.
- **For review:** `MEMBERSHIP_PAYMENT_URL` is configured but unused. Remove it, or wire it to an officially provided payment URL if ROCKS supplies one.
- The Member Directory remains BLOCKED pending a consent policy (prior report).

## 17. Completion estimate

The Membership section is about **85%** complete. Navigation, links, status display, and handoff are done and tested locally. Remaining work is live verification on staging and a physical device, plus any official ClubExpress integration.

## 18. Recommendations before public launch

1. Apply migration 012 on staging and verify pending → approved → member features → suspended with synthetic accounts.
2. Ask ROCKS whether app approval should require proof of current paid ClubExpress membership, and who verifies it.
3. Test every official link and a sandbox or dry-run renewal on a physical iPhone.
4. Decide what to do with the unused `MEMBERSHIP_PAYMENT_URL` setting.
5. Add server-side HTTPS validation for `chapters.website` (defence in depth; the app now refuses unsafe URLs).
6. Run VoiceOver and Dynamic Type checks on Membership and the status screen.

### Function status summary

| Function | Label |
|---|---|
| Membership page display, account card, navigation from You and Connect | IMPLEMENTED BUT NOT LIVE-VERIFIED (rendered and unit-tested) |
| Join The ROCKS, Renew Membership, member sign-in, benefits, information, contact | EXTERNAL WEBSITE HANDOFF (URLs verified) |
| Safe link handling and unavailable-link error | VERIFIED WORKING (unit test) |
| Pending, declined, and suspended status display with membership links | IMPLEMENTED BUT NOT LIVE-VERIFIED |
| Self-approval and role-change prevention; scoped admin approval | VERIFIED WORKING (local DB) / BLOCKED live until 012 |
| Demo membership card | DEMO ONLY |
| Official membership type, expiration, and renewal status in the app | INCOMPLETE (external system) |
| Payment | EXTERNAL WEBSITE HANDOFF; not tested |
