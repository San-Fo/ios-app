import SwiftUI

/// Per-business KYB verification, locked to a specific listing.
///
/// Unlike the generic `VerificationFlowView`, this is bound to a `businessId`
/// and calls `POST /businesses/{id}/verify`, which marks the listing verified
/// (publishing it) and makes the caller a verified business owner. Skippable
/// for demos — the listing simply stays unverified/private.
struct BusinessVerificationView: View {
    let businessId: String
    let businessName: String
    /// Called when finished. `verified` is true on success, false on skip.
    var onFinish: (_ verified: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileStore.self) private var profileStore

    @State private var documents: [VerificationDocument] = VerificationKind.kyb.requiredDocuments
    @State private var isSubmitting = false
    @State private var verified = false

    var body: some View {
        NavigationStack {
            Group {
                if verified { resultView } else { form }
            }
            .background(Theme.Palette.paper)
            .navigationTitle("Business (KYB)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
                if !verified {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip for now") { skip() }
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    }
                }
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header

                VStack(spacing: Theme.Spacing.sm) {
                    ForEach($documents) { $doc in
                        documentRow($doc)
                    }
                }

                CardContainer {
                    Text("Verifying confirms the business exists and that you own it. Your listing for \(businessName) stays private until this is approved, then it's locked to your verified KYB.")
                        .font(.lbiCaption)
                        .inkSecondaryStyle()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.sm) {
                PrimaryButton("Submit for verification", systemImage: "checkmark.shield.fill", isLoading: isSubmitting, isEnabled: allAttached) {
                    Task { await submit() }
                }
                Button("Skip for now") { skip() }
                    .font(.lbiSubtitle)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Palette.paper)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.Palette.red)
            Text("Verify \(businessName)").font(.lbiTitle).inkStyle()
            Text(VerificationKind.kyb.subtitle)
                .font(.lbiBody)
                .inkSecondaryStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func documentRow(_ doc: Binding<VerificationDocument>) -> some View {
        Button {
            // Mock attach: production opens a document/photo picker.
            doc.wrappedValue.reference = "attached-\(UUID().uuidString.prefix(8))"
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: doc.wrappedValue.isAttached ? "checkmark.circle.fill" : "paperclip")
                    .foregroundStyle(doc.wrappedValue.isAttached ? Theme.Palette.jade : Theme.Palette.red)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.wrappedValue.label).font(.lbiSubtitle).inkStyle()
                    Text(doc.wrappedValue.isAttached ? "Attached" : "Tap to attach")
                        .font(.lbiCaption).inkSecondaryStyle()
                }
                Spacer()
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var resultView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Palette.jade)
            Text("Business verified").font(.lbiTitle).inkStyle()
            Text("\(businessName) is now verified and published. You're a verified business owner.")
                .font(.lbiBody).inkSecondaryStyle()
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
            Spacer()
            PrimaryButton("Done") {
                onFinish(true)
                dismiss()
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var allAttached: Bool { documents.allSatisfy(\.isAttached) }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        // KYB is per-business: verify this specific listing and apply the
        // server-granted outcome (verified status + owner role).
        guard let outcome = try? await environment.verificationRepository.verifyBusiness(businessId: businessId) else {
            return
        }
        await profileStore.applyVerificationOutcome(outcome)
        verified = true
    }

    private func skip() {
        onFinish(false)
        dismiss()
    }
}

#Preview {
    BusinessVerificationView(businessId: "biz-1", businessName: "Wong's Noodles") { _ in }
        .environment(AppEnvironment.preview)
        .environment(previewProfileStore())
}
