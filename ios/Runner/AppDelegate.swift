import Flutter
import UIKit
@main
@objc class AppDelegate: FlutterAppDelegate {
  private let flutterEngine = FlutterEngine(name: "app_engine")
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = flutterViewController
    window.makeKeyAndVisible()
    self.window = window
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
