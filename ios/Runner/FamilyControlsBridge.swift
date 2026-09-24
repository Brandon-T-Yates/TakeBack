import Combine
import FamilyControls
import Flutter
import SwiftUI
import UIKit

/// Native authorization, picker, token storage, and restriction service boundary.
@MainActor
final class FamilyControlsBridge: NSObject, UIAdaptivePresentationControllerDelegate {
  private let channel: FlutterMethodChannel
  private let presenter: () -> UIViewController?
  private let store: AllowedAppsStore
  private let available: Bool
  private let authorizationStatus: () -> AuthorizationStatus
  private let restrictions: (any RestrictionControlling)?
  private let coordinator: NativeRestrictionCoordinator?
  private var setupLease: NativeFileLease?
  private var sharedObserver: NativeChangeObserver?
  private var authorizationObserver: AnyCancellable?
  private var foregroundObserver: AnyCancellable?
  private var pickerController: UIViewController?
  private var pickerResult: FlutterResult?
  private var requestingAuthorization = false

  init(
    messenger: FlutterBinaryMessenger,
    store: AllowedAppsStore = AllowedAppsStore(),
    available: Bool? = nil,
    authorizationStatus: @escaping () -> AuthorizationStatus = { AuthorizationCenter.shared.authorizationStatus },
    restrictions: (any RestrictionControlling)? = nil,
    presenter: @escaping () -> UIViewController?
  ) {
    self.channel = FlutterMethodChannel(name: "takeback/family_controls", binaryMessenger: messenger)
    self.store = store
    self.available = available ?? Self.platformAvailable
    self.authorizationStatus = authorizationStatus
    #if targetEnvironment(simulator)
    self.coordinator = nil
    self.restrictions = restrictions
    #else
    let coordinator = restrictions == nil
      ? NativeRestrictionCoordinator(legacy: .standard, recordsVerifiedAuthorization: true)
      : nil
    self.coordinator = coordinator
    self.restrictions = restrictions ?? coordinator
    #endif
    self.presenter = presenter
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      self.handle(call, result: result)
    }
    if coordinator != nil {
      sharedObserver = NativeChangeObserver { [weak self] in self?.authorizationChanged() }
    }
    #if !targetEnvironment(simulator)
    authorizationObserver = AuthorizationCenter.shared.$authorizationStatus
      .removeDuplicates()
      .receive(on: RunLoop.main)
      .sink { [weak self] status in
        // Do not lose a definite denial if a later status arrives before delivery.
        self?.authorizationChanged(denied: status == .denied)
      }
    #endif
    // Scene activation also refreshes authorization after returning from Settings.
    foregroundObserver = NotificationCenter.default.publisher(for: UIScene.didActivateNotification)
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.authorizationChanged() }
  }

  private static var platformAvailable: Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    return true
    #endif
  }

  private var authorization: String {
    guard available else { return "unavailable" }
    let status = authorizationStatus()
    if status == .approved { return "authorized" }
    if status == .denied { return "denied" }
    if status == .notDetermined { return "notDetermined" }
    // Unknown or stronger future authorization modes are not assumed valid.
    return "unavailable"
  }

  private func snapshot(denied: Bool = false) -> [String: Any] {
    if let coordinator { return coordinator.snapshot(denied: denied).metadata }
    let status = denied ? "denied" : authorization
    // Startup can report notDetermined before the system restores approval.
    // Only an explicit denial invalidates otherwise valid persisted tokens.
    if status == "denied" { store.clear() }
    let savedSelection = store.load()
    let selection = status == "authorized" ? savedSelection : nil
    let count = selection?.applicationTokens.count ?? 0
    let selectionUsable = selection != nil && (1...50).contains(count)
    let restriction = restrictions?.reconcile(authorization: status) ?? RestrictionSnapshot(state: .unlocked)
    var state: [String: Any] = [
      "available": available,
      "authorization": status,
      "hasSavedSelection": selection != nil,
      "applicationCount": count,
      "selectionUsable": selectionUsable,
      "restrictionMode": restrictions == nil ? "prototype" : "native",
      "lockdownState": restriction.state.rawValue,
    ]
    if let message = restriction.message { state["restrictionMessage"] = message }
    return state
  }

  private func authorizationChanged(denied: Bool = false) {
    let state = snapshot(denied: denied)
    if state["authorization"] as? String != "authorized", pickerResult != nil {
      finishPicker(FlutterError(
        code: "authorization_revoked",
        message: "Screen Time access is no longer authorized. Authorize again and reselect your allowed apps.",
        details: nil
      ))
    }
    channel.invokeMethod("setupChanged", arguments: state)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getSetupState": result(snapshot())
    case "requestAuthorization": requestAuthorization(result)
    case "selectAllowedApps": presentPicker(result)
    case "enableLockdown", "disableLockdown", "toggleLockdown", "isLockdownEnabled":
      handleRestriction(call.method, result: result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func handleRestriction(_ method: String, result: @escaping FlutterResult) {
    guard let restrictions else {
      result(FlutterError(code: "unavailable", message: "Real app restrictions require a supported physical iPhone.", details: nil))
      return
    }
    defer { channel.invokeMethod("setupChanged", arguments: snapshot()) }
    do {
      let state = snapshot()["lockdownState"] as? String
      switch method {
      case "isLockdownEnabled":
        guard state == "locked" || state == "unlocked" else {
          throw RestrictionFailure(code: "restriction_state_unknown", message: "Restriction state is unresolved. You can still unlock.")
        }
        result(state == "locked")
        return
      case "disableLockdown": try restrictions.disable()
      case "toggleLockdown" where state != "unlocked": try restrictions.disable()
      default:
        guard !requestingAuthorization, pickerResult == nil else {
          throw RestrictionFailure(code: "busy", message: "Finish the current Screen Time setup action before locking in.")
        }
        guard available else {
          throw RestrictionFailure(code: "unavailable", message: "Screen Time restrictions are unavailable on this device.")
        }
        try restrictions.enable(authorization: authorization)
      }
      result(snapshot())
    } catch let failure as RestrictionFailure {
      result(FlutterError(code: failure.code, message: failure.message, details: nil))
    } catch {
      result(FlutterError(code: "restriction_failed", message: "Could not confirm Unbound’s restrictions. Try UNLOCK to clear them.", details: nil))
    }
  }

  private func requestAuthorization(_ result: @escaping FlutterResult) {
    guard available else {
      result(FlutterError(code: "unavailable", message: "Screen Time setup requires a provisioned physical iPhone. You can continue in prototype mode.", details: nil))
      return
    }
    guard !requestingAuthorization, pickerResult == nil else {
      result(FlutterError(code: "busy", message: "Finish the current Screen Time setup action first.", details: nil))
      return
    }
    // Clear a denied/invalid selection, retaining valid data while status is unresolved.
    _ = snapshot()
    do { setupLease = try coordinator?.beginSetup(requireUnlocked: false) }
    catch { result(setupError(error)); return }
    requestingAuthorization = true
    Task { @MainActor in
      defer { requestingAuthorization = false; setupLease = nil }
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        authorizationChanged()
        result(nil)
      } catch {
        authorizationChanged()
        if let familyError = error as? FamilyControlsError,
           familyError == .authorizationCanceled {
          result(FlutterError(code: "authorization_cancelled", message: "Authorization was cancelled. Authorize Screen Time before locking in.", details: nil))
        } else if authorization == "denied" {
          result(FlutterError(code: "authorization_denied", message: "Screen Time access was denied. Authorize Screen Time before locking in.", details: nil))
        } else {
          result(FlutterError(code: "authorization_failed", message: "Screen Time authorization failed: \(error.localizedDescription) Check Family Controls capability and development provisioning in Xcode.", details: nil))
        }
      }
    }
  }

  private func presentPicker(_ result: @escaping FlutterResult) {
    let state = snapshot()
    guard available else { result("unavailable"); return }
    guard state["lockdownState"] as? String == "unlocked" else {
      result(FlutterError(code: "unlock_required", message: "Unlock Unbound before changing your allowed apps.", details: nil))
      return
    }
    guard authorization == "authorized" else {
      result(FlutterError(code: "authorization_required", message: "Authorize Screen Time before choosing allowed apps.", details: nil))
      return
    }
    guard !requestingAuthorization, pickerResult == nil,
          let parent = presenter(), parent.presentedViewController == nil else {
      result(FlutterError(code: "busy", message: "Close the current sheet and try choosing apps again.", details: nil))
      return
    }
    let initialSelection: FamilyActivitySelection
    do {
      setupLease = try coordinator?.beginSetup(requireUnlocked: true)
      initialSelection = try coordinator?.loadSelection() ?? store.load() ?? FamilyActivitySelection()
    } catch { setupLease = nil; result(setupError(error)); return }
    let picker = AllowedAppsPicker(
      selection: initialSelection,
      save: { [weak self] selection in
        guard let self, self.pickerResult != nil else { return }
        guard self.authorization == "authorized" else {
          self.authorizationChanged()
          return
        }
        // Validation throws into the visible picker message; nothing is saved.
        if let coordinator = self.coordinator { try coordinator.saveSelection(selection) }
        else { try self.store.save(selection) }
        self.channel.invokeMethod("setupChanged", arguments: self.snapshot())
        self.finishPicker("selected")
      },
      cancel: { [weak self] in self?.finishPicker("cancelled") }
    )
    let host = UIHostingController(rootView: picker)
    host.modalPresentationStyle = .pageSheet
    pickerResult = result
    pickerController = host
    parent.present(host, animated: true)
    host.presentationController?.delegate = self
  }

  private func finishPicker(_ value: Any?) {
    guard let result = pickerResult else { return }
    let host = pickerController
    pickerResult = nil
    pickerController = nil
    setupLease = nil
    if let host, host.presentingViewController != nil {
      host.dismiss(animated: true) { result(value) }
    } else {
      result(value)
    }
  }

  private func setupError(_ error: Error) -> FlutterError {
    let failure = error as? RestrictionFailure
    return FlutterError(code: failure?.code ?? "shared_storage_unavailable",
      message: failure?.message ?? "Could not access Unbound’s shared state. Please try again.", details: nil)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    finishPicker("cancelled")
  }
}
