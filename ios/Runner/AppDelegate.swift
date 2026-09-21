import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var familyControlsBridge: FamilyControlsBridge?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TakeBackFamilyControls") {
      familyControlsBridge = FamilyControlsBridge(messenger: registrar.messenger()) {
        // Resolve the engine's scene presenter when the picker is requested.
        registrar.viewController
      }
    }
  }
}
