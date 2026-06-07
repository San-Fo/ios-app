import SwiftUI

/// Public buyer intent flow after an owner declines commercial bids and opens a fallback price.
struct RetailPurchaseSheet: View {
    let businessName: String
    let offer: RetailFallbackOffer
    /// Confirms the purchase with the backend and opens a private deal chat.
    /// Returns `true` if a deal conversation was opened.
    var onConfirm: (_ buyerName: String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var message = ""
    @State private var submitted = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Group {
                if submitted { successView } else { form }
            }
            .background(Theme.Palette.paper)
            .navigationTitle("Buy Outright")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(submitted ? "Done" : "Cancel") { dismiss() }
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(title: "Public fallback offer", subtitle: businessName)
                CardContainer {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        StatPill(label: "Owner-set public price", value: Money.hkd(offer.askingPrice, abbreviated: true), icon: "tag.fill")
                        Text("This registers your interest to buy \(businessName) outright at the public fallback price. It is not a binding contract until diligence and documents are completed.")
                            .font(.lbiBody)
                            .inkSecondaryStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                LabeledSheetField(title: "Your name", text: $name, placeholder: "Buyer name")
                LabeledSheetEditor(title: "Message to owner", text: $message, placeholder: "Why are you a good next owner?")
            }
            .padding(Theme.Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("Confirm purchase interest", systemImage: "cart.fill", isLoading: isSubmitting, isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                Task {
                    isSubmitting = true
                    let ok = await onConfirm(name.trimmingCharacters(in: .whitespaces))
                    isSubmitting = false
                    if ok { submitted = true }
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Palette.paper)
        }
    }

    private var successView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            SuccessCheckmark(tint: Theme.Palette.jade)
            Text("Purchase interest sent")
                .font(.lbiTitle)
                .inkStyle()
            Text("The owner will be notified that you want to buy \(businessName) outright at the fallback price.")
                .font(.lbiBody)
                .inkSecondaryStyle()
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
            Spacer()
            PrimaryButton("Done") { dismiss() }.padding(Theme.Spacing.lg)
        }
    }
}

private struct LabeledSheetField: View {
    let title: String
    @Binding var text: String
    var placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.lbiLabel).inkSecondaryStyle()
            TextField(placeholder, text: $text)
                .font(.lbiBody)
                .padding(Theme.Spacing.md)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
        }
    }
}

private struct LabeledSheetEditor: View {
    let title: String
    @Binding var text: String
    var placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.lbiLabel).inkSecondaryStyle()
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder).font(.lbiBody).inkSecondaryStyle().padding(Theme.Spacing.md)
                }
                TextEditor(text: $text)
                    .font(.lbiBody)
                    .frame(minHeight: 110)
                    .padding(Theme.Spacing.sm)
                    .scrollContentBackground(.hidden)
            }
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
        }
    }
}
