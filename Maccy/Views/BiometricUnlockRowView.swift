import SwiftUI

struct BiometricUnlockRowView: View {
  @Environment(AppState.self) private var appState

  private func unlock() {
    appState.navigator.selectBiometricUnlockRow()
    appState.biometricGate.authenticate()
  }

  var body: some View {
    ListItemView(
      id: appState.biometricGate.unlockRowID,
      selectionId: appState.biometricGate.unlockRowID,
      appIcon: nil,
      image: nil,
      accessoryImage: nil,
      leadingSystemImageName: "lock.fill",
      attributedTitle: nil,
      shortcuts: [],
      isSelected: appState.biometricGate.isUnlockRowSelected,
      selectionIndex: nil,
      accessibilityLabel: "Unlock full history"
    ) {
      Text("Unlock full history…")
    }
    .accessibilityIdentifier("unlock-full-history-item")
    .buttonAction(unlock)
  }
}
