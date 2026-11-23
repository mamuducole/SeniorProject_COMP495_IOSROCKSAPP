# ROCKS Connect mobile demo

This is a new, standalone demo based on the SwiftUI screens and assets in the
parent project. It is not the source of the previously shared website, and
building it does not update that site.

## Build and deploy

With Node.js 20 or newer:

```sh
npm ci
npm run check
npm run build
```

Serve `dist/` over HTTP(S), not `file://`. To deploy on Hostinger, upload the
**contents** of `dist/` to the intended site's public web root, preserving
`assets/`. Use HTTPS, and verify that the server serves `.mjs` files as
JavaScript and PDFs as `application/pdf`. Deployment and DNS are not performed
by the build. The manifest enables standalone presentation where supported;
visiting the site normally does not hide browser controls. There is no service
worker or offline cache.

## Demo boundaries

- Choose **Explore Demo** on the sign-in screen. Sign-in, registration,
  password reset, membership renewal, reminders, and mentorship requests are not
  connected to production; do not enter real credentials or personal data.
- Community posts, likes, comments, and appearance settings are stored only in
  browser local storage. Clearing site data removes them. Reset the community
  from You > Settings. Mentorship requests are not sent or saved.
- The member directory does not expose private members. Mentor profiles and
  news articles are labeled as examples. Chapter information and the event
  calendar reflect the bundled iOS source, not a live feed; verify current
  information through ROCKS.
- The iOS publication catalog is empty and contains no bundled PDFs. The build
  generates an original, explicitly labeled one-page sample PDF for the reader.
  It is not a ROCKS publication. The reader uses PDF.js; an open-in-browser
  link is provided as an accessible fallback. PDF.js license is included in
  `dist/assets/pdfjs-LICENSE`.

## Verification performed

Production build and JavaScript syntax checks passed. The built site was served
locally and exercised in a browser using portrait viewport sizes 375×667,
393×852, 440×956, 360×800, 412×915, and 320×568. Across 14 routes at each
size, automated checks found no document-level horizontal overflow, buttons
extending past either side of the viewport, or bottom tab bar displacement.
The centered 430-pixel desktop preview was also checked at 1280×800.

Browser interaction checks covered sample registration, navigation, creating
and liking posts, commenting and persistence after reload, community reset,
chapter search, event list and calendar, and appearance persistence. A shortened
viewport was used to check the post sheet. The sample PDF loaded, rendered
nonblank pixels, and zoomed in the browser; its HTTP response and PDF signature
were also checked.

**Still required before acceptance:** verify the deployed build on physical
iPhone Safari and Android Chrome, including real safe areas, browser toolbar
changes, keyboard behavior, screen-reader use, PDF interaction, and PWA
installation. No side-by-side screenshots of the native iOS app and this build
were captured; close visual parity and pixel-perfect matching are not verified.
The installed iOS simulator app could not be inspected with the available
computer-use service. No deployment to Hostinger has been performed.
