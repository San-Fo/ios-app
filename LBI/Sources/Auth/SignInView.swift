import AuthenticationServices
import SwiftUI

/// The unauthenticated landing screen with Sign in with Apple.
struct SignInView: View {
    @Environment(AuthState.self) private var auth
    private let coordinator = SignInWithAppleCoordinator()

    var body: some View {
        ZStack {
            Theme.Palette.paper.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Spacer()

                VStack(spacing: Theme.Spacing.md) {
                    Rectangle()
                        .fill(Theme.Palette.red)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "storefront.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))

                    Text("San Fo")
                        .font(.lbiHero)
                        .multilineTextAlignment(.center)
                        .inkStyle()

                    Text("Discover, support and help preserve the local shops, eateries and family businesses that make Hong Kong home.")
                        .font(.lbiBody)
                        .multilineTextAlignment(.center)
                        .inkSecondaryStyle()
                        .padding(.horizontal, Theme.Spacing.md)
                }

                Spacer()

                if let message = auth.errorMessage {
                    Text(message)
                        .font(.lbiCaption)
                        .foregroundStyle(Theme.Palette.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await handleSignIn() }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "apple.logo").font(.system(size: 18, weight: .medium))
                        Text("Continue with Apple").font(.lbiSubtitle)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(Theme.Palette.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                }
                .disabled(auth.isWorking)

                Button("Skip for now") {
                    Task { await auth.skipSignIn() }
                }
                .font(.lbiSubtitle)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .disabled(auth.isWorking)
                .padding(.top, Theme.Spacing.xs)

                Text("By continuing you agree to support local businesses responsibly. This is not a trading product.")
                    .font(.lbiLabel)
                    .multilineTextAlignment(.center)
                    .inkSecondaryStyle()
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.md)
            }
            .padding(Theme.Spacing.lg)

            if auth.isWorking {
                Color.black.opacity(0.05).ignoresSafeArea()
                ProgressView().tint(Theme.Palette.red)
            }
        }
    }

    private func handleSignIn() async {
        do {
            let credential = try await coordinator.signIn()
            await auth.signInWithApple(credential)
        } catch SignInWithAppleError.cancelled {
            // ignore
        } catch {
            await auth.signInWithApple(
                AppleCredential(identityToken: "", authorizationCode: nil, fullName: nil, email: nil)
            )
        }
    }
}

#Preview {
    SignInView()
        .environment(AuthState(service: MockAuthService()))
}
