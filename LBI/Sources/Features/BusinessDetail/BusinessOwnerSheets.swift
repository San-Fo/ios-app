import SwiftUI

/// Lets the owner edit only non-critical business info (the description).
///
/// Critical fields — name, category, district, financial intent, sale terms —
/// are intentionally not editable here to preserve listing integrity.
struct EditBusinessSheet: View {
    let businessId: String
    let currentDescription: String
    /// Returns the updated business detail so the page can refresh.
    var onSaved: (BusinessDetail) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment

    @State private var description: String
    @State private var isSaving = false

    init(businessId: String, currentDescription: String, onSaved: @escaping (BusinessDetail) -> Void) {
        self.businessId = businessId
        self.currentDescription = currentDescription
        self.onSaved = onSaved
        _description = State(initialValue: currentDescription)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    SectionHeader(title: "Edit your business", subtitle: "You can update the description. Core details stay fixed.")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description").font(.lbiLabel).inkSecondaryStyle()
                        TextEditor(text: $description)
                            .font(.lbiBody)
                            .frame(minHeight: 160)
                            .padding(Theme.Spacing.sm)
                            .scrollContentBackground(.hidden)
                            .background(Theme.Palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
                    }

                    CardContainer {
                        Text("To change the name, category, location, or sale terms, contact support — these affect verification and active deals.")
                            .font(.lbiCaption).inkSecondaryStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .navigationTitle("Edit Business")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton("Save changes", isLoading: isSaving, isEnabled: canSave) {
                    Task { await save() }
                }
                .padding(Theme.Spacing.lg)
                .background(Theme.Palette.paper)
            }
        }
    }

    private var canSave: Bool {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != currentDescription
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        if let updated = try? await environment.businessRepository.updateBusiness(
            id: businessId,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        ) {
            onSaved(updated)
            dismiss()
        }
    }
}

/// Lets any signed-in user add a community memory under a business page.
struct AddMemorySheet: View {
    let businessId: String
    let businessName: String
    var onAdded: (CommunityMemory) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileStore.self) private var profileStore

    @State private var text = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    SectionHeader(title: "Share a memory", subtitle: "What does \(businessName) mean to you?")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your memory").font(.lbiLabel).inkSecondaryStyle()
                        TextEditor(text: $text)
                            .font(.lbiBody)
                            .frame(minHeight: 140)
                            .padding(Theme.Spacing.sm)
                            .scrollContentBackground(.hidden)
                            .background(Theme.Palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .navigationTitle("Add Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton("Post memory", systemImage: "paperplane.fill", isLoading: isSaving, isEnabled: canPost) {
                    Task { await post() }
                }
                .padding(Theme.Spacing.lg)
                .background(Theme.Palette.paper)
            }
        }
    }

    private var canPost: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func post() async {
        isSaving = true
        defer { isSaving = false }
        let author = profileStore.profile?.displayName ?? "Anonymous"
        if let memory = try? await environment.businessRepository.addMemory(
            businessId: businessId,
            author: author,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
        ) {
            onAdded(memory)
            dismiss()
        }
    }
}
