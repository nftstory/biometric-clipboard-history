# touchid round 02 — fix locked-list flash on popup open

Repo: /Users/nicholas/Development/maccy-touchid — branch `master` (NOT `main`).
Scope: Maccy app sources only (`Maccy/`), plus the version stamp in the Xcode project. Work only in this repo.
Context: round 01 (commit 1601dcb) added the biometric gate — while locked, the popup shows pinned items + the 3 newest unpinned items + an "Unlock full history…" row; `BiometricGate` in `Maccy/Observables/BiometricGate.swift`, gating in `Maccy/Observables/History.swift` (`refreshVisibleItems()` / `biometricSearchSource()`), popup lifecycle hooks in `Maccy/Observables/AppState.swift` (`prepareForPopupOpen()` / `popupDidClose()`).

On ambiguity, stop and report — never improvise.

## Deliverables

1. **Eliminate the locked-list flash on popup open.**
   - Observed defect (reported by the user on the r01 build): pressing the popup hotkey while the gate is locked briefly shows the FULL history list for a moment, then animates/collapses down to the gated set (pins + 3 newest + unlock row).
   - Required behavior: the first visible frame of the popup already shows only the gated set. Full history must never be painted while locked — not for a single frame — and there must be no shrink animation on open.
   - Likely mechanism to inspect first (hypothesis, not a mandate): `popupDidClose()` calls `refreshVisibleItems()` after `deactivateForPopup()`, so while the popup is closed `items` holds the full list; `prepareForPopupOpen()` then re-filters at (or after) the moment the panel becomes visible, and SwiftUI animates the difference. Confirm the actual mechanism by reading the open path (`FloatingPanel.swift`, `Popup.swift`, `AppState.prepareForPopupOpen()`) before changing anything.
   - Acceptable fixes (choose whichever the confirmed mechanism supports; report which you used): keep `items` gated while the popup is closed so the closed-state list is already the locked set, and/or apply the gate synchronously before the panel orders front, with the initial population wrapped in a transaction that disables animation.
   - Must preserve:
     - Within the grace window (gate unlocked, `biometricGraceSeconds`), the popup opens directly with the full list — no flash of the gated set in that direction either.
     - The post-Touch-ID unlock expansion inside an open popup keeps its current behavior (animation there is fine).
     - Search, ⌘1–9 shortcuts, and arrow navigation continue to operate only on the gated set while locked (round 01 behavior — do not regress).

2. **Bump the build stamp**: `CFBundleShortVersionString` → `2.7.1-touchid-r02`.

## Verify

- Build Release with the same fallback signing that worked in r01: automatic signing will fail (no "Mac Development" cert); use `CODE_SIGN_IDENTITY=-`, no team, `ENABLE_HARDENED_RUNTIME=NO`. Verify codesign (ad-hoc) passes deep/strict verification.
- Verify `CFBundleShortVersionString` of the built app is `2.7.1-touchid-r02`.
- Run MaccyTests (`xcodebuild -only-testing:MaccyTests test`). Known pre-existing flakes: `ClipboardTests.testIgnoreApplication` and `ClipboardTests.testIgnoreAllApplicationsExcept` — report their status but do not attempt to fix them. Any OTHER failure is a defect of this round.
- Do NOT attempt screenshot automation of the popup — last round the System Events hotkey scripting was unreliable and once typed into another app. No Touch ID automation. The user performs the visual flash check.
- Quit the currently running r01 instance (`build/Build/Products/Release/Maccy.app`, launched from this repo's build dir — kill by exact executable path match only; do not touch any other app) and launch the freshly built r02 app; verify the running PID's executable path is the new build.
- Commit the round on `master` (do not push).

## Report

≤100 lines to `logs/touchid-r02.report.txt` AND as your final message: root cause found for the flash, fix chosen, files touched with line counts, build/signing result, test results, running PID + executable path, deviations.
