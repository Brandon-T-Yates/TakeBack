import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var familyControlsBridge: FamilyControlsBridge?

  // Resolve the presenter when the picker is requested, not during app launch.
  private var pickerPresenter: UIViewController? { window?.rootViewController }
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "TakeBackFamilyControls") {
      familyControlsBridge = FamilyControlsBridge(messenger: registrar.messenger()) { [weak self] in
        self?.pickerPresenter
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
