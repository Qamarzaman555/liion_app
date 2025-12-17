import Foundation
import UIKit
import CoreLocation
import AVFoundation

/// BackgroundService - Keeps the app alive in background
/// This service uses multiple strategies to keep the app running:
/// 1. Location services (most reliable for long-term background execution)
/// 2. Background tasks
/// 3. Silent audio (optional, can be enabled if needed)
class BackgroundService: NSObject {
    
    static let shared = BackgroundService()
    
    private var isRunning = false
    private var locationManager: CLLocationManager?
    private var audioPlayer: AVAudioPlayer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private let logger = BackendLoggingService.shared
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    /// Start the background service
    func start() {
        guard !isRunning else {
            logger.logWarning("BackgroundService already running")
            return
        }
        
        isRunning = true
        logger.logInfo("Starting BackgroundService")
        
        // Start location updates (most reliable for keeping app alive)
        startLocationUpdates()
        
        // Setup background task handling
        setupBackgroundTaskHandling()
        
        // Optional: Uncomment to enable silent audio mode
        // setupSilentAudio()
        
        logger.logInfo("BackgroundService started successfully")
    }
    
    /// Stop the background service
    func stop() {
        guard isRunning else { return }
        
        isRunning = false
        logger.logInfo("Stopping BackgroundService")
        
        stopLocationUpdates()
        stopSilentAudio()
        
        logger.logInfo("BackgroundService stopped")
    }
    
    // MARK: - Location Services Setup
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyKilometer // Low accuracy to save battery
        locationManager?.distanceFilter = 500 // Update every 500 meters
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = false
        locationManager?.showsBackgroundLocationIndicator = true
    }
    
    private func startLocationUpdates() {
        guard let locationManager = locationManager else { return }
        
        let authStatus = CLLocationManager.authorizationStatus()
        
        switch authStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
            logger.logInfo("Requesting location authorization")
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
            logger.logInfo("Location updates started")
        case .denied, .restricted:
            logger.logError("Location access denied or restricted")
        @unknown default:
            logger.logWarning("Unknown location authorization status")
        }
    }
    
    private func stopLocationUpdates() {
        locationManager?.stopUpdatingLocation()
        locationManager?.stopMonitoringSignificantLocationChanges()
        logger.logInfo("Location updates stopped")
    }
    
    // MARK: - Background Task Handling
    
    private func setupBackgroundTaskHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        logger.logAppState("Entered Background")
        startBackgroundTask()
    }
    
    @objc private func appWillEnterForeground() {
        logger.logAppState("Entering Foreground")
        endBackgroundTask()
    }
    
    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task first
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.logger.logWarning("Background task expiring")
            self?.endBackgroundTask()
        }
        
        logger.logBackgroundTask("BackgroundService", status: "Started")
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            logger.logBackgroundTask("BackgroundService", status: "Ended")
        }
    }
    
    // MARK: - Silent Audio (Optional - use with caution)
    
    /// Setup silent audio to keep app alive
    /// WARNING: This method is controversial and may be rejected by App Store review
    /// Only use if absolutely necessary and you have a valid use case
    private func setupSilentAudio() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            // Create a silent audio file or use a very quiet sound
            guard let soundURL = Bundle.main.url(forResource: "silence", withExtension: "mp3") else {
                logger.logWarning("Silent audio file not found")
                return
            }
            
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.01 // Very low volume
            audioPlayer?.play()
            
            logger.logInfo("Silent audio started")
        } catch {
            logger.logError("Failed to setup silent audio: \(error.localizedDescription)")
        }
    }
    
    private func stopSilentAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        logger.logInfo("Silent audio stopped")
    }
    
    // MARK: - Public Status Methods
    
    func isServiceRunning() -> Bool {
        return isRunning
    }
    
    func getServiceStatus() -> [String: Any] {
        return [
            "isRunning": isRunning,
            "locationServicesEnabled": CLLocationManager.locationServicesEnabled(),
            "authorizationStatus": CLLocationManager.authorizationStatus().rawValue,
            "backgroundTimeRemaining": UIApplication.shared.backgroundTimeRemaining
        ]
    }
}

// MARK: - CLLocationManagerDelegate

extension BackgroundService: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        logger.logDebug("Location updated: (\(latitude), \(longitude))")
        
        // Restart background task to extend background time
        if UIApplication.shared.applicationState == .background {
            startBackgroundTask()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.logError("Location manager failed: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        logger.logInfo("Location authorization changed: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            startLocationUpdates()
        case .denied, .restricted:
            logger.logError("Location access denied - background service may not work properly")
        default:
            break
        }
    }
}

