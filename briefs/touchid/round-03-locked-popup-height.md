# touchid round 03 — size locked popup to gated content

Repo: /Users/nicholas/Development/maccy-touchid — branch `master` (NOT `main`).
Scope: Maccy app sources only (`Maccy/`), plus the version stamp in the Xcode project.
Context: round 01 (`1601dcb`) added the biometric gate; round 02 (`c4a3495`) fixed the open-flash by disabling animations on the gate refresh and pre-drawing the panel before ordering it front. Current build `2.7.1-touchid-r02`.

On ambiguity, stop and report — never improvise.

## Deliverables

1. **Size the locked popup to its gated content.**
   - Observed defect (user screenshot of r02): while locked, the popup opens at the full stored window height. Only the gated rows render at the top (pins + 3 newest), then a large empty black region, and the "Unlock full history…" row is stranded at the bottom just above the footer (Clear/Preferences/About/Quit).
   - Required behavior while locked: the panel height fits exactly the visible content — header/search field + pinned items + free items + the unlock row + footer — the same way stock Maccy sizes its panel when history contains only a few items. The unlock row renders as an ordinary next row immediately below the last visible item, with no empty gap.
   - Required on unlock (Touch ID success inside the open popup): the panel grows to its normal height for full history (capped by the stored window size), keeping the existing animated expansion.
   - Likely origin to inspect first (hypothesis, not a mandate): round 01 modified the height computation in `Maccy/Observables/Popup.swift` with a special-cased branch for `biometricUnlockRowVisible` that reorders the min/max clamping — this likely forces the stored `Defaults[.windowSize].height` instead of content height. Also check how the unlock row participates in the content-height measurement and whether `HistoryListView` pins it after the list. Read how stock Maccy computes content height for short histories before changing anything.
   - Must preserve, from rounds 01–02: no flash of the full list on open (first painted frame is gated AND correctly sized — no visible resize on open); gating of search/⌘1-9/arrow navigation; grace-window behavior (unlocked open shows full list at normal height immediately).

2. **Bump the build stamp**: `CFBundleShortVersionString` → `2.7.1-touchid-r03`.

## Verify

- Build Release with the r01/r02 fallback signing (automatic signing fails — no "Mac Development" cert): `CODE_SIGN_IDENTITY=-`, manual style, no team, `ENABLE_HARDENED_RUNTIME=NO`. Deep/strict codesign verification must pass.
- Verify `CFBundleShortVersionString` = `2.7.1-touchid-r03`.
- Run MaccyTests. Known pre-existing flakes to report but not fix: `ClipboardTests.testIgnoreApplication`, `ClipboardTests.testIgnoreAllApplicationsExcept`. Any other failure is a defect of this round.
- No screenshot automation of the popup, no Touch ID automation — the user does the visual check.
- Quit the currently running r02 instance (executable under this repo's `build/Build/Products/Release/Maccy.app` — match by exact executable path only) and launch the fresh r03 build; verify the running PID's executable path.
- Commit the round on `master` (do not push).

## Report

≤100 lines to `logs/touchid-r03.report.txt` AND as your final message: root cause of the oversized locked panel, fix chosen, files touched with line counts, build/signing result, test results, running PID + executable path, deviations.
