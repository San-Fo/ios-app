import AuthenticationServices
import Foundation

/// The credential extracted from a successful Sign in with Apple flow.
struct AppleCredential {
    let identityToken: String
    let authorizationCode: String?
    let fullName: String?
    let email: String?
}

enum SignInWithAppleError: Error {
    /// Apple returned no identity token (cannot authenticate with the backend).
    case missingIdentityToken
    /// The user dismissed the system Apple sheet.
    case cancelled
    /// Any other failure, with a description for logging.
    case failed(String)
}

/// Drives the native Sign in with Apple flow and returns the resulting
/// credential, which is then exchanged for a backend session token.
///
/// Bridges the delegate-based `AuthenticationServices` API to async/await using
/// a `CheckedContinuation`: `signIn()` suspends until a delegate callback fires.
@MainActor
final class SignInWithAppleCoordinator: NSObject {
    /// Resumes the awaiting `signIn()` call from the delegate callbacks.
    private var continuation: CheckedContinuation<AppleCredential, Error>?

    /// Presents the system Apple sheet and resolves with the credential.
    func signIn() async throws -> AppleCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension SignInWithAppleCoordinator: ASAuthorizationControllerDelegate {
    /// Success path: extract the identity token, auth code, name and email and
    /// resume the continuation with an `AppleCredential`.
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { continuation = nil }
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: SignInWithAppleError.missingIdentityToken)
            return
        }

        let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let name = credential.fullName.flatMap { components -> String? in
            let formatter = PersonNameComponentsFormatter()
            let value = formatter.string(from: components)
            return value.isEmpty ? nil : value
        }

        let result = AppleCredential(
            identityToken: identityToken,
            authorizationCode: authCode,
            fullName: name,
            email: credential.email
        )
        continuation?.resume(returning: result)
    }

    /// Failure path: map user cancellation to `.cancelled`, everything else to
    /// `.failed`, and resume the continuation by throwing.
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        defer { continuation = nil }
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: SignInWithAppleError.cancelled)
        } else {
            continuation?.resume(throwing: SignInWithAppleError.failed(error.localizedDescription))
        }
    }
}

extension SignInWithAppleCoordinator: ASAuthorizationControllerPresentationContextProviding {
    /// Tells the system which window to present the Apple sheet over.
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first

        // Prefer the existing key window; otherwise build one from an available
        // window scene. Sign in with Apple is only presented while a foreground
        // window scene exists, so one of these branches always succeeds.
        if let keyWindow = activeScene?.keyWindow {
            return keyWindow
        }
        guard let scene = activeScene else {
            preconditionFailure("Sign in with Apple presented without an active window scene")
        }
        return UIWindow(windowScene: scene)
    }
}
