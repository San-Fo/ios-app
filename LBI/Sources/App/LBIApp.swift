import SwiftUI

/// App entry point for Huo Ju (project/target name remains "LBI").
///
/// Owns the two long-lived objects and injects them into the SwiftUI
/// environment so every screen can reach them:
/// - `AppEnvironment`: the dependency container (services + repositories).
/// - `AuthState`: the observable sign-in state machine.
@main
struct LBIApp: App {
    /// Dependency container; created once for the whole app lifetime.
    @State private var environment: AppEnvironment
    /// Auth state machine, wired to the environment's auth service.
    @State private var auth: AuthState

    init() {
        // Build the environment first, then hand its auth service to AuthState.
        let env = AppEnvironment()
        _environment = State(initialValue: env)
        _auth = State(initialValue: AuthState(service: env.authService))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Inject shared dependencies for the whole view tree.
                .environment(environment)
                .environment(auth)
                // Global accent colour (cinnabar red) for controls/links.
                .tint(Theme.Palette.red)
        }
    }
}
