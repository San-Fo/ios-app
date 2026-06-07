import SwiftUI

/// Submit a collective offer on behalf of a takeover group.
struct CollectiveOfferView: View {
    let group: TakeoverGroup

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment

    @State private var amountText = ""
    @State private var isSubmitting = false
    @State private var submitted = false

    private var amount: Decimal? {
        guard let value = Decimal(string: amountText), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted { successView } else { form }
            }
            .background(Theme.Palette.paper)
            .navigationTitle("Collective Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(submitted ? "Done" : "Cancel") { dismiss() }.foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(title: "Offer for \(group.businessName)", subtitle: "On behalf of \(group.memberCount) members")
                HStack {
                    Text("HK$").font(.lbiTitle).inkSecondaryStyle()
                    TextField("0", text: $amountText).font(.lbiHero).keyboardType(.numberPad).inkStyle()
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))

                CardContainer {
                    Text("This offer represents the group's collective intent to acquire and preserve the business. Submitting starts a conversation with the owner — it is not a binding contract.")
                        .font(.lbiBody).inkSecondaryStyle().fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("Submit offer", isLoading: isSubmitting, isEnabled: amount != nil) {
                Task { await submit() }
            }
            .padding(Theme.Spacing.lg).background(Theme.Palette.paper)
        }
    }

    private var successView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(Theme.Palette.jade)
            Text("Offer submitted").font(.lbiTitle).inkStyle()
            Text("The owner of \(group.businessName) will be notified. Your group will be updated here.")
                .font(.lbiBody).inkSecondaryStyle().multilineTextAlignment(.center).padding(.horizontal, Theme.Spacing.lg)
            Spacer()
            PrimaryButton("Done") { dismiss() }.padding(Theme.Spacing.lg)
        }
    }

    private func submit() async {
        guard let amount else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        try? await environment.takeoverRepository.submitCollectiveOffer(groupId: group.id, amount: amount)
        submitted = true
    }
}

#Preview {
    CollectiveOfferView(group: SampleData.takeoverGroups[0])
        .environment(AppEnvironment.preview)
}
