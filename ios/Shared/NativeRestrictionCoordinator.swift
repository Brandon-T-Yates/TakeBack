import FamilyControls
import Foundation
import WidgetKit

struct NativeSetupSnapshot {
  let authorization: String
  let selection: FamilyActivitySelection?
  let restriction: RestrictionSnapshot
  var failureCode: String? = nil

  var metadata: [String: Any] {
    let usable = authorization == "authorized" && selection != nil
    var result: [String: Any] = [
      "available": true, "authorization": authorization,
      "hasSavedSelection": usable, "applicationCount": usable ? selection!.applicationTokens.count : 0,
      "selectionUsable": usable, "restrictionMode": "native", "lockdownState": restriction.state.rawValue,
    ]
    if let message = restriction.message { result["restrictionMessage"] = message }
    return result
  }
}

@MainActor
final class NativeRestrictionCoordinator: RestrictionControlling {
  private let persistence: SharedNativePersistence
  private let legacy: UserDefaults?
  private let authorizationStatus: @MainActor () -> String
  private let changed: () -> Void
  private let store: AllowedAppsStore
  private let restrictions: any RestrictionControlling

  init(persistence: SharedNativePersistence = SharedNativePersistence(), legacy: UserDefaults? = nil,
       authorization: @escaping @MainActor () -> String = NativeRestrictionCoordinator.systemAuthorization,
       changed: @escaping () -> Void = NativeWidgetChanges.post,
       makeRestrictions: @MainActor (AllowedAppsStore, NativePersistence) -> any RestrictionControlling = {
         TakeBackRestrictionStore(selectionStore: $0, persistence: $1)
       }) {
    self.persistence = persistence
    self.legacy = legacy
    self.authorizationStatus = authorization
    self.changed = changed
    self.store = AllowedAppsStore(persistence: persistence)
    self.restrictions = makeRestrictions(store, persistence)
  }

  static func systemAuthorization() -> String {
    let status = AuthorizationCenter.shared.authorizationStatus
    if status == .approved { return "authorized" }
    if status == .denied { return "denied" }
    if status == .notDetermined { return "notDetermined" }
    return "unavailable"
  }

  private func prepare() throws {
    if let legacy { try persistence.migrate(from: legacy) }
    else { try persistence.requireInitialized() }
  }

  private func readSetup(denied: Bool = false) throws -> NativeSetupSnapshot {
    try prepare()
    let authorization = denied ? "denied" : authorizationStatus()
    // Keep the Phase 2 invalidation rules identical in both processes.
    if authorization == "denied" {
      let clearedSelection = Result { try store.clearValidated() }
      let restriction = restrictions.reconcile(authorization: authorization)
      try clearedSelection.get()
      return NativeSetupSnapshot(authorization: authorization, selection: nil, restriction: restriction)
    }
    let selection = try store.loadValidated()
    return NativeSetupSnapshot(authorization: authorization, selection: selection,
      restriction: restrictions.reconcile(authorization: authorization))
  }

  func snapshot(denied: Bool = false) -> NativeSetupSnapshot {
    var notify = false
    defer { if notify { changed() } }
    do {
      return try persistence.transaction {
        let snapshot = try readSetup(denied: denied)
        let signature = "\(snapshot.authorization):\(snapshot.restriction.state.rawValue):\(snapshot.selection?.applicationTokens.count ?? -1)"
        let key = "takeback.ios.widgetSnapshot.v1"
        if try persistence.object(forKey: key) as? String != signature {
          try persistence.set(signature, forKey: key)
          notify = true
        }
        return snapshot
      }
    } catch {
      return NativeSetupSnapshot(authorization: authorizationStatus(), selection: nil,
        restriction: RestrictionSnapshot(state: .error, message: "Could not confirm Unbound’s restrictions. Tap UNLOCK to retry clearing them."),
        failureCode: (error as? RestrictionFailure)?.code ?? "shared_storage_unavailable")
    }
  }

  func reconcile(authorization: String) -> RestrictionSnapshot {
    snapshot(denied: authorization == "denied").restriction
  }

  func enable(authorization: String) throws {
    // Do not trust the caller's cached authorization or the widget's displayed state.
    let setup = try persistence.lease("setup")
    defer { withExtendedLifetime(setup) {}; changed() }
    try persistence.transaction {
      try prepare()
      let currentAuthorization = authorizationStatus()
      if currentAuthorization == "denied" { try store.clearValidated() }
      try restrictions.enable(authorization: currentAuthorization)
      guard try readSetup().restriction.state == .locked else {
        try restrictions.disable()
        throw RestrictionFailure(code: "restriction_apply_failed", message: "Unbound could not confirm the lock. Please try again.")
      }
    }
  }

  func disable() throws {
    defer { changed() }
    let lease: NativeFileLease
    do { lease = try persistence.lease("transaction") }
    catch {
      // Do not race an operation holding the transaction. Other storage failures
      // must still allow an attempt to clear the system policy.
      if (error as? RestrictionFailure)?.code == "busy" { throw error }
      try restrictions.disable()
      throw error
    }
    try withExtendedLifetime(lease) {
      // The policy reports an error if intent/recovery persistence remains unverified.
      _ = try? prepare()
      try restrictions.disable()
      guard try readSetup().restriction.state == .unlocked else {
        throw RestrictionFailure(code: "restriction_clear_failed", message: "Could not confirm clearing. Retry UNLOCK.")
      }
    }
  }

  func beginSetup(requireUnlocked: Bool) throws -> NativeFileLease {
    let lease = try persistence.lease("setup")
    try persistence.transaction {
      let snapshot = try readSetup()
      if requireUnlocked && snapshot.restriction.state != .unlocked {
        throw RestrictionFailure(code: "unlock_required", message: "Unlock Unbound before changing your allowed apps.")
      }
    }
    return lease
  }

  func loadSelection() throws -> FamilyActivitySelection? {
    try persistence.transaction { try prepare(); return try store.loadValidated() }
  }

  func saveSelection(_ selection: FamilyActivitySelection) throws {
    defer { changed() }
    try persistence.transaction {
      let snapshot = try readSetup()
      guard snapshot.authorization == "authorized", snapshot.restriction.state == .unlocked else {
        throw RestrictionFailure(code: "unlock_required", message: "Authorize and unlock Unbound before changing your allowed apps.")
      }
      try store.save(selection)
    }
  }
}

/// Token-free wake-up hints. The receiver always reads the authoritative state.
enum NativeWidgetChanges {
  static let kind = "UnboundLockWidget"
  static let notification = "com.tyleryates.takeback.native-state-changed" as CFString
  static func post() {
    WidgetCenter.shared.reloadTimelines(ofKind: kind)
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(notification), nil, nil, true)
  }
}

final class NativeChangeObserver {
  private let action: () -> Void
  init(action: @escaping () -> Void) {
    self.action = action
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(), { _, observer, _, _, _ in
        guard let observer else { return }
        let object = Unmanaged<NativeChangeObserver>.fromOpaque(observer).takeUnretainedValue()
        DispatchQueue.main.async { [weak object] in object?.action() }
      }, NativeWidgetChanges.notification, nil, .deliverImmediately)
  }
  deinit {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque())
  }
}
