# CMSN / Commission

**Founder visual review — Revision 02:** // in black and white and the first CMSN wordmark are approved. The spelled-out COMMISSION artwork and stacked lockup are rejected and must not be used. CMSN// remains horizontal; its revised slashes extend slightly beyond the N and sit farther away. Use 32px for the selected small digital symbol presentation. Apparel is primarily symbol-led, with shirt, tights/pants and bottle placements approved in direction.


One brand umbrella: native training app, website, identity, apparel and campaigns.


## Canonical product

- `ios/CMSNApp/`: SwiftUI Training Kernel, native Xcode project and tests.
- `app/`, `public/`, root package files: working Next.js 16 website; kept in place to preserve deployment paths. `web/README.md` maps this surface.
- `brand/master/`: previously approved CMSN glyph geometry and validator.
- `brand/identity/`, `brand/guidelines/`, `brand/exports/`: production candidates, governance, export references.
- `apparel/`: Collection 01 preparation, placements, flats and references.
- `content/`: campaign, social and AI production planning.
- `strategy/`: product and business source links.

Read `docs/consolidation/2026-09-14.md` for branch provenance, validation and founder review. This is a founder-review baseline, not an App Store release certification.

## Run

Website: `npm ci`, `npm run dev`. Checks: `npm run lint`, `npm run build`.

App: open `ios/CMSNApp/CMSNApp.xcodeproj`. Configuration changes belong in `project.yml`; regenerate with XcodeGen 2.46.0 and commit the synchronized project/plists. Xcode 26.6 is the tested toolchain; iOS deployment target remains 17.

Creative masters live in the CMSN Creative Cloud workspace. Existing purchased Opus files remain at their original paths until a verified cloud copy exists; no destructive migration or separate clothing repo.
