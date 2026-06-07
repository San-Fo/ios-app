import SwiftUI

/// Filter sheet for search: categories, districts, funding & availability.
struct SearchFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var query: BusinessQuery
    var onApply: () -> Void

    @State private var draft: BusinessQuery = BusinessQuery()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    section("Category") {
                        FlowLayout(spacing: 10) {
                            ForEach(BusinessCategory.allCases) { c in
                                SelectableChip(title: c.displayName, systemImage: c.systemImage, isSelected: draft.categories.contains(c)) {
                                    toggle(c, in: &draft.categories)
                                }
                            }
                        }
                    }
                    section("District") {
                        FlowLayout(spacing: 10) {
                            ForEach(District.allCases) { d in
                                SelectableChip(title: d.displayName, isSelected: draft.districts.contains(d)) {
                                    toggle(d, in: &draft.districts)
                                }
                            }
                        }
                    }
                    section("Availability") {
                        FlowLayout(spacing: 10) {
                            ForEach(FundingKind.allCases) { f in
                                SelectableChip(title: f.displayName, systemImage: f.systemImage, isSelected: draft.fundingKinds.contains(f)) {
                                    toggle(f, in: &draft.fundingKinds)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        draft.categories = []; draft.districts = []; draft.fundingKinds = []
                    }
                    .foregroundStyle(Theme.Palette.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton("Show results") {
                    query.categories = draft.categories
                    query.districts = draft.districts
                    query.fundingKinds = draft.fundingKinds
                    onApply()
                    dismiss()
                }
                .padding(Theme.Spacing.lg)
                .background(Theme.Palette.paper)
            }
        }
        .onAppear { draft = query }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title).font(.lbiSubtitle).inkStyle()
            content()
        }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

#Preview {
    SearchFiltersView(query: .constant(BusinessQuery())) {}
}
