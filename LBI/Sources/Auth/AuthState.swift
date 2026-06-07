import Observation
import SwiftUI

/// Observable session state that drives the app's auth gate.
///
/// `RootView` switches between loading, the sign-in screen, and the main app
/// based on `phase`. UI actions (sign in / out / skip) mutate this state.
@MainActor
@Observable
final class AuthState {
    /// The three mutually-exclusive states of the session.
    enum Phase: Equatable {
        /// Restoring a saved session at launch.
        case loading
        /// No valid session; show the sign-in screen.
        case signedOut
        /// Authenticated (real Apple user or a skipped-in guest).
        case signedIn(AuthenticatedUser)
    }

    /// Current session phase, observed by `RootView`.
    private(set) var phase: Phase = .loading
    /// True while a sign-in request is in flight (drives spinners/disabled UI).
    private(set) var isWorking = false
    /// User-facing error message for the last failed sign-in attempt.
    var errorMessage: String?

    private let service: AuthService

    init(service: AuthService) {
        self.service = service
    }

    /// Convenience accessor for the signed-in user, if any.
    var currentUser: AuthenticatedUser? {
        if case let .signedIn(user) = phase { return user }
        return nil
    }

    /// Called at launch to restore any existing session.
    func bootstrap() async {
        do {
            if let user = try await service.restoreSession() {
                phase = .signedIn(user)
            } else {
                phase = .signedOut
            }
        } catch {
            phase = .signedOut
        }
    }

    /// Exchanges an Apple credential for a session. Distinguishes user
    /// cancellation (silent) from real failures (surfaced via `errorMessage`).
    func signInWithApple(_ credential: AppleCredential) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let user = try await service.signInWithApple(credential)
            phase = .signedIn(user)
        } catch SignInWithAppleError.cancelled {
            // User cancelled — no error surfaced.
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Sign in failed. Please try again."
        }
    }

    /// Clears the session and returns to the signed-out gate.
    func signOut() async {
        await service.signOut()
        phase = .signedOut
    }

    /// Bypass authentication and continue as a local guest user.
    func skipSignIn() {
        errorMessage = nil
        phase = .signedIn(
            AuthenticatedUser(id: "guest-user", displayName: "Guest", email: nil)
        )
    }
}
