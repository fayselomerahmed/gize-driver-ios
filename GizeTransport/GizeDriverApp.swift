import SwiftUI
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    private let gcmMessageIDKey = "gcm.message_id"
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var fcmToken: String?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AppLogger.info("Driver app launched.")
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        UNUserNotificationCenter.current().delegate = self
        setupFirebaseMessaging()
        requestNotificationPermission(application)
        setupNotificationObservers()
        observeAuthenticationState()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        setDriverActiveStatus(false)
        removeDriverLocation()
    }

    @objc private func applicationDidEnterBackground() {
        AppLogger.info("Driver app entered background.")
        startBackgroundTask()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        AppLogger.info("Driver app will enter foreground.")
        endBackgroundTask()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    private func setupFirebaseMessaging() {
        Messaging.messaging().delegate = self
    }

    private func requestNotificationPermission(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                AppLogger.error("Notification permission error: \(error.localizedDescription)")
                return
            }

            guard granted else {
                AppLogger.warning("Notification permission denied.")
                return
            }

            #if targetEnvironment(simulator)
            AppLogger.info("Skipping APNs registration on Simulator.")
            #else
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
            #endif
        }
    }

    private func observeAuthenticationState() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }

            if user != nil {
                AppLogger.info("Driver signed in.")
                self.uploadStoredFCMToken()
                self.setDriverActiveStatus(true)
            } else {
                AppLogger.info("Driver signed out.")
            }
        }
    }

    private func setDriverActiveStatus(_ isActive: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else {
            AppLogger.warning("No authenticated driver for active-status update.")
            return
        }

        Firestore.firestore().collection("users").document(uid).updateData(["isActive": isActive]) { error in
            if let error = error {
                AppLogger.error("Active-status update failed: \(error.localizedDescription)")
            } else {
                AppLogger.info("Driver active status updated.")
            }
        }
    }

    private func removeDriverLocation() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        LocationManager.shared.removeDriverLocation(driverUid: uid)
    }

    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "FinishDriverBackgroundTasks") {
            self.endBackgroundTask()
        }

        DispatchQueue.global(qos: .background).async {
            self.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        AppLogger.info("APNs device token registered successfully.")
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppLogger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        AppLogger.info("Firebase registration token refreshed.")
        self.fcmToken = fcmToken
        uploadStoredFCMToken()
    }

    private func uploadStoredFCMToken() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let fcmToken = fcmToken else {
            AppLogger.warning("No FCM token available to upload.")
            return
        }

        Firestore.firestore().collection("users").document(uid).setData(["fcmToken": fcmToken], merge: true) { error in
            if let error = error {
                AppLogger.error("FCM token update failed: \(error.localizedDescription)")
            } else {
                AppLogger.info("FCM token updated in Firestore.")
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        AppLogger.info("Foreground notification received.")
        completionHandler([.alert, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        AppLogger.info("User interacted with notification.")
        completionHandler()
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if userInfo[gcmMessageIDKey] != nil {
            AppLogger.info("Received remote notification message.")
        }
        completionHandler(.newData)
    }
}

@main
struct GizeDriverApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var userService = UserService.shared
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var networkManager = NetworkManager.shared
    @State private var isLoading = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading {
                    LaunchScreenWrapper(isLoading: $isLoading)
                        .environmentObject(networkManager)
                } else if Auth.auth().currentUser == nil {
                    LoginView(viewModel: authViewModel)
                        .environmentObject(networkManager)
                } else {
                    HomeView()
                        .environmentObject(authViewModel)
                        .environmentObject(homeViewModel)
                        .environmentObject(userService)
                        .environmentObject(networkManager)
                }

                NetworkStatusView()
                    .environmentObject(networkManager)
            }
            .onAppear {
                performInitialSetup()
            }
        }
    }

    private func performInitialSetup() {
        DispatchQueue.main.async {
            isLoading = false
        }
    }
}

struct NetworkStatusView: View {
    @EnvironmentObject var networkManager: NetworkManager

    var body: some View {
        if !networkManager.isConnected {
            HStack(spacing: 10) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 15, weight: .bold))

                Text("Connection lost. Some trip updates may be delayed.")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .foregroundColor(Color.theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: GizeUI.compactCorner, style: .continuous)
                    .stroke(Color.theme.warning.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: GizeUI.compactCorner, style: .continuous))
            .shadow(color: GizeUI.softShadow, radius: 12, x: 0, y: 6)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct LaunchScreenWrapper: View {
    @Binding var isLoading: Bool

    var body: some View {
        ZStack {
            if isLoading {
                LoadingView(isLoading: $isLoading)
            }
        }
    }
}
