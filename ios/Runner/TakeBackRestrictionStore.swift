import FamilyControls
import Foundation
import ManagedSettings

enum LockdownState: String {
  case unlocked, locked, checking, error
}

struct RestrictionSnapshot {
  let state: LockdownState
  var message: String? = nil
}

struct RestrictionFailure: LocalizedError {
  let code: String
  let message: String
  var errorDescription: String? { message }
}

// The generic core can be tested with inert identifiers, never fabricated Apple tokens.
enum ShieldPolicy<Token: Hashable>: Equatable {
  case clear
  case allowlist(Set<Token>, active: Bool)
  case unexpected
}

@MainActor
protocol RestrictionBackend {
  associatedtype Token: Hashable
  func read() throws -> ShieldPolicy<Token>
  func apply(allowing tokens: Set<Token>) throws
  func clear() throws
}

@MainActor
protocol RestrictionControlling {
  func reconcile(authorization: String) -> RestrictionSnapshot
  func enable(authorization: String) throws
  func disable() throws
}

@MainActor
final class RestrictionPolicy<Backend: RestrictionBackend>: RestrictionControlling {
  static var intentKey: String { "takeback.ios.lockdownRequested.v1" }
  private let backend: Backend
  private let defaults: UserDefaults
  private let selection: () -> Set<Backend.Token>?
  private var clearingUnconfirmed = false

  init(backend: Backend, defaults: UserDefaults, selection: @escaping () -> Set<Backend.Token>?) {
    self.backend = backend
    self.defaults = defaults
    self.selection = selection
  }

  func reconcile(authorization: String) -> RestrictionSnapshot {
    do {
      if authorization == "denied" || clearingUnconfirmed {
        try disable()
        return RestrictionSnapshot(state: .unlocked)
      }
      switch try backend.read() {
      case .clear:
        defaults.removeObject(forKey: Self.intentKey)
        return RestrictionSnapshot(state: .unlocked)
      case let .allowlist(tokens, active):
        guard active, defaults.bool(forKey: Self.intentKey),
              let saved = selection(), (1...50).contains(saved.count), saved == tokens else {
          try disable()
          return RestrictionSnapshot(state: .unlocked)
        }
        return RestrictionSnapshot(
          state: authorization == "authorized" ? .locked : .checking,
          message: authorization == "authorized" ? nil : "Checking Screen Time authorization. You can still unlock."
        )
      case .unexpected:
        try disable()
        return RestrictionSnapshot(state: .unlocked)
      }
    } catch {
      return RestrictionSnapshot(state: .error, message: "Could not confirm TakeBack’s restrictions. Tap UNLOCK to retry clearing them.")
    }
  }

  func enable(authorization: String) throws {
    let current = reconcile(authorization: authorization)
    guard current.state != .error else {
      throw RestrictionFailure(code: "restriction_state_unknown", message: current.message!)
    }
    guard authorization == "authorized" else {
      throw RestrictionFailure(code: "authorization_required", message: "Authorize Screen Time before locking in.")
    }
    guard let tokens = selection() else {
      throw RestrictionFailure(code: "selection_required", message: "Choose and save your allowed apps before locking in.")
    }
    guard !tokens.isEmpty else {
      throw RestrictionFailure(code: "empty_selection", message: "Choose at least one allowed app before locking in.")
    }
    guard tokens.count <= 50 else {
      throw RestrictionFailure(code: "selection_limit", message: "Choose no more than 50 allowed apps before locking in.")
    }
    if current.state == .locked { return }
    do {
      try backend.apply(allowing: tokens)
      guard try backend.read() == .allowlist(tokens, active: true) else {
        throw RestrictionFailure(code: "restriction_apply_failed", message: "TakeBack could not confirm that app restrictions were applied. Please try again.")
      }
      defaults.set(true, forKey: Self.intentKey)
    } catch {
      // A partial write must never be reported as a successful lock.
      try disable()
      throw RestrictionFailure(code: "restriction_apply_failed", message: "TakeBack could not confirm that app restrictions were applied. Please try again.")
    }
  }

  func disable() throws {
    clearingUnconfirmed = true
    do {
      try backend.clear()
      guard try backend.read() == .clear else {
        throw RestrictionFailure(code: "restriction_clear_failed", message: "Restrictions are still present.")
      }
      defaults.removeObject(forKey: Self.intentKey)
      clearingUnconfirmed = false
    } catch {
      // Keep intent until clearing is verified, so relaunch also offers recovery.
      throw RestrictionFailure(code: "restriction_clear_failed", message: "Could not confirm that TakeBack’s restrictions were cleared. Tap UNLOCK to retry.")
    }
  }
}

@MainActor
private final class ManagedSettingsBackend: RestrictionBackend {
  typealias Token = ApplicationToken
  private let store = ManagedSettingsStore(named: .init("takeback.lockdown"))

  func read() throws -> ShieldPolicy<ApplicationToken> {
    guard store.shield.applications == nil, store.shield.webDomains == nil,
          store.shield.webDomainCategories == nil else { return .unexpected }
    guard let policy = store.shield.applicationCategories else { return .clear }
    guard case let .all(except: tokens) = policy else { return .unexpected }
    // Availability is declared by the installed ManagedSettings SDK.
    if #available(iOS 26.5, *) {
      return .allowlist(tokens, active: store.isActive)
    }
    return .allowlist(tokens, active: true)
  }

  func apply(allowing tokens: Set<ApplicationToken>) throws {
    store.shield.applicationCategories = .all(except: tokens)
    if #available(iOS 26.5, *) { store.isActive = true }
  }

  func clear() throws { store.clearAllSettings() }
}

@MainActor
final class TakeBackRestrictionStore: RestrictionControlling {
  private let policy: RestrictionPolicy<ManagedSettingsBackend>

  init(selectionStore: AllowedAppsStore, defaults: UserDefaults = .standard) {
    policy = RestrictionPolicy(backend: ManagedSettingsBackend(), defaults: defaults) {
      selectionStore.load()?.applicationTokens
    }
  }

  func reconcile(authorization: String) -> RestrictionSnapshot { policy.reconcile(authorization: authorization) }
  func enable(authorization: String) throws { try policy.enable(authorization: authorization) }
  func disable() throws { try policy.disable() }
}
