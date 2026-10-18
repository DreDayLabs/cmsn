# Higgsfield originals

Full-resolution source media generated in Higgsfield for the CMSN app. The
downsized copies the app actually ships live in
`ios/CMSNApp/CMSNApp/Resources/`; these are the masters they were cut from.

The binaries are stored in **Git LFS** (see `/.gitattributes`), so they do not
bloat normal git history. After cloning, run `git lfs pull` to fetch them.

## Contents

90 files, about 380 MB.

| Date (UTC) | What | Model |
|---|---|---|
| 2026-08-23 | 7 moody monochrome training photos + dark-gym welcome loop | Soul v2, Seedance 2.5 |
| 2026-08-23 | 7 bright high-key monochrome photos + bright-gym loop | Soul v2, Seedance 2.5 |
| 2026-08-24 | ~60 commercial campaign photos (Nike/Equinox direction) and their edits | Soul v2, Nano Banana 2 |
| 2026-08-24 | 3 locked-tripod athlete clips | Veo 3.1 |
| 2026-08-27 | 7 CMSN-emblem fitness background loops (9:16, 6s) | Seedance 2.5 |
| 2026-09-10 | 3 Commission apparel hero product shots | Nano Banana 2 |

`manifest.json` records, for every file: the Higgsfield job ID, model, full
prompt, reference media, creation time, CDN URL, size and sha256.

## Restoring and verifying

```sh
media/higgsfield/fetch.sh
```

Downloads anything missing (including un-pulled LFS pointers) from the
Higgsfield CDN and checks every file against the manifest's sha256.

## In Higgsfield

The same jobs are filed in the Higgsfield project **CMSN (Commission) App
Media** (`8559d449-e503-4e77-9da1-aed571134ff4`), under `Images/` and
`Videos/`. Generate new CMSN work into that project so it doesn't get mixed
into the general generation history again, and add the result here with an
entry in `manifest.json`.

## Not included

Higgsfield work for other projects in the same account (Bloomit, SEAM,
Walkstack, BASTE, Cali's World, and the Sep 10 batch of food photography) is
not part of CMSN and was left out on purpose.
