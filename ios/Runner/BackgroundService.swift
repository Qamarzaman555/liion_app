import Foundation
import UIKit
import AVFoundation

/// BackgroundService - Keeps the app alive in background
/// This service uses multiple strategies to keep the app running:
/// 1. Background tasks
/// 2. Silent audio (optional, can be enabled if needed)
class BackgroundService: NSObject {
    
    static let shared = BackgroundService()
    
    private var isRunning = false
    private var audioPlayer: AVAudioPlayer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private let logger = BackendLoggingService.shared
    
    private override init() {
        super.init()
    }
    
    /// Start the background service
    func start() {
        guard !isRunning else {
            logger.logWarning("BackgroundService already running")
            return
        }
        
        isRunning = true
        logger.logInfo("Starting BackgroundService")
        
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
        
        stopSilentAudio()
        endBackgroundTask()
        
        logger.logInfo("BackgroundService stopped")
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
            "backgroundTimeRemaining": UIApplication.shared.backgroundTimeRemaining
        ]
    }
}

