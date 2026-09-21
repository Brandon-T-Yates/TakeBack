import FamilyControls
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testDefaultSelectionIsAppSpecific() throws {
    let apps = try AllowedAppsStore.applicationsOnly(FamilyActivitySelection())
    XCTAssertFalse(apps.includeEntireCategory)
    XCTAssertTrue(apps.categoryTokens.isEmpty)
    XCTAssertTrue(apps.webDomainTokens.isEmpty)
  }

  func testRejectsCategoriesWebsitesAndCategoryExpansion() {
    XCTAssertThrowsError(try AllowedAppsStore.validateSelection(
      includesEntireCategory: false, categoryCount: 1, webDomainCount: 0))
    XCTAssertThrowsError(try AllowedAppsStore.validateSelection(
      includesEntireCategory: false, categoryCount: 0, webDomainCount: 1))
    XCTAssertThrowsError(try AllowedAppsStore.validateSelection(
      includesEntireCategory: true, categoryCount: 0, webDomainCount: 0))
  }

  func testRestoreClearAndRejectedSavePreservesPreviousSelection() throws {
    let suite = "takeback.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = AllowedAppsStore(defaults: defaults)
    XCTAssertNil(store.load())
    try store.save(FamilyActivitySelection())
    let savedData = defaults.data(forKey: AllowedAppsStore.selectionKey)
    XCTAssertNotNil(AllowedAppsStore(defaults: defaults).load())
    XCTAssertThrowsError(try store.save(FamilyActivitySelection(includeEntireCategory: true)))
    XCTAssertEqual(defaults.data(forKey: AllowedAppsStore.selectionKey), savedData)
    store.clear()
    XCTAssertNil(AllowedAppsStore(defaults: defaults).load())
  }
}
