import SwiftUI

/// The main authenticated app shell: Discover, Saved, Profile + a dedicated
/// iOS 26 search tab (`Tab(role: .search)`), which the system surfaces with the
/// floating search field treatment.
struct MainTabView: View {
    @Environment(ProfileStore.self) private var profileStore

    /// A normal user who owns at least one business gets an extra "Owner Desk"
    /// tab — they keep the full supporter experience otherwise. Ownership is a
    /// derived state, not a separate account type.
    private var isOwner: Bool { profileStore.ownsBusiness }

    var body: some View {
        if profileStore.profile?.isInstitutionalInvestor == true {
            investorTabs
        } else {
            publicTabs
        }
    }

    private var publicTabs: some View {
        TabView {
            Tab("Discover", systemImage: "sparkles") { DiscoverView() }
            Tab("Saved", systemImage: "bookmark.fill") { SavedView() }
            // Owners (normal users with a listing) get a business desk tab.
            if isOwner {
                Tab("My Business", systemImage: "storefront.fill") { OwnerDashboardView() }
            }
            Tab("Profile", systemImage: "person.fill") { ProfileView() }
            Tab(role: .search) { SearchView() }
        }
        .tint(Theme.Palette.red)
    }

    private var investorTabs: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.line.uptrend.xyaxis") {
                InvestorDashboardView()
            }

            Tab("Deals", systemImage: "briefcase.fill") {
                InvestorOpportunitiesView()
            }

            // STUB (no backend): tokenized marketplace, verified-investor only.
            Tab("Market", systemImage: "bitcoinsign.circle.fill") {
                TokenMarketplaceView()
            }

            // Commercial investors who also own a business keep their desk.
            if isOwner {
                Tab("My Business", systemImage: "storefront.fill") { OwnerDashboardView() }
            }

            Tab("Account", systemImage: "building.columns.fill") {
                ProfileView()
            }

            Tab(role: .search) {
                InvestorSearchView()
            }
        }
        .tint(Theme.Palette.red)
    }
}

#Preview {
    let env = AppEnvironment.preview
    return MainTabView()
        .environment(env)
        .environment(ProfileStore(repository: MockProfileRepository(), businessRepository: MockBusinessRepository()))
        .environment(AuthState(service: env.authService))
}
