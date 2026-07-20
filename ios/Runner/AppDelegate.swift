import Flutter
import UIKit
// Uncomment these lines when google_maps_flutter is added to pubspec.yaml
// import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Uncomment this line when google_maps_flutter is added to pubspec.yaml
    // GMSServices.provideAPIKey("AIzaSyAXjzGoUZVyISPLug4ZeovvBPr6vAJSxWw")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
