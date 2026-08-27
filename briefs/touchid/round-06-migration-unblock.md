# touchid round 06 — unblock bundle-id migration, install r06

Repo: /Users/nicholas/Development/maccy-touchid — branch `master` (NOT `main`).
Scope: Maccy app sources + README migration note + the external migration/install steps below.
Context: round 05 work is sitting UNCOMMITTED in the working tree (dedupe vacuous-match fix + regression test, bundle id → `life.nftstory.biometric-clipboard-history`, default hotkey → ⌃⌘C, stamp r05 — see `logs/touchid-r05.report.txt`). It stopped, as instructed, when the first launch of the sandboxed new-bundle-id app failed reading the OLD container: NSCocoaErrorDomain 257 on `~/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/org.p0deje.Maccy.plist` — the new app's sandbox cannot read the old container. The installed app is r04 (`org.p0deje.Maccy` id), RUNNING again, with 196 history items in the old container store.

On ambiguity, stop and report — never improvise.

## Deliverables

1. **Commit the round 05 work first**, as its own commit on `master` (message: the r05 content — dedupe fix, bundle id, default hotkey). Do not mix it with this round's changes.
2. **Make the in-app migration non-fatal.** Keep the first-launch migration (it will work for non-sandboxed reads or future entitlement setups), but when reading the legacy container fails with a permissions error, log and SKIP gracefully — the app must start fresh instead of failing to launch. Do NOT add sandbox exception entitlements and do NOT disable the App Sandbox. Set the migration-done flag on graceful skip too (don't retry forever); cite the lines.
3. **README**: add a short "Migrating from Maccy" subsection under our fork intro: existing Maccy/old-container data isn't readable from inside the new app's sandbox; give the 3-4 shell commands a user runs (app quit) to copy their old defaults + `Storage.sqlite` into the new container (same mechanics as deliverable 5). Keep it tight.
4. **Bump the build stamp**: `CFBundleShortVersionString` → `2.7.1-touchid-r06`. Commit this round's changes.
5. **Build, install, and migrate THIS machine externally** (shell has user-level access; the sandbox restriction only binds the app):
   a. Release build with the established signing fallback (`CODE_SIGN_IDENTITY=-`, manual, no team, `ENABLE_HARDENED_RUNTIME=NO`); deep/strict codesign must pass; verify version r06 + bundle id `life.nftstory.biometric-clipboard-history`.
   b. Quit the running r04 instance (exact executable path `/Applications/Biometric Clipboard History.app/Contents/MacOS/Biometric Clipboard History` only). Replace the app in /Applications via `ditto`.
   c. Launch once so macOS creates the new container, wait a beat, then quit it (exact path match only). It will have started fresh via the graceful skip.
   d. With the app NOT running, migrate: copy the old container's defaults into the new container's Preferences plist (all keys from `org.p0deje.Maccy.plist`, preserving `KeyboardShortcuts_popup` = the user's ⌃⌘C binding and any biometric knobs), and copy `Storage.sqlite` (+ -wal/-shm) from the old container's App Support into the new container's matching location, replacing the fresh empty store. Beware cfprefsd caching — make sure the written defaults actually take (e.g. write via `defaults` against the container plist path and/or restart cfprefsd for that domain as needed; verify by reading back). NEVER modify or delete the old container.
   e. Relaunch from /Applications. Verify: PID executable path; bundle id + version r06; new container store item count equals the old count (~196 — report both numbers, no contents); popup hotkey defaults key present with the ⌃⌘C value; biometric knobs present.
   f. Run the transient-only pasteboard probe from round 05 against the running fixed app: first item's numberOfCopies must NOT bump. Report before/after.
6. **Tests**: run MaccyTests (with the r05 regression test). Known pre-existing flakes to report but not fix: `ClipboardTests.testIgnoreApplication`, `ClipboardTests.testIgnoreAllApplicationsExcept`. Any other failure is a defect of this round.

## Verify / report

No popup screenshot automation, no Touch ID automation — user does visual checks (expect Accessibility + login-item re-grant prompts; report, don't fix). Do not push.
≤120 lines to `logs/touchid-r06.report.txt` AND as your final message: both commits' hashes, graceful-skip lines cited, README section added, migration verification numbers (old vs new item count, hotkey/knob keys), post-fix probe result, install PID/path, deviations.
