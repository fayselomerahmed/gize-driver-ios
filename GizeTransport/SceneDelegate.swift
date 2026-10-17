import UIKit
import Firebase

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    var terminationTimer: Timer?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // Set isActive to true when the app is launched.
        setDriverActiveStatus(true)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Cancel any termination tasks since the app is active again.
        endBackgroundTask()
        invalidateTerminationTimer()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // No action needed; isActive remains true.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Start a background task and schedule termination actions.
        startBackgroundTask()
        scheduleTerminationActions()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Cancel any termination tasks since the app is entering foreground.
        endBackgroundTask()
        invalidateTerminationTimer()
    }

    // MARK: - Background Task Management

    private func startBackgroundTask() {
        endBackgroundTask() // End any existing background tasks.
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "DriverStatusUpdate") {
            // This closure is called when the background time is about to expire.
            self.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // MARK: - Termination Actions

    private func scheduleTerminationActions() {
        // Invalidate any existing timer.
        invalidateTerminationTimer()

        // Schedule a timer to set isActive to false and remove location after 30 seconds.
        terminationTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(handleAppTermination), userInfo: nil, repeats: false)
        RunLoop.current.add(terminationTimer!, forMode: .common)
    }

    private func invalidateTerminationTimer() {
        terminationTimer?.invalidate()
        terminationTimer = nil
    }

    @objc private func handleAppTermination() {
        // Set isActive to false and remove driver location.
        setDriverActiveStatus(false)
        removeDriverLocation()
        // End the background task since we're done.
        endBackgroundTask()
    }

    // MARK: - Update Driver Active Status

    private func setDriverActiveStatus(_ isActive: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("SceneDelegate: No authenticated user found. Skipping isActive update.")
            return
        }

        let userRef = Firestore.firestore().collection("users").document(uid)
        userRef.updateData(["isActive": isActive]) { error in
            if let error = error {
                print("SceneDelegate: Error updating isActive status: \(error.localizedDescription)")
            } else {
                print("SceneDelegate: isActive status successfully updated to \(isActive).")
            }
        }
    }

    // MARK: - Remove Driver Location

    private func removeDriverLocation() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("SceneDelegate: No authenticated user found. Skipping driver location removal.")
            return
        }

        // Use LocationService to decouple LocationManager dependency
        LocationService.shared.removeDriverLocation(driverUid: uid) { error in
            if let error = error {
                print("SceneDelegate: Error removing driver location: \(error.localizedDescription)")
            } else {
                AppLogger.info("Driver location removed after going offline.")
            }
        }
    }
}

// MARK: - LocationService

class LocationService {
    static let shared = LocationService()

    func removeDriverLocation(driverUid: String, completion: @escaping (Error?) -> Void) {
        let driversLocationRef = Database.database().reference().child("DriversLocations").child(driverUid)

        driversLocationRef.removeValue { error, _ in
            completion(error)
        }
    }
}
