import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TidyPicsDevice") else { return }
    // Infos sur l'appareil dont l'app a besoin, sans dépendance supplémentaire.
    let channel = FlutterMethodChannel(name: "tidypics/device", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "storage":
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [
          .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ])
        // La place des photos n'est pas connue ici : elle est calculée côté Dart.
        result([
          "total": values?.volumeTotalCapacity ?? 0,
          "free": values?.volumeAvailableCapacityForImportantUsage ?? 0,
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
