import SwiftUI

/// Decides what to show based on auth + onboarding state.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthState.self) private var auth
    @State private var profileStore: ProfileStore?

    var body: some View {
        Group {
            switch auth.phase {
            case .loading:
                loadingView
            case .signedOut:
                SignInView()
            case let .signedIn(user):
                signedInView(user: user)
            }
        }
        .task {
            await auth.bootstrap()
        }
    }

    private var loadingView: some View {
        ZStack {
            Theme.Palette.paper.ignoresSafeArea()
            ProgressView().tint(Theme.Palette.red)
        }
    }

    @ViewBuilder
    private func signedInView(user: AuthenticatedUser) -> some View {
        if let store = profileStore {
            content(store: store)
                .environment(store)
        } else {
            loadingView
                .task {
                    let store = ProfileStore(repository: environment.profileRepository)
                    await store.load(for: user)
                    profileStore = store
                }
        }
    }

    @ViewBuilder
    private func content(store: ProfileStore) -> some View {
        if store.profile?.hasCompletedOnboarding == true {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}
