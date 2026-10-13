import FamilyControls
import Foundation

/// Stores opaque app tokens only. This never reads the Flutter prototype key.
final class AllowedAppsStore {
  static let selectionKey = "takeback.ios.allowedApplications.v1"
  private let persistence: NativePersistence

  enum SelectionError: LocalizedError, Equatable {
    case emptySelection
    case selectionLimit

    var errorDescription: String? {
      switch self {
      case .emptySelection:
        return "This selection can't be saved. Your previous allowed apps are unchanged. "
          + "Choose individual apps only."
      case .selectionLimit:
        return "Unbound supports up to 50 allowed apps."
      }
    }

    var flutterErrorCode: String {
      switch self {
      case .emptySelection: return "unsupported_selection"
      case .selectionLimit: return "selection_limit"
      }
    }
  }

  init(defaults: UserDefaults = .standard) {
    self.persistence = DefaultsNativePersistence(defaults)
  }

  init(persistence: NativePersistence) { self.persistence = persistence }

  static func decode(_ data: Data) throws -> FamilyActivitySelection {
    try normalizedStoredSelection(JSONDecoder().decode(FamilyActivitySelection.self, from: data))
  }

  /// Picker binding: keep saved app tokens selected and prefer category expansion UX.
  static func pickerInitialSelection(from saved: FamilyActivitySelection?) -> FamilyActivitySelection {
    var selection = FamilyActivitySelection(includeEntireCategory: true)
    selection.applicationTokens = saved?.applicationTokens ?? []
    return selection
  }

  static func validateSaveApplicationCount(_ count: Int) throws {
    guard count > 0 else { throw SelectionError.emptySelection }
    guard count <= 50 else { throw SelectionError.selectionLimit }
  }

  static func applicationsOnly(_ selection: FamilyActivitySelection) throws -> FamilyActivitySelection {
    try validateSaveApplicationCount(selection.applicationTokens.count)
    return strippedApplicationTokens(from: selection)
  }

  static func normalizedStoredSelection(_ selection: FamilyActivitySelection) throws -> FamilyActivitySelection {
    let count = selection.applicationTokens.count
    guard count <= 50 else { throw SelectionError.selectionLimit }
    return strippedApplicationTokens(from: selection)
  }

  private static func strippedApplicationTokens(from selection: FamilyActivitySelection) -> FamilyActivitySelection {
    var apps = FamilyActivitySelection()
    apps.applicationTokens = selection.applicationTokens
    return apps
  }

  func save(_ selection: FamilyActivitySelection) throws {
    let validated = try Self.applicationsOnly(selection)
    let data = try JSONEncoder().encode(validated)
    try persistence.set(data, forKey: Self.selectionKey)
  }

  func load() -> FamilyActivitySelection? { try? loadValidated() }

  func loadValidated() throws -> FamilyActivitySelection? {
    guard let value = try persistence.object(forKey: Self.selectionKey) else { return nil }
    guard let data = value as? Data, let selection = try? Self.decode(data) else {
      try clearValidated()
      return nil
    }
    return selection
  }

  func clearValidated() throws { try persistence.set(nil, forKey: Self.selectionKey) }
  func clear() { try? clearValidated() }
}
