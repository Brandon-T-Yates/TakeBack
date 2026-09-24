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
    XCTAssertEqual(try context.snapshot()["selectionUsable"] as? Bool, false)

    try context.relaunch()

    let state = try context.snapshot()
    XCTAssertEqual(state["authorization"] as? String, "authorized")
    XCTAssertEqual(state["hasSavedSelection"] as? Bool, true)
    XCTAssertEqual(state["applicationCount"] as? Int, 0)
    XCTAssertEqual(state["selectionUsable"] as? Bool, false)
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
      let restored = try context.snapshot()
      XCTAssertEqual(restored["hasSavedSelection"] as? Bool, true)
      XCTAssertEqual(restored["selectionUsable"] as? Bool, false)
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

      XCTAssertEqual(try XCTUnwrap(state)["selectionUsable"] as? Bool, false)
      XCTAssertEqual(try XCTUnwrap(state)["hasSavedSelection"] as? Bool, status == .approved)
      if status == .denied {
        XCTAssertNil(context.defaults.object(forKey: AllowedAppsStore.selectionKey))
      } else {
        XCTAssertEqual(context.defaults.data(forKey: AllowedAppsStore.selectionKey), savedData)
      }
    }
  }

  @MainActor
  func testBridgeUsesOneMonotonicRevisionDomainForRepliesAndEvents() async throws {
    let context = try PersistenceContext()
    defer { context.cleanUp() }
    let first = try XCTUnwrap(try context.snapshot()["revision"] as? Int)
    let changed = expectation(description: "Scene activation emits revisioned setupChanged")
    var eventRevision: Int?
    context.messenger.onMethodCall = { call in
      guard call.method == "setupChanged" else { return }
      eventRevision = (call.arguments as? [String: Any])?["revision"] as? Int
      changed.fulfill()
    }

    NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
    await fulfillment(of: [changed], timeout: 2)
    context.messenger.onMethodCall = nil
    let event = try XCTUnwrap(eventRevision)
    let final = try XCTUnwrap(try context.snapshot()["revision"] as? Int)

    XCTAssertLessThan(first, event)
    XCTAssertLessThan(event, final)
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

@MainActor
final class RestrictionPolicyTests: XCTestCase {
  func testActivationRequiresAuthorizationAndValidNonemptyBoundedSelection() throws {
    let c = try RestrictionTestContext()
    defer { c.cleanUp() }
    for status in ["notDetermined", "denied", "unavailable"] {
      XCTAssertThrowsError(try c.policy.enable(authorization: status))
    }
    c.selection = nil
    XCTAssertThrowsError(try c.policy.enable(authorization: "authorized"))
    c.selection = []
    XCTAssertThrowsError(try c.policy.enable(authorization: "authorized")) { error in
      XCTAssertEqual((error as? RestrictionFailure)?.code, "empty_selection")
    }
    c.selection = Set((0...50).map(String.init))
    XCTAssertThrowsError(try c.policy.enable(authorization: "authorized"))
    XCTAssertEqual(c.backend.applyCount, 0)
    XCTAssertFalse(c.intent)
    c.selection = Set((0..<50).map(String.init))
    try c.policy.enable(authorization: "authorized")
    XCTAssertEqual(c.backend.policy, .allowlist(c.selection!, active: true))
  }

  func testEnableAndDisableAreIdempotentAndOnlyUseNativeIntent() throws {
    let c = try RestrictionTestContext()
    defer { c.cleanUp() }
    c.defaults.set(true, forKey: "takeback.prototype.lockdownEnabled")
    XCTAssertEqual(c.policy.reconcile(authorization: "authorized").state, .unlocked)
    XCTAssertEqual(c.backend.applyCount, 0)
    try c.policy.enable(authorization: "authorized")
    try c.policy.enable(authorization: "authorized")
    XCTAssertEqual(c.backend.applyCount, 1)
    XCTAssertTrue(c.intent)
    XCTAssertEqual(c.backend.policy, .allowlist(["allowed-a", "allowed-b"], active: true))
    XCTAssertEqual(c.policy.reconcile(authorization: "authorized").state, .locked)
    try c.policy.disable()
    try c.policy.disable()
    XCTAssertEqual(c.backend.policy, .clear)
    XCTAssertFalse(c.intent)
    XCTAssertTrue(c.defaults.bool(forKey: "takeback.prototype.lockdownEnabled"))
  }

  func testRelaunchReadsExistingPolicyWithoutReapplying() throws {
    let c = try RestrictionTestContext()
    defer { c.cleanUp() }
    try c.policy.enable(authorization: "authorized")
    let relaunched = c.makePolicy()
    XCTAssertEqual(relaunched.reconcile(authorization: "authorized").state, .locked)
    XCTAssertEqual(c.backend.applyCount, 1)
    c.backend.policy = .clear
    XCTAssertEqual(relaunched.reconcile(authorization: "authorized").state, .unlocked)
    XCTAssertFalse(c.intent)
    XCTAssertEqual(c.backend.applyCount, 1)
  }

  func testUnresolvedAuthorizationPreservesPolicyButDenialClearsIt() throws {
    let c = try RestrictionTestContext()
    defer { c.cleanUp() }
    try c.policy.enable(authorization: "authorized")
    for authorization in ["notDetermined", "unavailable"] {
      XCTAssertEqual(c.policy.reconcile(authorization: authorization).state, .checking)
      XCTAssertTrue(c.intent)
      XCTAssertEqual(c.backend.policy, .allowlist(c.selection!, active: true))
      XCTAssertThrowsError(try c.policy.enable(authorization: authorization))
    }
    XCTAssertEqual(c.policy.reconcile(authorization: "authorized").state, .locked)
    XCTAssertEqual(c.policy.reconcile(authorization: "denied").state, .unlocked)
    XCTAssertEqual(c.backend.policy, .clear)
    XCTAssertFalse(c.intent)
    XCTAssertEqual(c.policy.reconcile(authorization: "authorized").state, .unlocked)
  }

  func testOrphanMismatchedInvalidAndInactivePoliciesAreCleared() throws {
    let c = try RestrictionTestContext()
    defer { c.cleanUp() }
    let invalidPolicies: [ShieldPolicy<String>] = [
      .allowlist(["another-app"], active: true),
      .allowlist(c.selection!, active: false), .unexpected,
    ]
    for policy in invalidPolicies {
      c.defaults.set(true, forKey: RestrictionPolicy<FakeRestrictionBackend>.intentKey)
      c.backend.policy = policy
      XCTAssertEqual(c.policy.reconcile(authorization: "authorized").state, .unlocked)
      XCTAssertEqual(c.backend.policy, .clear)
      XCTAssertFalse(c.intent)
    }
    c.backend.policy = .allowlist(c.selection!, active: true)
    XCTAssertEqual(c.policy.reconcile(authorization: "authorized").state, .unlocked)
    XCTAssertEqual(c.backend.policy, .clear)
    for invalidSelection in [nil, Set<String>()] as [Set<String>?] {
      c.selection = ["allowed-a"]
      try c.policy.enable(authorization: "authorized")
      c.selection = invalidSelection
      XCTAssertEqual(c.policy.reconcile(authorization: "authorized").state, .unlocked)
      XCTAssertEqual(c.backend.policy, .clear)
    }
  }

  func testFailedApplyRollsBackAndFailedClearRetainsRecoveryState() throws {
    let c = try RestrictionTestContext()
    defer { c.cleanUp() }
    c.backend.dropApply = true
    XCTAssertThrowsError(try c.policy.enable(authorization: "authorized"))
    XCTAssertEqual(c.backend.policy, .clear)
    XCTAssertFalse(c.intent)
    c.backend.dropApply = false
    c.backend.throwAfterApply = true
    XCTAssertThrowsError(try c.policy.enable(authorization: "authorized"))
    XCTAssertEqual(c.backend.policy, .clear)
    c.backend.throwAfterApply = false
    try c.policy.enable(authorization: "authorized")
    c.backend.ignoreClear = true
    XCTAssertThrowsError(try c.policy.disable())
    XCTAssertTrue(c.intent)
    XCTAssertEqual(c.policy.reconcile(authorization: "authorized").state, .error)
    XCTAssertEqual(c.policy.reconcile(authorization: "denied").state, .error)
    c.backend.failRead = true
    XCTAssertEqual(c.policy.reconcile(authorization: "authorized").state, .error)
    XCTAssertThrowsError(try c.policy.enable(authorization: "authorized"))
    c.backend.failRead = false
    c.backend.ignoreClear = false
    try c.policy.disable()
    XCTAssertEqual(c.policy.reconcile(authorization: "authorized").state, .unlocked)
    XCTAssertFalse(c.intent)
  }

  func testFailedPartialApplyAndCleanupCannotClaimUnlocked() throws {
    let c = try RestrictionTestContext()
    defer { c.cleanUp() }
    c.backend.throwAfterApply = true
    c.backend.ignoreClear = true
    XCTAssertThrowsError(try c.policy.enable(authorization: "authorized")) { error in
      XCTAssertEqual((error as? RestrictionFailure)?.code, "restriction_clear_failed")
    }
    XCTAssertEqual(c.policy.reconcile(authorization: "authorized").state, .error)
    c.backend.ignoreClear = false
    try c.policy.disable()
    XCTAssertEqual(c.backend.policy, .clear)
  }

  func testInactiveWriteCannotBeReportedAsLocked() throws {
    let c = try RestrictionTestContext()
    defer { c.cleanUp() }
    c.backend.applyActive = false
    XCTAssertThrowsError(try c.policy.enable(authorization: "authorized"))
    XCTAssertFalse(c.intent)
    XCTAssertEqual(c.backend.policy, .clear)
  }

  func testSceneRevocationClearsNativePolicyAndSelectionAndNotifiesFlutter() async throws {
    let c = try RestrictionTestContext()
    defer { c.cleanUp() }
    let store = AllowedAppsStore(defaults: c.defaults)
    try store.save(FamilyActivitySelection())
    try c.policy.enable(authorization: "authorized")
    let messenger = TestBinaryMessenger()
    var authorization = AuthorizationStatus.approved
    let bridge = FamilyControlsBridge(messenger: messenger, store: store, available: true,
      authorizationStatus: { authorization }, restrictions: c.policy, presenter: { nil })
    defer { withExtendedLifetime(bridge) {} }
    let notification = expectation(description: "Revocation emits reconciled state")
    messenger.onMethodCall = { call in
      guard call.method == "setupChanged" else { return }
      let state = call.arguments as? [String: Any]
      XCTAssertEqual(state?["lockdownState"] as? String, "unlocked")
      XCTAssertEqual(state?["selectionUsable"] as? Bool, false)
      notification.fulfill()
    }
    authorization = .denied
    NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
    await fulfillment(of: [notification], timeout: 2)
    XCTAssertNil(store.load())
    XCTAssertEqual(c.backend.policy, .clear)
    XCTAssertFalse(c.intent)
  }

  func testEnableIsRejectedWhilePickerIsOpen() throws {
    let messenger = TestBinaryMessenger()
    let restrictions = StubRestrictions()
    let parent = NonPresentingViewController()
    let bridge = FamilyControlsBridge(messenger: messenger, available: true,
      authorizationStatus: { .approved }, restrictions: restrictions, presenter: { parent })
    defer { withExtendedLifetime(bridge) {} }
    let handler = try XCTUnwrap(messenger.handler)
    let codec = FlutterStandardMethodCodec.sharedInstance()
    handler(codec.encode(FlutterMethodCall(methodName: "selectAllowedApps", arguments: nil))) { _ in }
    XCTAssertTrue(parent.pickerPresented)
    var reply: Data?
    handler(codec.encode(FlutterMethodCall(methodName: "enableLockdown", arguments: nil))) { reply = $0 }
    XCTAssertEqual((codec.decodeEnvelope(try XCTUnwrap(reply)) as? FlutterError)?.code, "busy")
    XCTAssertEqual(restrictions.enableCount, 0)
  }

  func testAuthorizationChangeRevokesOpenPickerExactlyOnce() async throws {
    let messenger = TestBinaryMessenger()
    let restrictions = StubRestrictions()
    let parent = NonPresentingViewController()
    var authorization = AuthorizationStatus.approved
    let bridge = FamilyControlsBridge(messenger: messenger, available: true,
      authorizationStatus: { authorization }, restrictions: restrictions, presenter: { parent })
    defer { withExtendedLifetime(bridge) {} }
    let handler = try XCTUnwrap(messenger.handler)
    let codec = FlutterStandardMethodCodec.sharedInstance()
    var pickerReplies = 0
    var pickerReply: Data?
    handler(codec.encode(FlutterMethodCall(methodName: "selectAllowedApps", arguments: nil))) {
      pickerReplies += 1
      pickerReply = $0
    }
    XCTAssertTrue(parent.pickerPresented)
    XCTAssertEqual(pickerReplies, 0)

    let changed = expectation(description: "Each authorization refresh emits setupChanged")
    changed.expectedFulfillmentCount = 2
    messenger.onMethodCall = { call in
      if call.method == "setupChanged" { changed.fulfill() }
    }
    authorization = .denied
    NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
    NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
    await fulfillment(of: [changed], timeout: 2)

    XCTAssertEqual(pickerReplies, 1)
    let error = codec.decodeEnvelope(try XCTUnwrap(pickerReply)) as? FlutterError
    XCTAssertEqual(error?.code, "authorization_revoked")
    XCTAssertEqual(restrictions.state, .unlocked)
  }

  func testBridgeGuardsPickerAndUsesUnlockForUncertainToggle() throws {
    let messenger = TestBinaryMessenger()
    let restrictions = StubRestrictions()
    let bridge = FamilyControlsBridge(messenger: messenger, available: true,
      authorizationStatus: { .approved }, restrictions: restrictions, presenter: { nil })
    defer { withExtendedLifetime(bridge) {} }
    let codec = FlutterStandardMethodCodec.sharedInstance()
    func invoke(_ method: String) throws -> Any? {
      var reply: Data?
      try XCTUnwrap(messenger.handler)(codec.encode(FlutterMethodCall(methodName: method, arguments: nil))) { reply = $0 }
      return codec.decodeEnvelope(try XCTUnwrap(reply))
    }
    for state in [LockdownState.locked, .checking, .error] {
      restrictions.state = state
      let error = try invoke("selectAllowedApps") as? FlutterError
      XCTAssertEqual(error?.code, "unlock_required")
      restrictions.state = state
      _ = try invoke("toggleLockdown")
      XCTAssertEqual(restrictions.state, .unlocked)
    }
    XCTAssertEqual(restrictions.enableCount, 0)
    XCTAssertEqual(restrictions.disableCount, 3)
    restrictions.state = .checking
    XCTAssertEqual((try invoke("isLockdownEnabled") as? FlutterError)?.code, "restriction_state_unknown")
    restrictions.state = .locked
    XCTAssertEqual(try invoke("isLockdownEnabled") as? Bool, true)
  }
}

@MainActor
private final class RestrictionTestContext {
  let suite = "takeback.restriction.tests.\(UUID().uuidString)"
  let backend = FakeRestrictionBackend()
  var defaults: UserDefaults!
  var selection: Set<String>? = ["allowed-a", "allowed-b"]
  lazy var policy = makePolicy()
  var intent: Bool { defaults.bool(forKey: RestrictionPolicy<FakeRestrictionBackend>.intentKey) }
  init() throws { defaults = try XCTUnwrap(UserDefaults(suiteName: suite)) }
  func makePolicy() -> RestrictionPolicy<FakeRestrictionBackend> {
    RestrictionPolicy(backend: backend, defaults: defaults) { [unowned self] in self.selection }
  }
  func cleanUp() { defaults.removePersistentDomain(forName: suite) }
}

@MainActor
private final class FakeRestrictionBackend: RestrictionBackend {
  var policy: ShieldPolicy<String> = .clear
  var applyCount = 0
  var dropApply = false
  var throwAfterApply = false
  var ignoreClear = false
  var failRead = false
  var applyActive = true
  func read() throws -> ShieldPolicy<String> {
    if failRead { throw RestrictionFailure(code: "read", message: "Test read failure") }
    return policy
  }
  func apply(allowing tokens: Set<String>) throws {
    applyCount += 1
    if !dropApply { policy = .allowlist(tokens, active: applyActive) }
    if throwAfterApply { throw RestrictionFailure(code: "write", message: "Test partial write") }
  }
  func clear() throws { if !ignoreClear { policy = .clear } }
}

@MainActor
private final class StubRestrictions: RestrictionControlling {
  var state = LockdownState.unlocked
  var enableCount = 0
  var disableCount = 0
  func reconcile(authorization: String) -> RestrictionSnapshot { RestrictionSnapshot(state: state) }
  func enable(authorization: String) throws { enableCount += 1; state = .locked }
  func disable() throws { disableCount += 1; state = .unlocked }
}

@MainActor
private final class NonPresentingViewController: UIViewController {
  var pickerPresented = false
  override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
    pickerPresented = true
    completion?()
  }
}
