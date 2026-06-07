import SwiftUI

/// The main authenticated app shell: Discover, Saved, Profile + a dedicated
/// iOS 26 search tab (`Tab(role: .search)`), which the system surfaces with the
/// floating search field treatment.
struct MainTabView: View {
    @Environment(ProfileStore.self) private var profileStore

    var body: some View {
        if profileStore.profile?.isOwner == true {
            ownerTabs
        } else if profileStore.profile?.isInstitutionalInvestor == true {
            investorTabs
        } else {
            publicTabs
        }
    }

    private var publicTabs: some View {
        TabView {
            Tab("Discover", systemImage: "sparkles") { DiscoverView() }
            Tab("Saved", systemImage: "bookmark.fill") { SavedView() }
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

            Tab("Account", systemImage: "building.columns.fill") {
                ProfileView()
            }

            Tab(role: .search) {
                InvestorSearchView()
            }
        }
        .tint(Theme.Palette.red)
    }

    private var ownerTabs: some View {
        TabView {
            Tab("Dashboard", systemImage: "storefront.fill") {
                OwnerDashboardView()
            }

            Tab("Submit", systemImage: "square.and.pencil") {
                ListingFlowView()
            }

            Tab("Account", systemImage: "person.crop.rectangle.fill") {
                ProfileView()
            }

            Tab(role: .search) {
                SearchView()
            }
        }
        .tint(Theme.Palette.red)
    }
}

#Preview {
    MainTabView()
        .environment(AppEnvironment.preview)
        .environment(ProfileStore(repository: MockProfileRepository()))
}
