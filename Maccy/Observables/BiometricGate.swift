import Defaults
import Foundation
import LocalAuthentication
import Observation

@Observable
final class BiometricGate {
  let unlockRowID = UUID()

  private(set) var authenticating = false
  private(set) var isActiveForPopup = false
  private(set) var isUnlockRowSelected = false
  var lastAuthAt: Date?

  @ObservationIgnored
  private var authenticationContext: LAContext?

  var unlocked: Bool {
    guard let lastAuthAt else { return false }
    return Date.now.timeIntervalSince(lastAuthAt) <= TimeInterval(Defaults[.biometricGraceSeconds])
  }

  private(set) var lockedForPopup = false

  var isLocked: Bool {
    Defaults[.biometricGateEnabled] && isActiveForPopup && lockedForPopup
  }

  func activateForPopup() {
    isActiveForPopup = true
    isUnlockRowSelected = false
    lockedForPopup = Defaults[.biometricGateEnabled] && !unlocked
  }

  func deactivateForPopup() {
    isActiveForPopup = false
    isUnlockRowSelected = false
    lockedForPopup = false
  }

  func selectUnlockRow() {
    isUnlockRowSelected = true
  }

  func deselectUnlockRow() {
    isUnlockRowSelected = false
  }

  func authenticate() {
    guard isLocked, !authenticating else { return }

    authenticating = true
    let context = LAContext()
    authenticationContext = context
    context.evaluatePolicy(
      .deviceOwnerAuthentication,
      localizedReason: "Unlock clipboard history"
    ) { [weak self] success, _ in
      DispatchQueue.main.async {
        guard let self else { return }
        self.authenticating = false
        self.authenticationContext = nil

        guard success else { return }
        self.lastAuthAt = Date()
        self.lockedForPopup = false
        AppState.shared.biometricGateDidUnlock()
      }
    }
  }
}
