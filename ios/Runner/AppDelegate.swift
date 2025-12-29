import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  private let backgroundService = BackgroundService.shared
  private let loggingService = BackendLoggingService.shared
  private let bleService = BLEService.shared
  private let backgroundServiceChannel = BackgroundServiceChannel()
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase before anything else
    FirebaseApp.configure()
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup Flutter method channel
    if let controller = window?.rootViewController as? FlutterViewController {
      backgroundServiceChannel.setupChannel(with: controller.binaryMessenger)
    }
    
    // Get app version and build number
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // Initialize logging service with version info
    loggingService.initialize(appVersion: appVersion, buildNumber: buildNumber)
    loggingService.logInfo("App launched - v\(appVersion) (\(buildNumber))")
    
    // Start BLE service
    bleService.start()
    
    // Start background service to keep app alive
    backgroundService.start()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
    loggingService.logWarning("App will terminate")
    bleService.stop()
    backgroundService.stop()
    loggingService.stop()
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    loggingService.logAppState("Did Enter Background")
  }
  
  override func applicationWillEnterForeground(_ application: UIApplication) {
    loggingService.logAppState("Will Enter Foreground")
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    loggingService.logAppState("Did Become Active")
  }
  
  override func applicationWillResignActive(_ application: UIApplication) {
    loggingService.logAppState("Will Resign Active")
  }
}
