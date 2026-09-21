import FamilyControls
import Flutter
import UIKit
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

  @MainActor
  func testAuthorizedSelectionSurvivesBridgeAndStoreRecreation() throws {
    let context = try PersistenceContext()
    defer { context.cleanUp() }
    XCTAssertEqual(try context.snapshot()["selectionUsable"] as? Bool, false)
    // A deliberately saved empty selection is valid; no fabricated Apple tokens.
    try context.store.save(FamilyActivitySelection())
    let savedData = try XCTUnwrap(context.defaults.data(forKey: AllowedAppsStore.selectionKey))
    XCTAssertEqual(try context.snapshot()["selectionUsable"] as? Bool, true)

    try context.relaunch()

    let state = try context.snapshot()
    XCTAssertEqual(state["authorization"] as? String, "authorized")
    XCTAssertEqual(state["hasSavedSelection"] as? Bool, true)
    XCTAssertEqual(state["selectionUsable"] as? Bool, true)
    XCTAssertEqual(context.defaults.data(forKey: AllowedAppsStore.selectionKey), savedData)
  }

  @MainActor
  func testUnresolvedStartupRetainsSelectionUntilApprovalReturns() throws {
    for unavailable in [false, true] {
      let context = try PersistenceContext()
      defer { context.cleanUp() }
      try context.store.save(FamilyActivitySelection())
      let savedData = try XCTUnwrap(context.defaults.data(forKey: AllowedAppsStore.selectionKey))
      context.status = .notDetermined
      context.available = !unavailable
      try context.relaunch()

      // Repeated startup/foreground reads must not destroy the stored bytes.
      for _ in 0..<3 {
        let state = try context.snapshot()
        XCTAssertEqual(state["authorization"] as? String, unavailable ? "unavailable" : "notDetermined")
        XCTAssertEqual(state["selectionUsable"] as? Bool, false)
        XCTAssertEqual(state["hasSavedSelection"] as? Bool, false)
        XCTAssertEqual(context.defaults.data(forKey: AllowedAppsStore.selectionKey), savedData)
      }

      context.status = .approved
      context.available = true
      try context.relaunch()
      XCTAssertEqual(try context.snapshot()["selectionUsable"] as? Bool, true)
      XCTAssertEqual(context.defaults.data(forKey: AllowedAppsStore.selectionKey), savedData)
    }
  }

  @MainActor
  func testDeniedAuthorizationClearsSelectionAcrossRelaunch() throws {
    let context = try PersistenceContext()
    defer { context.cleanUp() }
    try context.store.save(FamilyActivitySelection())
    context.status = .denied
    try context.relaunch()

    let state = try context.snapshot()
    XCTAssertEqual(state["authorization"] as? String, "denied")
    XCTAssertEqual(state["selectionUsable"] as? Bool, false)
    XCTAssertNil(context.defaults.object(forKey: AllowedAppsStore.selectionKey))

    context.status = .approved
    try context.relaunch()
    XCTAssertEqual(try context.snapshot()["hasSavedSelection"] as? Bool, false)
  }

  @MainActor
  func testCorruptAndUnsupportedSelectionsAreRemovedEvenWhileAuthorizationIsUnresolved() throws {
    let context = try PersistenceContext()
    defer { context.cleanUp() }
    context.status = .notDetermined
    let unsupported = try JSONEncoder().encode(FamilyActivitySelection(includeEntireCategory: true))
    for invalidValue in [Data("invalid JSON".utf8), unsupported, "wrong storage type"] as [Any] {
      context.defaults.set(invalidValue, forKey: AllowedAppsStore.selectionKey)
      let state = try context.snapshot()
      XCTAssertEqual(state["hasSavedSelection"] as? Bool, false)
      XCTAssertEqual(state["selectionUsable"] as? Bool, false)
      XCTAssertNil(context.defaults.object(forKey: AllowedAppsStore.selectionKey))
    }
  }

  @MainActor
  func testSceneActivationRetainsRestoresAndRevokesSelection() async throws {
    let context = try PersistenceContext()
    defer { context.cleanUp() }
    try context.store.save(FamilyActivitySelection())
    let savedData = try XCTUnwrap(context.defaults.data(forKey: AllowedAppsStore.selectionKey))

    for status in [AuthorizationStatus.notDetermined, .approved, .denied] {
      context.status = status
      let changed = expectation(description: "Scene activation sends setupChanged")
      var state: [String: Any]?
      context.messenger.onMethodCall = { call in
        guard call.method == "setupChanged" else { return }
        state = call.arguments as? [String: Any]
        changed.fulfill()
      }
      NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
      await fulfillment(of: [changed], timeout: 2)
      context.messenger.onMethodCall = nil

      XCTAssertEqual(try XCTUnwrap(state)["selectionUsable"] as? Bool, status == .approved)
      if status == .denied {
        XCTAssertNil(context.defaults.object(forKey: AllowedAppsStore.selectionKey))
      } else {
        XCTAssertEqual(context.defaults.data(forKey: AllowedAppsStore.selectionKey), savedData)
      }
    }
  }
}

@MainActor
private final class PersistenceContext {
  private let suite = "takeback.persistence.tests.\(UUID().uuidString)"
  private(set) var defaults: UserDefaults!
  private(set) var store: AllowedAppsStore!
  private var bridge: FamilyControlsBridge?
  let messenger = TestBinaryMessenger()
  var status: AuthorizationStatus = .approved
  var available = true

  init() throws { try relaunch() }

  func relaunch() throws {
    bridge = nil
    defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    store = AllowedAppsStore(defaults: defaults)
    bridge = FamilyControlsBridge(
      messenger: messenger,
      store: store,
      available: available,
      authorizationStatus: { [unowned self] in self.status },
      presenter: { nil }
    )
  }

  func snapshot() throws -> [String: Any] {
    let handler = try XCTUnwrap(messenger.handler)
    let codec = FlutterStandardMethodCodec.sharedInstance()
    var reply: Data?
    handler(codec.encode(FlutterMethodCall(methodName: "getSetupState", arguments: nil))) { reply = $0 }
    return try XCTUnwrap(codec.decodeEnvelope(try XCTUnwrap(reply)) as? [String: Any])
  }

  func cleanUp() {
    bridge = nil
    defaults.removePersistentDomain(forName: suite)
  }
}

private final class TestBinaryMessenger: NSObject, FlutterBinaryMessenger {
  var handler: FlutterBinaryMessageHandler?
  var onMethodCall: ((FlutterMethodCall) -> Void)?

  func send(onChannel channel: String, message: Data?) {
    guard let message else { return }
    onMethodCall?(FlutterStandardMethodCodec.sharedInstance().decodeMethodCall(message))
  }

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    send(onChannel: channel, message: message)
    callback?(nil)
  }

  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    self.handler = handler
    return 1
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) { handler = nil }
}
