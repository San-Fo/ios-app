import SwiftUI

/// The user's saved businesses.
struct SavedView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileStore.self) private var profileStore

    @State private var all: [Business] = []
    @State private var isLoading = true

    private var saved: [Business] {
        let ids = profileStore.profile?.savedBusinessIds ?? []
        return all.filter { ids.contains($0.id) }
    }

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
                                    isSaved: true,
                                    onSaveTapped: { Task { await profileStore.toggleSaved(business.id) } }
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
        all = (try? await environment.businessRepository.list(query: BusinessQuery())) ?? []
        isLoading = false
    }
}

#Preview {
    SavedView()
        .environment(AppEnvironment.preview)
        .environment(previewProfileStore())
}
