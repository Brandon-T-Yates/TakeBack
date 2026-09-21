import FamilyControls
import Foundation

/// Stores opaque app tokens only. This never reads the Flutter prototype key.
final class AllowedAppsStore {
  static let selectionKey = "takeback.ios.allowedApplications.v1"
  private let defaults: UserDefaults

  enum SelectionError: LocalizedError {
    case unsupportedSelection
    var errorDescription: String? {
      "Only individual apps are supported. Deselect categories and websites, "
        + "then expand categories to choose individual apps. Your previous allowlist has not changed."
    }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
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
    defaults.set(data, forKey: Self.selectionKey)
  }

  func load() -> FamilyActivitySelection? {
    guard let data = defaults.data(forKey: Self.selectionKey) else { return nil }
    do {
      return try Self.applicationsOnly(JSONDecoder().decode(FamilyActivitySelection.self, from: data))
    } catch {
      // Corrupt or unsupported stored data cannot become an allowlist.
      clear()
      return nil
    }
  }

  func clear() {
    defaults.removeObject(forKey: Self.selectionKey)
  }
}
