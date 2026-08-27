# touchid round 05 — fix vacuous dedupe match; migrate bundle id to nftstory

Repo: /Users/nicholas/Development/maccy-touchid — branch `master` (NOT `main`).
Scope: Maccy app sources + Xcode project + the migration/install steps below.
Context: probe 01 (`logs/touchid-probe01.report.txt`) investigated a user-reported bug: one item ("You really should have us…", 9 copies) permanently at position 1, count climbing though the user never re-copied it. Plain-text repro failed, but the audit found a residual stock-Maccy edge: an incoming item whose fields are all transient/ignored leaves the content comparison `allSatisfy` vacuously true (`Maccy/Models/HistoryItem.swift:85` area), so `findSimilarItem` (`Maccy/Observables/History.swift:156`, `:481`) can match the FIRST item and merge into it — bumping its count and lastCopiedAt. Current installed build `2.7.1-touchid-r04` at `/Applications/Biometric Clipboard History.app`, bundle id `org.p0deje.Maccy`, history DB `~/Library/Containers/org.p0deje.Maccy/Data/Library/Application Support/Maccy/Storage.sqlite`.

On ambiguity, stop and report — never improvise.

## Deliverables

1. **Reproduce the vacuous-match bug pre-fix (best effort).** Write a transient-only pasteboard event the way the edge predicts (e.g. an NSPasteboard write declaring only types in Maccy's ignored/transient set, such as `org.nspasteboard.TransientType`, with no surviving content fields — derive the exact shape from `Clipboard.swift:27-31,233-238` and `HistoryItem.swift`). Then check the store: did the CURRENT first item's numberOfCopies/lastCopiedAt bump? Report the result either way. If it does not reproduce, continue — the fix below is correct regardless — but flag root cause as unconfirmed.
2. **Fix the dedupe.** An item with no comparable (non-transient) contents must never match an existing item: guard the similar-item/supersedes check so empty contents → no match (and such an event should not create an empty history item either — check what stock code does with it downstream and keep that behavior sane). Cite the exact lines changed.
3. **Unit test** in MaccyTests covering the bug: a transient-only incoming item must not merge into an unrelated existing item and must not bump its numberOfCopies.
4. **Migrate the bundle identifier** to `life.nftstory.biometric-clipboard-history`:
   - Change the bundle id in the project (all targets/configs that reference `org.p0deje.Maccy`).
   - Sandbox container note: the app is sandboxed (container path above). With a new bundle id it gets a NEW container. Add a one-time migration ON FIRST LAUNCH (guarded by a "migrationDone" flag in the new defaults domain) that: (a) copies all `org.p0deje.Maccy` defaults into the new domain — including `KeyboardShortcuts_popup` (the ⌃⌘C hotkey) and the biometric knobs; (b) copies the old history store (`Storage.sqlite` + any -wal/-shm siblings) from the old container/App Support location into the new one if no store exists there yet. Read the old data read-only; never delete or modify the old container.
   - If the old container is unreadable from the new sandbox (sandbox denies cross-container reads), STOP and report the exact error — do not improvise entitlement changes.
5. **Make ⌃⌘C (control+command+C) the fork's DEFAULT popup hotkey** for fresh installs (upstream defaults to ⇧⌘C, which fights browser DevTools; the public announcement states ⌃⌘C as the product behavior). Change the code-level default for the popup KeyboardShortcut; an existing user-set value in defaults must still win (the migrating user already has ⌃⌘C stored).

6. **Bump the build stamp**: `CFBundleShortVersionString` → `2.7.1-touchid-r05`.
6. **Build + install swap** (after tests pass): Release build with the established fallback signing (`CODE_SIGN_IDENTITY=-`, manual, no team, `ENABLE_HARDENED_RUNTIME=NO`, `PRODUCT_MODULE_NAME=Maccy` where needed); deep/strict codesign must pass. Quit the running r04 instance (match by exact executable path `/Applications/Biometric Clipboard History.app/Contents/MacOS/Biometric Clipboard History` only), replace the app in /Applications with `ditto`, launch it, verify: PID path, version r05, new bundle id, AND that the migration ran — new defaults domain contains the hotkey + knobs, and the new container has the history store with the user's items (report item count old vs new; do not print item contents).

## Verify

- Run MaccyTests including the new test. Known pre-existing flakes to report but not fix: `ClipboardTests.testIgnoreApplication`, `ClipboardTests.testIgnoreAllApplicationsExcept`. Any other failure is a defect of this round.
- Repeat the deliverable-1 transient-only pasteboard event against the RUNNING fixed app: the first item's count must NOT bump. Report before/after numbers.
- No popup screenshot automation, no Touch ID automation — user does visual checks. Expect Accessibility/login-item to need re-granting after the bundle-id change; report, don't attempt to fix.
- Commit the round on `master` (do not push).

## Report

≤120 lines to `logs/touchid-r05.report.txt` AND as your final message: pre-fix repro result, fix lines cited, test result, migration mechanics + old/new item counts, install verification, deviations.
