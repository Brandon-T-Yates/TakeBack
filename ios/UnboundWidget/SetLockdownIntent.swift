import AppIntents
import WidgetKit

@available(iOS 17.0, *)
struct SetLockdownIntent: AppIntent {
  static var title: LocalizedStringResource = "Set Unbound Lock"
  static var isDiscoverable: Bool = false
  static var openAppWhenRun: Bool = false
  @available(iOS 26.0, *)
  static var supportedModes: IntentModes { .background }

  @Parameter(title: "Enable restrictions") var enabled: Bool
  init() {}
  init(enabled: Bool) { self.enabled = enabled }

  private static var supported: Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    return true
    #endif
  }

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    defer { WidgetCenter.shared.reloadTimelines(ofKind: NativeWidgetChanges.kind) }
    guard Self.supported else {
      throw RestrictionFailure(code: "unavailable", message: "Real restrictions require a provisioned iPhone.")
    }
    let coordinator = NativeRestrictionCoordinator()
    let result = try WidgetLockAction.perform(enabled: enabled, restrictions: coordinator,
      authorization: NativeRestrictionCoordinator.systemAuthorization)
    return .result(value: result)
  }
}
