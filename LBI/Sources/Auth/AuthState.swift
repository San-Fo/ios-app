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

    /// Dev-only sign in for testing against the live backend (needs `DEV_AUTH=1`).
    /// Optionally forces an investor status, e.g. `institutionalVerified`.
    func signInDev(subject: String? = nil, investorStatus: String? = nil, name: String? = nil) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let user = try await service.signInDev(subject: subject, investorStatus: investorStatus, name: name)
            phase = .signedIn(user)
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Dev sign in failed."
        }
    }

    /// Clears the session and returns to the signed-out gate.
    func signOut() async {
        await service.signOut()
        phase = .signedOut
    }

    /// Continue without Apple sign-in.
    ///
    /// In live mode this still needs a real backend session (otherwise every
    /// authenticated call — including `GET /me` — fails and the app can't leave
    /// the loading screen), so it requests a guest session via dev sign-in. If
    /// that's unavailable (mock mode, or backend down) it falls back to a purely
    /// local guest so the app remains usable offline.
    func skipSignIn() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            // Use a stable, per-install subject so each device gets its own
            // isolated guest account (and reuses it across launches) rather than
            // everyone sharing the backend's default dev user.
            let subject = AuthState.guestSubject
            let user = try await service.signInDev(subject: subject, investorStatus: nil, name: "Guest")
            phase = .signedIn(user)
        } catch {
            // No backend session available — continue as a local-only guest.
            phase = .signedIn(AuthenticatedUser(id: "guest-user", displayName: "Guest", email: nil))
        }
    }

    /// A stable guest subject unique to this install, persisted in
    /// `UserDefaults` so the same guest account is reused across app launches.
    private static var guestSubject: String {
        let key = "lbi.guestSubject"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = "guest-\(UUID().uuidString.prefix(12))"
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}
