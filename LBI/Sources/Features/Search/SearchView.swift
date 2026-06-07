import SwiftUI

/// Search businesses by name, district, category and funding type.
///
/// Uses the iOS search-tab pattern: the search field is provided by the
/// system via `.searchable` on the enclosing navigation stack, and results
/// reuse the same `BusinessCard` component as the Discover feed.
struct SearchView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileStore.self) private var profileStore

    @State private var searchText = ""
    @State private var query = BusinessQuery()
    @State private var results: [Business] = []
    @State private var isLoading = false
    @State private var showFilters = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    activeFilters

                    if isLoading {
                        ProgressView().tint(Theme.Palette.red)
                            .frame(maxWidth: .infinity).padding(.top, Theme.Spacing.xl)
                    } else if results.isEmpty {
                        emptyState
                    } else {
                        Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                            .font(.lbiCaption).inkSecondaryStyle()
                        ForEach(results) { business in
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
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Shops, stories, districts…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: {
                        Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(Theme.Palette.red)
                    }
                }
            }
            .navigationDestination(for: Business.self) { business in
                BusinessDetailView(businessId: business.id)
            }
            .sheet(isPresented: $showFilters) {
                SearchFiltersView(query: $query) { Task { await load() } }
            }
        }
        .task { await load() }
        .onChange(of: searchText) { _, newValue in
            query.text = newValue
            Task { await load() }
        }
    }

    @ViewBuilder
    private var activeFilters: some View {
        if activeFilterCount > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(query.categories), id: \.self) { c in
                        TagChip(text: c.displayName, style: .red)
                    }
                    ForEach(Array(query.districts), id: \.self) { d in
                        TagChip(text: d.displayName, style: .jade)
                    }
                    ForEach(Array(query.fundingKinds), id: \.self) { f in
                        TagChip(text: f.displayName, style: .gold)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36)).foregroundStyle(Theme.Palette.inkSecondary.opacity(0.4))
            Text("No matches").font(.lbiHeadline).inkStyle()
            Text("Try a different search or adjust your filters.")
                .font(.lbiBody).inkSecondaryStyle().multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, Theme.Spacing.xl)
    }

    /// Number of applied filters, used to badge the filter button.
    private var activeFilterCount: Int {
        query.categories.count + query.districts.count + query.fundingKinds.count
    }

    /// Runs the current query against the repository.
    private func load() async {
        // Only show the full-screen spinner on the first load; subsequent
        // searches refine results in place to avoid flicker while typing.
        isLoading = results.isEmpty
        results = (try? await environment.businessRepository.list(query: query)) ?? []
        isLoading = false
    }
}

#Preview {
    SearchView()
        .environment(AppEnvironment.preview)
        .environment(previewProfileStore())
}
