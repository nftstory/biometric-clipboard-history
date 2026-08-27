import Defaults
import KeyboardShortcuts
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  static let isTesting = CommandLine.arguments.contains("enable-testing")
  private static let bundleIdentifier = "life.nftstory.biometric-clipboard-history"
  private static let legacyBundleIdentifier = "org.p0deje.Maccy"
  private static let legacyMigrationDoneKey = "nftstoryLegacyBundleMigrationDone"

  var panel: FloatingPanel<ContentView>!
  private var legacyMigrationFailed = false

  @objc
  private lazy var statusItem: NSStatusItem = {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.behavior = .removalAllowed
    statusItem.button?.action = #selector(performStatusItemClick)
    statusItem.button?.image = Defaults[.menuIcon].image
    statusItem.button?.imagePosition = .imageLeft
    statusItem.button?.target = self
    return statusItem
  }()

  // Base accessibility label for the status item; kept separate from the optional
  // dynamic `title` (recent copy text) so VoiceOver always announces something
  // meaningful even when that preference is off or the app is disabled.
  private func updateStatusItemAccessibilityLabel() {
    let base = NSLocalizedString("status_item_accessibility_label", comment: "")
    statusItem.button?.setAccessibilityLabel(
      isStatusItemDisabled ? "\(base) — \(NSLocalizedString("status_item_disabled_accessibility_suffix", comment: ""))" : base
    )
  }

  private var isStatusItemDisabled: Bool {
    Defaults[.ignoreEvents] || Defaults[.enabledPasteboardTypes].isEmpty
  }

  private var statusItemVisibilityObserver: NSKeyValueObservation?

  func applicationWillFinishLaunching(_ notification: Notification) { // swiftlint:disable:this function_body_length
    #if DEBUG
    if Self.isTesting {
      // Start from a clean slate for the isolated testing preferences.
      UserDefaults.standard.removePersistentDomain(forName: Defaults.Keys.testingSuiteName)
    }
    #endif

    do {
      try migrateLegacyBundleIfNeeded()
    } catch {
      legacyMigrationFailed = true
      let message = "Legacy bundle migration failed: \(String(reflecting: error))"
      NSLog("%@", message)
      if let data = "\(message)\n".data(using: .utf8) {
        FileHandle.standardError.write(data)
      }
      NSApp.terminate(nil)
      return
    }

    // Bridge FloatingPanel via AppDelegate.
    AppState.shared.appDelegate = self

    Clipboard.shared.onNewCopy { History.shared.add($0) }
    Clipboard.shared.start()

    Task {
      for await _ in Defaults.updates(.clipboardCheckInterval, initial: false) {
        Clipboard.shared.restart()
      }
    }

    statusItemVisibilityObserver = observe(\.statusItem.isVisible, options: .new) { _, change in
      if let newValue = change.newValue, Defaults[.showInStatusBar] != newValue {
        Defaults[.showInStatusBar] = newValue
      }
    }

    Task {
      for await value in Defaults.updates(.showInStatusBar) {
        statusItem.isVisible = value
      }
    }

    Task {
      for await value in Defaults.updates(.menuIcon, initial: false) {
        statusItem.button?.image = value.image
      }
    }

    synchronizeMenuIconText()
    Task {
      for await value in Defaults.updates(.showRecentCopyInMenuBar) {
        if value {
          statusItem.button?.title = AppState.shared.menuIconText
        } else {
          statusItem.button?.title = ""
        }
      }
    }

    updateStatusItemAccessibilityLabel()

    Task {
      for await _ in Defaults.updates(.ignoreEvents) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
        updateStatusItemAccessibilityLabel()
      }
    }

    Task {
      for await _ in Defaults.updates(.enabledPasteboardTypes) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
        updateStatusItemAccessibilityLabel()
      }
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    guard !legacyMigrationFailed else { return }

    migrateUserDefaults()
    disableUnusedGlobalHotkeys()

    panel = FloatingPanel(
      contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
      identifier: Bundle.main.bundleIdentifier ?? Self.bundleIdentifier,
      statusBarButton: statusItem.button,
      onClose: { AppState.shared.popup.reset() }
    ) {
      ContentView()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    panel.toggle(height: AppState.shared.popup.height)
    return true
  }

  func applicationWillTerminate(_ notification: Notification) {
    if Defaults[.clearOnQuit] {
      AppState.shared.history.clear()
    }
  }

  private func migrateLegacyBundleIfNeeded() throws {
    guard !Self.isTesting else { return }

    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: Self.legacyMigrationDoneKey) else { return }

    let legacyContainer = legacyContainerURL()
    let legacyPreferencesURL = legacyContainer
      .appending(path: "Data/Library/Preferences/\(Self.legacyBundleIdentifier).plist")
    let legacyStoreURL = legacyContainer
      .appending(path: "Data/Library/Application Support/Maccy/Storage.sqlite")
    let destinationStoreURL = URL.applicationSupportDirectory
      .appending(path: "Maccy/Storage.sqlite")

    var legacyDefaults = try readLegacyDefaults(at: legacyPreferencesURL) ?? [:]
    let hasLegacyStore = try readableFileExists(at: legacyStoreURL)
    if hasLegacyStore && !FileManager.default.fileExists(atPath: destinationStoreURL.path) {
      try copyLegacyStore(from: legacyStoreURL, to: destinationStoreURL)
    }

    // The fork's biometric defaults may never have been materialized in the old
    // preferences domain. Persist their effective values in the new domain.
    if legacyDefaults["biometricGateEnabled"] == nil {
      legacyDefaults["biometricGateEnabled"] = true
    }
    if legacyDefaults["biometricFreeItems"] == nil {
      legacyDefaults["biometricFreeItems"] = 3
    }
    if legacyDefaults["biometricGraceSeconds"] == nil {
      legacyDefaults["biometricGraceSeconds"] = 300
    }

    for (key, value) in legacyDefaults {
      defaults.set(value, forKey: key)
    }
    defaults.set(true, forKey: Self.legacyMigrationDoneKey)
    defaults.synchronize()

    NSLog(
      "Legacy bundle migration completed: copied %ld defaults; history store present=%@",
      legacyDefaults.count,
      hasLegacyStore ? "yes" : "no"
    )
  }

  private func legacyContainerURL() -> URL {
    let appSupportURL = URL.applicationSupportDirectory.standardizedFileURL
    let containerSuffix = "/Library/Containers/\(Self.bundleIdentifier)/Data/Library/Application Support"

    if appSupportURL.path.hasSuffix(containerSuffix) {
      let homePath = String(appSupportURL.path.dropLast(containerSuffix.count))
      return URL(fileURLWithPath: homePath)
        .appending(path: "Library/Containers/\(Self.legacyBundleIdentifier)")
    }

    return FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "Library/Containers/\(Self.legacyBundleIdentifier)")
  }

  private func readLegacyDefaults(at url: URL) throws -> [String: Any]? {
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch where isNoSuchFileError(error) {
      return nil
    }

    let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
    guard let dictionary = propertyList as? [String: Any] else {
      throw migrationError("Legacy defaults are not a dictionary at \(url.path)")
    }
    return dictionary
  }

  private func readableFileExists(at url: URL) throws -> Bool {
    do {
      let handle = try FileHandle(forReadingFrom: url)
      try handle.close()
      return true
    } catch where isNoSuchFileError(error) {
      return false
    }
  }

  private func copyLegacyStore(from sourceStore: URL, to destinationStore: URL) throws {
    let fileManager = FileManager.default
    let destinationDirectory = destinationStore.deletingLastPathComponent()
    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

    let stagingDirectory = destinationDirectory
      .appending(path: ".legacy-bundle-migration-\(UUID().uuidString)")
    try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: false)
    defer { try? fileManager.removeItem(at: stagingDirectory) }

    var stagedFiles: [(source: URL, destination: URL)] = []
    for suffix in ["", "-wal", "-shm"] {
      let source = URL(fileURLWithPath: sourceStore.path + suffix)
      let staged = stagingDirectory.appending(path: "Storage.sqlite\(suffix)")
      let destination = URL(fileURLWithPath: destinationStore.path + suffix)

      do {
        try fileManager.copyItem(at: source, to: staged)
        stagedFiles.append((staged, destination))
      } catch where !suffix.isEmpty && isNoSuchFileError(error) {
        continue
      }
    }

    for stagedFile in stagedFiles {
      guard !fileManager.fileExists(atPath: stagedFile.destination.path) else {
        throw migrationError("Migration destination already exists at \(stagedFile.destination.path)")
      }
      try fileManager.moveItem(at: stagedFile.source, to: stagedFile.destination)
    }
  }

  private func isNoSuchFileError(_ error: Error) -> Bool {
    let error = error as NSError
    return error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError
  }

  private func migrationError(_ message: String) -> NSError {
    NSError(
      domain: "life.nftstory.biometric-clipboard-history.migration",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }

  private func ensureMigration(key: String, _ action: () -> Void) {
    if Defaults[.migrations][key] != true {
      action()
      Defaults[.migrations][key] = true
    }
  }

  @MainActor
  private func migrateUserDefaults() {
    ensureMigration(key: "2024-07-01-version-2") {
      // Start 2.x from scratch.
      Defaults.reset(.migrations)

      // Inverse hide* configuration keys.
      Defaults[.showFooter] = !UserDefaults.standard.bool(forKey: "hideFooter")
      Defaults[.showSearch] = !UserDefaults.standard.bool(forKey: "hideSearch")
      Defaults[.showTitle] = !UserDefaults.standard.bool(forKey: "hideTitle")
      UserDefaults.standard.removeObject(forKey: "hideFooter")
      UserDefaults.standard.removeObject(forKey: "hideSearch")
      UserDefaults.standard.removeObject(forKey: "hideTitle")
    }

    ensureMigration(key: "2025-07-04-add-jpeg-heic") {
      var types = Defaults[.enabledPasteboardTypes]
      if !types.isDisjoint(with: StorageType.images.types) {
        types.formUnion(StorageType.images.types)
      }
      Defaults[.enabledPasteboardTypes] = types
    }

    ensureMigration(key: "2026-08-12-cleanup-orphaned-history-item-contents") {
      _ = try? Storage.shared.cleanupOrphanedContents()
    }

    // The following defaults are not used in Maccy 2.x
    // and should be removed in 3.x.
    // - LaunchAtLogin__hasMigrated
    // - avoidTakingFocus
    // - saratovSeparator
    // - maxMenuItemLength
    // - maxMenuItems
  }

  @objc
  private func performStatusItemClick() {
    if let event = NSApp.currentEvent {
      let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

      if modifierFlags.contains(.option) {
        Defaults[.ignoreEvents].toggle()

        if modifierFlags.contains(.shift) {
          Defaults[.ignoreOnlyNextEvent] = Defaults[.ignoreEvents]
        }

        return
      }
    }

    panel.toggle(height: AppState.shared.popup.height, at: .statusItem)
  }

  private func synchronizeMenuIconText() {
    _ = withObservationTracking {
      AppState.shared.menuIconText
    } onChange: {
      DispatchQueue.main.async {
        if Defaults[.showRecentCopyInMenuBar] {
          self.statusItem.button?.title = AppState.shared.menuIconText
        }
        self.synchronizeMenuIconText()
      }
    }
  }

  private func disableUnusedGlobalHotkeys() {
    let names: [KeyboardShortcuts.Name] = [.delete, .pin, .togglePreview]
    KeyboardShortcuts.disable(names)

    NotificationCenter.default.addObserver(
      forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
      object: nil,
      queue: nil
    ) { notification in
      if let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name, names.contains(name) {
        KeyboardShortcuts.disable(name)
      }
    }
  }
}
