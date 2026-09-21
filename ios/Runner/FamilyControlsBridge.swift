import Combine
import FamilyControls
import Flutter
import SwiftUI
import UIKit

/// Native responsibilities only: authorization, picker presentation and tokens.
@MainActor
final class FamilyControlsBridge: NSObject, UIAdaptivePresentationControllerDelegate {
  private let channel: FlutterMethodChannel
  private let presenter: () -> UIViewController?
  private let store = AllowedAppsStore()
  private var authorizationObserver: AnyCancellable?
  private var foregroundObserver: AnyCancellable?
  private var pickerController: UIViewController?
  private var pickerResult: FlutterResult?
  private var requestingAuthorization = false

  init(messenger: FlutterBinaryMessenger, presenter: @escaping () -> UIViewController?) {
    self.channel = FlutterMethodChannel(name: "takeback/family_controls", binaryMessenger: messenger)
    self.presenter = presenter
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      self.handle(call, result: result)
    }
    #if !targetEnvironment(simulator)
    authorizationObserver = AuthorizationCenter.shared.$authorizationStatus
      .removeDuplicates()
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.authorizationChanged() }
    #endif
    foregroundObserver = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.authorizationChanged() }
  }

  private var available: Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    return true
    #endif
  }

  private var authorization: String {
    guard available else { return "unavailable" }
    let status = AuthorizationCenter.shared.authorizationStatus
    if status == .approved { return "authorized" }
    if status == .denied { return "denied" }
    if status == .notDetermined { return "notDetermined" }
    // Unknown or stronger future authorization modes are not assumed valid.
    return "unavailable"
  }

  private func snapshot() -> [String: Any] {
    let status = authorization
    if status != "authorized" { store.clear() }
    let selection = status == "authorized" ? store.load() : nil
    return [
      "available": available,
      "authorization": status,
      "hasSavedSelection": selection != nil,
      "applicationCount": selection?.applicationTokens.count ?? 0,
      "selectionUsable": status == "authorized" && selection != nil,
    ]
  }

  private func authorizationChanged() {
    let state = snapshot()
    if authorization != "authorized", pickerResult != nil {
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
    default: result(FlutterMethodNotImplemented)
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
    // Clear anything left by a previously revoked authorization before reauthorizing.
    _ = snapshot()
    requestingAuthorization = true
    Task { @MainActor in
      defer { requestingAuthorization = false }
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        authorizationChanged()
        result(nil)
      } catch {
        authorizationChanged()
        if let familyError = error as? FamilyControlsError,
           familyError == .authorizationCanceled {
          result(FlutterError(code: "authorization_cancelled", message: "Authorization was cancelled. Try again or continue in prototype mode.", details: nil))
        } else if authorization == "denied" {
          result(FlutterError(code: "authorization_denied", message: "Screen Time access was denied. You can retry authorization or continue in prototype mode.", details: nil))
        } else {
          result(FlutterError(code: "authorization_failed", message: "Screen Time authorization failed: \(error.localizedDescription) Check Family Controls capability and development provisioning in Xcode.", details: nil))
        }
      }
    }
  }

  private func presentPicker(_ result: @escaping FlutterResult) {
    _ = snapshot()
    guard available else { result("unavailable"); return }
    guard authorization == "authorized" else {
      result(FlutterError(code: "authorization_required", message: "Authorize Screen Time before choosing allowed apps.", details: nil))
      return
    }
    guard !requestingAuthorization, pickerResult == nil,
          let parent = presenter(), parent.presentedViewController == nil else {
      result(FlutterError(code: "busy", message: "Close the current sheet and try choosing apps again.", details: nil))
      return
    }
    let picker = AllowedAppsPicker(
      selection: store.load() ?? FamilyActivitySelection(),
      save: { [weak self] selection in
        guard let self, self.pickerResult != nil else { return }
        guard self.authorization == "authorized" else {
          self.authorizationChanged()
          return
        }
        // Validation throws into the visible picker message; nothing is saved.
        try self.store.save(selection)
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
    if let host, host.presentingViewController != nil {
      host.dismiss(animated: true) { result(value) }
    } else {
      result(value)
    }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    finishPicker("cancelled")
  }
}
