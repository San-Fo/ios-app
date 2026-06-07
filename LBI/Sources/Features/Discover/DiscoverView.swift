import SwiftUI

/// Personalised discovery feed of businesses worth preserving.
struct DiscoverView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileStore.self) private var profileStore

    @State private var recommended: [Business] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header

                    if isLoading {
                        loadingState
                    } else if let errorMessage {
                        errorState(errorMessage)
                    } else {
                        feed
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ListingFlowView()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.Palette.red)
                    }
                }
            }
            .navigationDestination(for: Business.self) { business in
                BusinessDetailView(businessId: business.id)
            }
        }
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(greeting)
                .font(.lbiCaption)
                .inkSecondaryStyle()
            Text("Keep our neighbourhoods alive.")
                .font(.lbiDisplayMedium)
                .inkStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let name = profileStore.profile?.displayName ?? "Friend"
        return "Welcome back, \(name)"
    }

    @ViewBuilder
    private var feed: some View {
        if recommended.isEmpty {
            CardContainer {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Nothing here yet").font(.lbiHeadline).inkStyle()
                    Text("Check back soon for businesses near you.").font(.lbiBody).inkSecondaryStyle()
                }
            }
        } else {
            if let urgent = recommended.first(where: { $0.status.isUrgent }) {
                urgentBanner(urgent)
            }
            SectionHeader(title: "Recommended for you", subtitle: "Sorted by your interests. All public offers remain visible.")
            ForEach(recommended) { business in
                NavigationLink(value: business) {
                    BusinessCard(
                        business: business,
                        isSaved: profileStore.isSaved(business.id),
                        onSaveTapped: { Task { await profileStore.toggleSaved(business.id) } }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func urgentBanner(_ business: Business) -> some View {
        NavigationLink(value: business) {
            HStack(spacing: Theme.Spacing.md) {
                RemoteImage(url: business.heroImageURL, contentMode: .fill)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    TagChip(
                        text: business.daysRemaining.map { "Urgent · \($0) days left" } ?? "Urgent",
                        systemImage: "clock.badge.exclamationmark",
                        style: .red
                    )
                    Text(business.name).font(.lbiSubtitle).inkStyle()
                        .lineLimit(1)
                    Text(business.storyHeadline).font(.lbiCaption).inkSecondaryStyle()
                        .lineLimit(2).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Theme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Palette.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView().tint(Theme.Palette.red)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xxl)
    }

    private func errorState(_ message: String) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Couldn't load").font(.lbiHeadline).inkStyle()
                Text(message).font(.lbiBody).inkSecondaryStyle()
                SecondaryButton("Try again") { Task { await load() } }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            recommended = try await environment.businessRepository.recommended(for: profileStore.profile)
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Something went wrong."
        }
        isLoading = false
    }
}

#Preview {
    DiscoverView()
        .environment(AppEnvironment.preview)
        .environment(previewProfileStore())
}

@MainActor
func previewProfileStore() -> ProfileStore {
    let store = ProfileStore(repository: MockProfileRepository())
    var profile = UserProfile.empty(id: "p", displayName: "Mei", email: nil)
    profile.interests = [.restaurant, .bookstore]
    profile.districts = [.shamShuiPo, .wanChai]
    profile.hasCompletedOnboarding = true
    profile.savedBusinessIds = ["biz-001", "biz-003"]
    profile.joinedGroupIds = ["tg-002"]
    profile.investments = SampleData.sampleInvestments
    store.setProfileForPreview(profile)
    return store
}
