# Bebas Neue

Not bundled in this repo — binary font files can't be authored by an agent that
can only write text. `CMSNTypography.display`/`.displaySmall` reference it by
name and fall back to the system font automatically until it's here, so the
app builds and runs correctly either way; this is a visual-polish gap, not a
build blocker.

## Drop-in steps (once, on your Mac)

1. Download the OFL-licensed family from Google Fonts:
   https://fonts.google.com/specimen/Bebas+Neue
2. Unzip it, find `BebasNeue-Regular.ttf`, and put it in this folder
   (`ios/CMSNApp/CMSNApp/Resources/Fonts/BebasNeue-Regular.ttf`) — the exact
   filename matters, it's what `UIAppFonts` in `project.yml` already
   references.
3. Delete this README (or leave it, it won't affect the build).
4. `cd ios/CMSNApp && xcodegen generate`, rebuild. `CMSNTypography`'s
   `Font.custom("BebasNeue-Regular", ...)` calls will pick it up with no
   further code changes — this folder is already included in the target's
   bundled resources.
