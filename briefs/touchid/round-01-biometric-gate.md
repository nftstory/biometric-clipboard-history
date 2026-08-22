# Round 01 — touchid: biometric gate on clipboard history

Repo: `~/Development/maccy-touchid` (fork of p0deje/Maccy at v2.7.1, Swift/SwiftUI, Xcode 26.5).
Scope: the Maccy app target only. **On ambiguity, stop and report — never improvise.**

Goal: the popup shows only the most recent few clipboard items freely; seeing
anything older requires Touch ID (with password fallback). Exact behavior below —
zero taste decisions left open.

## Deliverables

1. **Locked/unlocked state.** Add a biometric gate object (e.g. `BiometricGate`
   observable) holding `lastAuthAt: Date?`. `unlocked` == `lastAuthAt` within the
   grace window. Auth via `LocalAuthentication` `LAContext.evaluatePolicy(.deviceOwnerAuthentication,
   localizedReason: "Unlock clipboard history")` — `.deviceOwnerAuthentication`
   exactly (biometrics first, password fallback). On success set `lastAuthAt = Date()`.

2. **Settings (UserDefaults only, no preferences UI this round).** Using the same
   Defaults mechanism the app already uses for its settings, add:
   - `biometricGateEnabled` Bool, default `true`
   - `biometricFreeItems` Int, default `3`
   - `biometricGraceSeconds` Int, default `300`
   When `biometricGateEnabled` is false, app behaves exactly like stock Maccy.

3. **List gating.** Locate where the popup's visible history items are computed
   (inspect the code and report the file/type in your report). When gated+locked:
   - All PINNED items remain visible.
   - Of the unpinned items, only the `biometricFreeItems` most recent are visible.
   - If any items are hidden, append one extra row at the end of the visible
     history styled like a normal history row, title: `Unlock full history…` with
     a lock symbol (SF Symbol `lock.fill`) as its leading image. Selecting it
     (click or Enter) triggers the auth of deliverable 1 and NEVER pastes anything.
     On success the list immediately refreshes to full history; on failure/cancel
     nothing changes.
   - Grace expiry: next time the popup opens after `biometricGraceSeconds` have
     elapsed since `lastAuthAt`, it is locked again (no need for a live timer that
     relocks an open popup).

4. **Search gating.** While locked, search must match ONLY the visible items
   (pins + free recents). The `Unlock full history…` row stays visible in search
   results whenever the gate is locked. After unlock, search covers everything.

5. **Keyboard navigation** must treat the unlock row like a selectable row
   (arrow keys reach it, Enter activates it) and must not break existing
   navigation when the gate is disabled or unlocked.

6. **Build stamp.** Append `-touchid-r01` to the app's marketing version
   (CFBundleShortVersionString or the xcconfig/project setting that feeds it) so
   About/Finder Get Info shows `2.7.1-touchid-r01`. Bump the suffix every round.

7. **Build.** `xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration
   Release -derivedDataPath build build` with automatic/ad-hoc signing (report
   which signing actually applied). Report the built `.app` path. Do NOT install
   to /Applications and do NOT touch the brew cask.

8. **Runtime proof (locked state only — do NOT attempt to automate Touch ID).**
   - Seed history: `pbcopy` 6 distinct strings `touchid-test-1`…`-6`, 1s apart,
     while the built app is running.
   - Quit any running Maccy instance first (`pkill -x Maccy`), launch the built
     app, wait 2s.
   - Open the popup via AppleScript System Events: key code 8 with
     {control down, command down} (the user's popup hotkey is ⌃⌘C; it is stored
     in defaults and will apply to your build since bundle id is unchanged).
   - `screencapture -x` the screen to `proofs/touchid-r01/popup-locked.png`
     (≤1600px wide — downscale with sips if needed). The proof must show: the 3
     newest test strings (6,5,4), NO older test strings, and the
     `Unlock full history…` row.
   - Second proof `proofs/touchid-r01/popup-search-locked.png`: with popup open,
     type `touchid-test` into search — must show only items 6,5,4 + unlock row.
   - If keystroke automation is blocked by TCC/permissions, capture what you can,
     stop, and report the exact error as a deviation — never fake a proof.
   - Leave the BUILT app running when done (not the brew one).

9. **Tests.** If the existing test suite has unit tests that still pass headlessly,
   run them and report pass/fail counts. Do not write new UI tests this round.

10. **Commit** all source changes on current branch (main) with a clear message.
    Do NOT push (Claude handles push after judging).

## Report
Write `logs/touchid-r01.report.txt`, ≤100 lines: files touched with line counts,
where the list gating landed (file/type names), signing result, proof paths,
test results, deviations. No source dumps.
