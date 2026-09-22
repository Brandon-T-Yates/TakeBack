import FamilyControls
import Foundation

/// Stores opaque app tokens only. This never reads the Flutter prototype key.
final class AllowedAppsStore {
  static let selectionKey = "takeback.ios.allowedApplications.v1"
  private let persistence: NativePersistence

  enum SelectionError: LocalizedError {
    case unsupportedSelection
    var errorDescription: String? {
      "Only individual apps are supported. Deselect categories and websites, "
        + "then expand categories to choose individual apps. Your previous allowlist has not changed."
    }
  }

  init(defaults: UserDefaults = .standard) {
    self.persistence = DefaultsNativePersistence(defaults)
  }

  init(persistence: NativePersistence) { self.persistence = persistence }

  static func decode(_ data: Data) throws -> FamilyActivitySelection {
    try applicationsOnly(JSONDecoder().decode(FamilyActivitySelection.self, from: data))
  }

  static func applicationsOnly(_ selection: FamilyActivitySelection) throws -> FamilyActivitySelection {
    try validateSelection(
      includesEntireCategory: selection.includeEntireCategory,
      categoryCount: selection.categoryTokens.count,
      webDomainCount: selection.webDomainTokens.count
    )
    var apps = FamilyActivitySelection()
    apps.applicationTokens = selection.applicationTokens
    return apps
  }

  static func validateSelection(includesEntireCategory: Bool, categoryCount: Int, webDomainCount: Int) throws {
    guard !includesEntireCategory, categoryCount == 0, webDomainCount == 0 else {
      throw SelectionError.unsupportedSelection
    }
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
