# ROCKS Connect authentication fix report

## 1. Root cause

The simulator error came from the Debug build launched for the preceding redesign review: its `SUPABASE_URL` and `SUPABASE_ANON_KEY` were deliberately overridden to empty values. The app correctly selected `UnavailableAuthService`, so real login and password recovery could not work. The error was not proof of an incorrect password.

The ignored local `Config.Development.xcconfig` has a syntactically valid HTTPS URL and a publishable-format key. Their project, validity, and environment have **not** been verified; the owner said the environment is unknown and must not be contacted. No configuration values were printed, changed, or sent to a service.

## 2. Files modified

- `ROCKS/App/AppState.swift`, `ROCKS/App/ROCKSApp.swift`, `ROCKS/App/RootView.swift`
- `ROCKS/Info.plist`
- `ROCKS/Services/AuthService.swift`, `ROCKS/Services/SupabaseAuthService.swift`
- `ROCKS/ViewModels/AuthViewModel.swift`, `ROCKS/Views/LoginView.swift`
- `ROCKSTests/ROCKSTests.swift`, `README.md`
- This report

Existing work was checkpointed in Git as `31d228d` before authentication changes. Authentication changes remain uncommitted.

## 3. Supabase configuration

Existing Debug xcconfig inclusion and the existing shared client are retained. The local values are not automatically a safe staging environment. Release uses `Config.example.xcconfig` defaults and needs approved build-time configuration through an appropriate secure workflow. Never put a secret/service-role key in the app.

Supabase Swift is pinned at **2.55.2**. Its `emitLocalSessionAsInitialSession: true` option was already configured; this work did not upgrade the SDK.

## 4. Login

**Implemented but awaiting live verification.** The branded login now has password visibility and email/empty-password validation. Existing users with passwords shorter than eight characters are no longer rejected solely by a new-password rule. Selected invalid-credentials and unconfirmed-email errors are clearer. Loading and the Debug-only local demo remain.

The existing server does **not** distinguish approved members from applicants, so a successful real login does not currently prove membership eligibility. No real login was tested.

## 5. Create account

**Incomplete or blocked.** The form collects first name, last name, email, password, and confirmation and validates them locally. Submitting to Supabase is intentionally blocked in the iOS service because membership approval, enforceable permissions, and approved terms/privacy documents are not defined. Form values are not submitted. Chapter selection and legal acknowledgments were not invented. Name metadata transmission, signup, duplicate handling, and profile creation are therefore not complete.

The client-side block does **not** stop direct Supabase Auth signup or API access. An authorized administrator must assess the project's signup settings and policies.

## 6. Email verification

**Incomplete or blocked.** No signup confirmation callback, email delivery, or verified-email-to-approval flow was implemented or tested. Do not treat successful email confirmation as organizational membership.

## 7. Password recovery

**Implemented but awaiting live verification.** A separate request screen validates the address and displays a privacy-preserving confirmation only when the request succeeds. The existing Supabase service requests a PKCE recovery redirect to `org.rocksinc.rocks://recovery`. The app registers that scheme, handles the recovery link, provides matching new-password fields, updates through Supabase, and requires recovery-session sign-out before returning to Sign In. It identifies rate-limiting and several invalid/expired-link cases.

PKCE requires requesting and opening the link on the same device. Custom URL schemes are not exclusive to an app; PKCE protects the code exchange but the full flow still requires staging security and device testing. No actual reset email, link exchange, or password update was tested.

## 8. Session restoration and sign-out

**Implemented but awaiting live verification.** Existing restoration uses `client.auth.session`, checks expiration, fetches the role, avoids a login flash, and surfaces refresh/network failure without authenticating. Unknown roles now fail closed rather than defaulting to `member`. The recovery screen stays separate from the dashboard; a persisted marker causes an interrupted recovery session to be closed instead of restored as a normal login. Local mocks cover this behavior and sign-out failure.

The SDK configuration option is covered by a local test; the warning and real expired-token refresh have not been verified against a configured server. Live sign-out and revoked-token behavior remain unverified.

## 9. Membership approval

**Incomplete or blocked.** Migration 008 creates a `member` profile for new Auth users; there is no pending/approved membership field, approved verification process, approval workflow, or comprehensive RLS gating. The owner confirmed the process is undecided. Existing permissions therefore may allow a newly registered Auth user to access member functionality. No unapproved person should be treated as an approved ROCKS member.

Decide the authoritative membership source, who may approve or revoke access, allowed pending-user actions, and a migration/backfill strategy for existing members. Enforce the resulting rules in the database and trusted functions, not just SwiftUI. The app currently cannot show a trustworthy pending status.

## 10. Security

Changes avoid embedding private keys, do not auto-grant administrator roles, reject unknown profile roles, restrict the recovery callback to the app's recovery URL, and keep recovery sessions out of ordinary navigation. Registration is blocked only in this client pending a server-side solution.

Existing RLS/profile-consent and membership issues remain open; see [the Phase 5 report](ROCKS_PHASE_5_BETA_REPORT.md). No new security audit or live policy test was performed.

## 11. Database migrations

None created or applied. Migration 008 and the existing profile role guard were inspected. Migration 011 remains locally tested but undeployed. No production data was changed.

## 12. Build results

Xcode 16.4, iPhone 16 simulator, iOS 18.6, arm64, blank Supabase build settings:

- Debug simulator test build: **passed**.
- Release simulator build: **passed**.
- Earlier intermediate attempts failed due to a Swift view-scope/compiler error and a shared Xcode build database lock; both were corrected and the final runs passed.
- Package-cache refresh produced `safe.bareRepository` warnings, but resolution and builds completed.

## 13. Automated tests

Final XCTest suite: **66 passed, 1 skipped, 0 failed**. The skipped test requires simulator notification authorization and is unrelated to authentication.

New synthetic tests cover registration validation and client blocking, invalid recovery destinations, recovery email validation, recovery-session closure, interrupted recovery, and failure to close recovery. Existing mock tests cover missing, validated, and failed session restoration and the SDK option. They do not prove Supabase email delivery, the SDK/server PKCE exchange, actual token expiry, or server authorization.

## 14. Simulator testing

Tests ran on the iPhone simulator with blank backend values. No manual visual interaction, email-link tap, keyboard/accessibility audit, physical device, or light/dark authentication walkthrough was performed. The prior Computer Use service was unauthorized and was not retried.

## 15. Manual Supabase Dashboard configuration

Use a **separate, explicitly approved staging project**, synthetic accounts, and an administrator:

1. In the staging project's **Connect / API Keys**, obtain its Project URL and publishable (or legacy `anon`) key. Enter them only in the ignored `Config.Development.xcconfig`; encode the URL as `https:/$()/PROJECT.supabase.co` for xcconfig. Do not paste keys in chat or use a secret/service-role key.
2. Verify Email authentication and confirmation settings under **Authentication → Providers → Email** and configure suitable staging email delivery under **Authentication → SMTP Settings**. Never claim delivery until an actual synthetic email is received.
3. Under **Authentication → URL Configuration → Redirect URLs**, allow the exact recovery URL `org.rocksinc.rocks://recovery`. Confirm the recovery template uses the Supabase confirmation link. Test request, same-device link opening, expiry, password update, sign-out, and a subsequent login.
4. Review whether public signup is enabled and whether existing RLS permits unapproved accounts to read/write member data. Do not make production changes from this report; have an authorized administrator review and test an approved staging policy first.
5. Agree and approve the terms/privacy documents and membership verification process before implementing signup and enabling member access. Add and test the separately designed signup confirmation callback only when that flow is implemented.

## 16. Remaining work and readiness

Authentication is **not complete**. Live login, signup, email confirmation, profile creation, membership approval, recovery completion, real-session expiry, live sign-out, and server-side authorization have not been verified end to end. Registration and verification are blocked; server-side membership enforcement and legal documents do not exist. Current profile visibility and role policies still require independent review.

Before any real-member rollout: identify a safe staging project; agree on membership and pending-access rules; implement and test the server-enforced lifecycle and approved legal acknowledgments; finish registration/verification; run the full synthetic end-to-end flows and device/accessibility tests; and resolve the documented privacy blockers.

### Classification summary

| Feature | Classification |
| --- | --- |
| Local validation, recovery-state gate, callback routing | Implemented but awaiting live verification; focused local tests passed |
| Supabase login, recovery request/update, session restoration and sign-out | Implemented but awaiting live verification |
| Local demo login | Demo only |
| Registration, profile provisioning verification, email confirmation, membership approval and server-side pending-user restriction | Incomplete or blocked |
