import SwiftUI
import UIKit

@MainActor
final class QuickActionCoordinator {
    static let shared = QuickActionCoordinator()

    private weak var appState: AppState?
    private var queuedShortcutType: String?

    private init() {}

    func bind(appState: AppState) {
        self.appState = appState

        if let queuedShortcutType {
            self.queuedShortcutType = nil
            _ = appState.handleShortcut(type: queuedShortcutType)
        }
    }

    @discardableResult
    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        handle(type: shortcutItem.type)
    }

    @discardableResult
    func handle(type: String) -> Bool {
        guard EmergencyQuickAction(rawValue: type) != nil else {
            return false
        }

        guard let appState else {
            queuedShortcutType = type
            return true
        }

        return appState.handleShortcut(type: type)
    }
}

final class RediM8AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = RediM8SceneDelegate.self
        return configuration
    }
}

final class RediM8SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let shortcutItem = connectionOptions.shortcutItem else {
            return
        }

        Task { @MainActor in
            _ = QuickActionCoordinator.shared.handle(shortcutItem)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in
            completionHandler(QuickActionCoordinator.shared.handle(shortcutItem))
        }
    }
}

@main
struct RediM8App: App {
    @UIApplicationDelegateAdaptor(RediM8AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var navigationRouter = NavigationRouter()

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState, router: navigationRouter)
                .preferredColorScheme(.dark)
        }
    }
}
