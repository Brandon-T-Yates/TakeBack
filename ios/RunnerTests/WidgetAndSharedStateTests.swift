import FamilyControls
import Foundation
import AppIntents
import XCTest
import SwiftUI
@testable import Runner

@MainActor
final class WidgetAndSharedStateTests: XCTestCase {
  private func context() throws -> SharedTestContext { try SharedTestContext() }

  @available(iOS 17.0, *)
  func testWidgetIntentIsPublishedByRunnerAndCannotOpenIt() {
    func requiresAppIntent<T: AppIntent>(_: T.Type) {}
    requiresAppIntent(SetLockdownIntent.self)
    XCTAssertFalse(SetLockdownIntent.openAppWhenRun)
    if #available(iOS 26.0, *) {
      XCTAssertEqual(SetLockdownIntent.supportedModes, .background)
    }
    if #available(iOS 27.0, *) {
      XCTAssertEqual(SetLockdownIntent.allowedExecutionTargets, .widgetKitExtension)
    }
  }

  func testMigrationPreservesSelectionIntentAndNeverTouchesPrototype() throws {
    for locked in [false, true] {
      let c = try context(); defer { c.cleanUp() }
      let data = try JSONEncoder().encode(FamilyActivitySelection())
      c.legacy.set(data, forKey: AllowedAppsStore.selectionKey)
      c.legacy.set(locked, forKey: SharedNativePersistence.intentKey)
      c.legacy.set(true, forKey: "takeback.prototype.lockdownEnabled")
      try c.shared.transaction { try c.shared.migrate(from: c.legacy) }
      XCTAssertEqual(try c.shared.object(forKey: AllowedAppsStore.selectionKey) as? Data, data)
      XCTAssertEqual(try c.shared.object(forKey: SharedNativePersistence.intentKey) as? Bool == true, locked)
      XCTAssertNil(c.legacy.object(forKey: AllowedAppsStore.selectionKey))
      XCTAssertTrue(c.legacy.bool(forKey: "takeback.prototype.lockdownEnabled"))
      XCTAssertNotNil(try AllowedAppsStore(persistence: c.shared).loadValidated())
    }
  }

  func testMigrationFailureRetainsLegacyAndInterruptedCommitIsNotRepeated() throws {
    let c = try context(); defer { c.cleanUp() }
    let data = try JSONEncoder().encode(FamilyActivitySelection())
    c.legacy.set(data, forKey: AllowedAppsStore.selectionKey)
    let failed = SharedNativePersistence(container: { c.root }, writeData: { _, _ in throw SharedNativePersistence.storageFailure })
    XCTAssertThrowsError(try failed.transaction { try failed.migrate(from: c.legacy) })
    XCTAssertEqual(c.legacy.data(forKey: AllowedAppsStore.selectionKey), data)
    let interrupted = SharedNativePersistence(container: { c.root }, writeData: { data, url in
      try data.write(to: url, options: .atomic)
      throw SharedNativePersistence.storageFailure
    })
    XCTAssertThrowsError(try interrupted.transaction { try interrupted.migrate(from: c.legacy) })
    XCTAssertEqual(c.legacy.data(forKey: AllowedAppsStore.selectionKey), data)
    // Shared revocation/deletion wins even if old private data remains after a crash.
    try c.shared.transaction { try c.shared.set(nil, forKey: AllowedAppsStore.selectionKey) }
    try c.shared.transaction { try c.shared.migrate(from: c.legacy) }
    XCTAssertNil(try c.shared.object(forKey: AllowedAppsStore.selectionKey))
    XCTAssertNil(c.legacy.object(forKey: AllowedAppsStore.selectionKey))
  }

  func testCorruptLegacySelectionIsDiscardedButCorruptSharedFileNeverImportsAgain() throws {
    let c = try context(); defer { c.cleanUp() }
    c.legacy.set(Data("invalid".utf8), forKey: AllowedAppsStore.selectionKey)
    try c.shared.transaction { try c.shared.migrate(from: c.legacy) }
    XCTAssertNil(try c.shared.object(forKey: AllowedAppsStore.selectionKey))
    let data = try JSONEncoder().encode(FamilyActivitySelection())
    c.legacy.set(data, forKey: AllowedAppsStore.selectionKey)
    let path = c.root.appendingPathComponent("takeback-native/state-v1.plist")
    try Data("broken".utf8).write(to: path)
    XCTAssertThrowsError(try c.shared.transaction { try c.shared.migrate(from: c.legacy) })
    XCTAssertEqual(c.legacy.data(forKey: AllowedAppsStore.selectionKey), data)
    XCTAssertEqual(try Data(contentsOf: path), Data("broken".utf8))
  }

  func testWidgetBeforeMigrationCannotClearExistingPolicy() throws {
    let c = try context(); defer { c.cleanUp() }
    c.backend.policy = .allowlist(["app"], active: true)
    let widget = c.coordinator()
    let snapshot = widget.snapshot()
    XCTAssertEqual(WidgetRestrictionState(snapshot), .setup)
    XCTAssertEqual(snapshot.failureCode, "setup_required")
    XCTAssertEqual(c.backend.policy, .allowlist(["app"], active: true))
    XCTAssertEqual(c.backend.clearCount, 0)
  }

  func testAppWidgetAndRelaunchUseSamePolicyWithoutReapplying() throws {
    let c = try context(); defer { c.cleanUp() }
    let app = c.coordinator(migrate: true)
    XCTAssertEqual(app.snapshot().restriction.state, .unlocked)
    // Inert test identifiers drive the real generic policy; no Apple token fabrication.
    try app.enable(authorization: "authorized")
    let widget = c.coordinator()
    XCTAssertEqual(widget.snapshot().restriction.state, .locked)
    XCTAssertEqual(try WidgetLockAction.perform(enabled: true, restrictions: widget, authorization: { c.authorization }), "locked")
    XCTAssertEqual(c.backend.applyCount, 1)
    XCTAssertEqual(c.coordinator().snapshot().restriction.state, .locked)
    XCTAssertEqual(try WidgetLockAction.perform(enabled: false, restrictions: widget, authorization: { c.authorization }), "unlocked")
    XCTAssertEqual(app.snapshot().restriction.state, .unlocked)
    try app.disable()
    XCTAssertGreaterThan(c.notifications, 0)
  }

  func testUnresolvedAuthorizationRetainsSelectionThenRevocationClearsAndNotifies() throws {
    let c = try context(); defer { c.cleanUp() }
    c.legacy.set(try JSONEncoder().encode(FamilyActivitySelection()), forKey: AllowedAppsStore.selectionKey)
    let app = c.coordinator(migrate: true)
    _ = app.snapshot()
    try app.enable(authorization: "authorized")
    c.authorization = "notDetermined"
    let widget = c.coordinator()
    XCTAssertEqual(widget.snapshot().restriction.state, .checking)
    XCTAssertNotNil(try c.shared.object(forKey: AllowedAppsStore.selectionKey))
    XCTAssertThrowsError(try WidgetLockAction.perform(enabled: true, restrictions: widget, authorization: { c.authorization }))
    c.authorization = "authorized"
    XCTAssertEqual(widget.snapshot().restriction.state, .locked)
    c.authorization = "denied"
    XCTAssertEqual(widget.snapshot().restriction.state, .unlocked)
    XCTAssertNil(try c.shared.object(forKey: AllowedAppsStore.selectionKey))
    XCTAssertNil(try c.shared.object(forKey: SharedNativePersistence.intentKey))
    XCTAssertEqual(c.backend.policy, .clear)
    XCTAssertGreaterThan(c.notifications, 1)
  }

  func testPendingClearIsVisibleToAnotherProcessAndCanRecover() throws {
    let c = try context(); defer { c.cleanUp() }
    let app = c.coordinator(migrate: true); _ = app.snapshot()
    try app.enable(authorization: "authorized")
    c.backend.ignoreClear = true
    XCTAssertThrowsError(try app.disable())
    XCTAssertEqual(try c.shared.object(forKey: SharedNativePersistence.pendingClearKey) as? Bool, true)
    let widget = c.coordinator()
    XCTAssertEqual(widget.snapshot().restriction.state, .error)
    c.backend.ignoreClear = false
    try widget.disable()
    XCTAssertEqual(app.snapshot().restriction.state, .unlocked)
    XCTAssertNil(try c.shared.object(forKey: SharedNativePersistence.pendingClearKey))
  }

  func testPickerAndAuthorizationLeaseRejectActivationButPermitUnlock() throws {
    let c = try context(); defer { c.cleanUp() }
    let app = c.coordinator(migrate: true); _ = app.snapshot()
    let widget = c.coordinator()
    var lease: NativeFileLease? = try app.beginSetup(requireUnlocked: true)
    XCTAssertThrowsError(try widget.enable(authorization: "authorized"))
    XCTAssertEqual(c.backend.applyCount, 0)
    try widget.disable()
    withExtendedLifetime(lease) {}
    lease = nil
    try widget.enable(authorization: "authorized")
    XCTAssertThrowsError(try app.beginSetup(requireUnlocked: true))
  }

  func testCompetingTransactionDoesNotClearOrClaimSuccess() throws {
    let c = try context(); defer { c.cleanUp() }
    let app = c.coordinator(migrate: true); _ = app.snapshot()
    try app.enable(authorization: "authorized")
    let otherStore = SharedNativePersistence(container: { c.root })
    let lease = try otherStore.lease("transaction")
    try withExtendedLifetime(lease) {
      XCTAssertEqual(app.snapshot().restriction.state, .error)
      XCTAssertThrowsError(try app.disable())
      XCTAssertEqual(c.backend.policy, .allowlist(["app"], active: true))
    }
  }

  func testWidgetActivationValidationAndFailedWriteNeverReturnSuccess() throws {
    let c = try context(); defer { c.cleanUp() }
    let app = c.coordinator(migrate: true); _ = app.snapshot()
    for tokens in [nil, Set<String>(), Set((0...50).map(String.init))] as [Set<String>?] {
      c.tokens = tokens
      XCTAssertThrowsError(try WidgetLockAction.perform(enabled: true, restrictions: app, authorization: { "authorized" }))
      XCTAssertEqual(c.backend.applyCount, 0)
    }
    c.tokens = ["app"]
    c.backend.dropApply = true
    XCTAssertThrowsError(try WidgetLockAction.perform(enabled: true, restrictions: app, authorization: { "authorized" }))
    XCTAssertEqual(app.snapshot().restriction.state, .unlocked)
    XCTAssertNil(try c.shared.object(forKey: SharedNativePersistence.intentKey))
  }

  func testWidgetPresentationAndExplicitRequests() {
    let unlocked = WidgetRestrictionState(state: .unlocked, authorization: "authorized", applicationCount: 2)
    XCTAssertEqual(unlocked.symbol, "lock.open.fill")
    XCTAssertEqual(unlocked.title, "LOCK IN")
    XCTAssertEqual(unlocked.requestedEnabled, true)
    let locked = WidgetRestrictionState(state: .locked, authorization: "authorized", applicationCount: 2)
    XCTAssertEqual(locked.symbol, "lock.fill")
    XCTAssertEqual(locked.title, "UNLOCK")
    XCTAssertEqual(locked.requestedEnabled, false)
    for state in [LockdownState.checking, .error] {
      let recovery = WidgetRestrictionState(state: state, authorization: "unavailable", applicationCount: nil)
      XCTAssertTrue(recovery.uncertain)
      XCTAssertEqual(recovery.requestedEnabled, false)
    }
    for count in [nil, 0, 51] as [Int?] {
      let setup = WidgetRestrictionState(state: .unlocked, authorization: "authorized", applicationCount: count)
      XCTAssertEqual(setup.title, "Open Unbound")
      XCTAssertNil(setup.requestedEnabled)
    }
  }

  func testWidgetRendersDistinctVerifiedAndRecoveryControls() throws {
    let states: [WidgetRestrictionState] = [.unlocked, .locked, .setup, .recovery]
    let images = try states.map { state in
      let renderer = ImageRenderer(content: WidgetControlLabel(state: state)
        .foregroundStyle(Color.black).frame(width: 160, height: 120).background(Color.white))
      return try XCTUnwrap(renderer.uiImage?.pngData())
    }
    XCTAssertEqual(Set(images).count, 4)
  }

  func testStorageFailureStillAttemptsClearWithoutReportingSuccess() throws {
    let backend = SharedFakeBackend()
    backend.policy = .allowlist(["app"], active: true)
    let policy = RestrictionPolicy(backend: backend, persistence: UnavailablePersistence()) { Set(["app"]) }
    XCTAssertThrowsError(try policy.disable())
    XCTAssertEqual(backend.policy, .clear)
    backend.policy = .allowlist(["app"], active: true)
    XCTAssertEqual(policy.reconcile(authorization: "denied").state, .error)
    XCTAssertEqual(backend.policy, .clear)
  }

  func testUnavailableAppGroupStillAllowsClearAttempt() throws {
    let backend = SharedFakeBackend()
    backend.policy = .allowlist(["app"], active: true)
    let coordinator = NativeRestrictionCoordinator(persistence: SharedNativePersistence(container: { nil }),
      authorization: { "authorized" }, changed: {}, makeRestrictions: { _, persistence in
        RestrictionPolicy(backend: backend, persistence: persistence) { Set(["app"]) }
      })
    XCTAssertEqual(coordinator.snapshot().restriction.state, .error)
    XCTAssertThrowsError(try coordinator.disable())
    XCTAssertEqual(backend.policy, .clear)
    XCTAssertEqual(backend.clearCount, 1)
  }

  func testDarwinNotificationContainsNoPayloadAndReachesObserver() async {
    let delivered = expectation(description: "Native state invalidation received")
    let observer = NativeChangeObserver { delivered.fulfill() }
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(NativeWidgetChanges.notification), nil, nil, true)
    await fulfillment(of: [delivered], timeout: 3)
    withExtendedLifetime(observer) {}
  }
}

@MainActor
private final class SharedTestContext {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let suite = "unbound.widget.tests.\(UUID().uuidString)"
  let legacy: UserDefaults
  lazy var shared = SharedNativePersistence(container: { [unowned self] in self.root })
  let backend = SharedFakeBackend()
  var tokens: Set<String>? = ["app"]
  var authorization = "authorized"
  var notifications = 0
  init() throws { legacy = try XCTUnwrap(UserDefaults(suiteName: suite)) }
  func coordinator(migrate: Bool = false) -> NativeRestrictionCoordinator {
    NativeRestrictionCoordinator(persistence: shared, legacy: migrate ? legacy : nil,
      authorization: { [unowned self] in self.authorization }, changed: { [unowned self] in self.notifications += 1 },
      makeRestrictions: { _, persistence in
        RestrictionPolicy(backend: self.backend, persistence: persistence) { [unowned self] in self.tokens }
      })
  }
  func cleanUp() { legacy.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
}

@MainActor
private final class SharedFakeBackend: RestrictionBackend {
  var policy: ShieldPolicy<String> = .clear
  var applyCount = 0
  var clearCount = 0
  var ignoreClear = false
  var dropApply = false
  func read() throws -> ShieldPolicy<String> { policy }
  func apply(allowing tokens: Set<String>) throws {
    applyCount += 1
    if !dropApply { policy = .allowlist(tokens, active: true) }
  }
  func clear() throws { clearCount += 1; if !ignoreClear { policy = .clear } }
}

private final class UnavailablePersistence: NativePersistence {
  func object(forKey key: String) throws -> Any? { throw SharedNativePersistence.storageFailure }
  func set(_ value: Any?, forKey key: String) throws { throw SharedNativePersistence.storageFailure }
}
