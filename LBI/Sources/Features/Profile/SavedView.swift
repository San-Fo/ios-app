import SwiftUI

/// The user's saved businesses.
struct SavedView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileStore.self) private var profileStore

    @State private var saved: [Business] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Saved")
                        .font(.lbiDisplayMedium).inkStyle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Theme.Spacing.xs)

                    if isLoading {
                        ProgressView().tint(Theme.Palette.red)
                            .frame(maxWidth: .infinity).padding(.top, Theme.Spacing.xl)
                    } else if saved.isEmpty {
                        emptyState
                    } else {
                        ForEach(saved) { business in
                            NavigationLink(value: business) {
                                BusinessCard(
                                    business: business,
                                    isSaved: profileStore.isSaved(business.id),
                                    onSaveTapped: {
                                        Task {
                                            await profileStore.toggleSaved(business.id)
                                            await load()
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Business.self) { business in
                BusinessDetailView(businessId: business.id)
            }
        }
        .task { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "bookmark")
                .font(.system(size: 36)).foregroundStyle(Theme.Palette.inkSecondary.opacity(0.4))
            Text("No saved businesses yet").font(.lbiHeadline).inkStyle()
            Text("Tap the bookmark on any business to keep it here.")
                .font(.lbiBody).inkSecondaryStyle().multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, Theme.Spacing.xxl)
    }

    private func load() async {
        let ids = profileStore.savedBusinessIds
        guard !ids.isEmpty else {
            saved = []
            isLoading = false
            return
        }
        // Resolve each saved id directly so saved businesses appear even if they
        // aren't in the (paginated/filtered) discovery list.
        var results: [Business] = []
        for id in ids {
            if let detail = try? await environment.businessRepository.detail(id: id) {
                results.append(detail.summary)
            }
        }
        saved = results
        isLoading = false
    }
}

#Preview {
    SavedView()
        .environment(AppEnvironment.preview)
        .environment(previewProfileStore())
}
