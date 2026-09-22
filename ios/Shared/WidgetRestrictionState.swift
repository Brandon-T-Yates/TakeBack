import Foundation

enum WidgetRestrictionState: String {
  case unlocked, locked, setup, recovery

  init(state: LockdownState, authorization: String, applicationCount: Int?, failureCode: String? = nil) {
    if failureCode == "setup_required" { self = .setup }
    else if state == .checking || state == .error { self = .recovery }
    else if state == .locked {
      self = authorization == "authorized" && applicationCount.map { (1...50).contains($0) } == true ? .locked : .recovery
    }
    else if authorization == "authorized", let count = applicationCount, (1...50).contains(count) { self = .unlocked }
    else { self = .setup }
  }

  init(_ snapshot: NativeSetupSnapshot) {
    self.init(state: snapshot.restriction.state, authorization: snapshot.authorization,
      applicationCount: snapshot.selection?.applicationTokens.count, failureCode: snapshot.failureCode)
  }

  var title: String {
    switch self {
    case .unlocked: return "LOCK IN"
    case .locked, .recovery: return "UNLOCK"
    case .setup: return "Open Unbound"
    }
  }
  var symbol: String { self == .unlocked ? "lock.open.fill" : "lock.fill" }
  var uncertain: Bool { self == .setup || self == .recovery }
  var requestedEnabled: Bool? { self == .setup ? nil : self == .unlocked }
  var accessibilityState: String {
    switch self {
    case .unlocked: return "Unlocked"
    case .locked: return "Locked"
    case .setup: return "Setup required"
    case .recovery: return "Restriction state unconfirmed"
    }
  }
}

/// Shared/testable intent boundary: explicit requests, never blind toggles.
@MainActor
enum WidgetLockAction {
  static func perform(enabled: Bool, restrictions: any RestrictionControlling,
                      authorization: @MainActor () -> String) throws -> String {
    if enabled { try restrictions.enable(authorization: authorization()) }
    else { try restrictions.disable() }
    let state = restrictions.reconcile(authorization: authorization()).state
    guard state == (enabled ? .locked : .unlocked) else {
      throw RestrictionFailure(code: "restriction_state_unknown", message: "Could not verify the resulting restriction state. Retry UNLOCK if needed.")
    }
    return state.rawValue
  }
}
