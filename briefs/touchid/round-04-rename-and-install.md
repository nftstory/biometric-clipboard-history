# touchid round 04 — rename to Biometric Clipboard History, kill auto-update, install

Repo: /Users/nicholas/Development/maccy-touchid — branch `master` (NOT `main`).
Scope: Maccy app sources + Xcode project, plus the system install steps in deliverable 4.
Context: rounds 01–03 (`1601dcb`, `c4a3495`, `ac04489`) added the Touch ID gate, fixed the open flash, and fixed locked-panel sizing. Current build `2.7.1-touchid-r03` running from this repo's build dir. The product is being released publicly as "Biometric Clipboard History" (github.com/nftstory/biometric-clipboard-history).

On ambiguity, stop and report — never improvise.

## Deliverables

1. **Rename the app's user-facing name to "Biometric Clipboard History".**
   - Set the app's display name (CFBundleDisplayName / CFBundleName / product name as appropriate) so the Finder name, menu bar app name, and About panel show "Biometric Clipboard History".
   - KEEP the bundle identifier `org.p0deje.Maccy` exactly as is — settings and history carryover depend on it.
   - Check what the popup header label (currently renders "Maccy" next to the search field) is bound to; if it derives from the bundle name it will follow automatically — report which. Do NOT undertake a repo-wide rename of "Maccy" in localized .strings/.xcstrings files; source-code type names stay as they are.
   - The built product should be `Biometric Clipboard History.app`.

2. **Disable Sparkle auto-updates.** The fork must never self-update from upstream Maccy's appcast (that would replace the app with stock Maccy and silently remove the biometric gate). Remove/neutralize the Sparkle feed URL and disable automatic update checks (and hide/disable any "Check for updates" UI if it would now point at upstream). Report exactly what was changed.

3. **Bump the build stamp**: `CFBundleShortVersionString` → `2.7.1-touchid-r04`.

4. **Install as the only clipboard manager on this Mac** (after the build verifies):
   a. Build Release with the established fallback signing: `CODE_SIGN_IDENTITY=-`, manual style, no team, `ENABLE_HARDENED_RUNTIME=NO`; deep/strict codesign verification must pass.
   b. Quit the running r03 instance (executable under this repo's `build/Build/Products/Release/` — match by exact executable path only).
   c. Uninstall the Homebrew original: `brew uninstall --cask maccy` (removes /Applications/Maccy.app). If the cask is not installed, report and continue.
   d. Copy the built app to `/Applications/Biometric Clipboard History.app` (use `ditto`), remove any stale copy at that path first, and launch it from /Applications.
   e. Verify: running PID's executable path is under /Applications; `CFBundleShortVersionString` = `2.7.1-touchid-r04`; no other Maccy/clipboard-fork process is running; /Applications/Maccy.app no longer exists.
   f. Report (do not attempt to fix): whether Accessibility/login-item permissions likely need re-granting — the ad-hoc signature differs from the notarized brew build, so TCC may re-prompt.

## Verify

- Run MaccyTests. Known pre-existing flakes to report but not fix: `ClipboardTests.testIgnoreApplication`, `ClipboardTests.testIgnoreAllApplicationsExcept`. Any other failure is a defect of this round.
- No screenshot automation of the popup, no Touch ID automation — the user does the visual check.
- Commit the round on `master` (do not push).

## Report

≤120 lines to `logs/touchid-r04.report.txt` AND as your final message: rename mechanism (and what the popup header binds to), Sparkle changes, files touched with line counts, build/test results, install steps taken with final PID + executable path, whether /Applications/Maccy.app is gone, permission caveats, deviations.
