import SwiftUI

/// A reusable, skippable verification flow for KYC / KYB / pro-investor.
///
/// Document capture is mocked (tap to attach a placeholder reference). On
/// submit, the backend reviews the documents; the mock auto-approves so the
/// demo can proceed. The whole flow can be skipped for demo purposes.
struct VerificationFlowView: View {
    let kind: VerificationKind
    /// Called when the flow finishes. `approved` is true if verification was
    /// submitted/approved, false if the user skipped.
    var onFinish: (_ approved: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileStore.self) private var profileStore

    @State private var documents: [VerificationDocument]
    @State private var isSubmitting = false
    @State private var result: VerificationStatus?

    init(kind: VerificationKind, onFinish: @escaping (_ approved: Bool) -> Void) {
        self.kind = kind
        self.onFinish = onFinish
        _documents = State(initialValue: kind.requiredDocuments)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    resultView(result)
                } else {
                    form
                }
            }
            .background(Theme.Palette.paper)
            .navigationTitle(kind.shortTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
                if result == nil {
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
                    Text("Your documents are reviewed securely. You can skip this for now — some features stay locked until you're verified.")
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
            Text(kind.title).font(.lbiTitle).inkStyle()
            Text(kind.subtitle)
                .font(.lbiBody)
                .inkSecondaryStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func documentRow(_ doc: Binding<VerificationDocument>) -> some View {
        Button {
            // Mock attach: in production this opens a document/photo picker.
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

    private func resultView(_ status: VerificationStatus) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: status.isApproved ? "checkmark.seal.fill" : "clock.fill")
                .font(.system(size: 64))
                .foregroundStyle(status.isApproved ? Theme.Palette.jade : Theme.Palette.gold)
            Text(status.isApproved ? "You're verified" : "Submitted for review")
                .font(.lbiTitle).inkStyle()
            Text(status.isApproved
                ? "Your \(kind.shortTitle) check is approved. The related features are now unlocked."
                : "We'll review your \(kind.shortTitle) documents and update your status shortly.")
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
        let labels = documents.map(\.label)
        // The server reviews the submission and decides both the status and any
        // role grant; the client just applies whatever comes back.
        guard let outcome = try? await environment.verificationRepository.submit(kind: kind, documentLabels: labels) else {
            result = .pending
            return
        }
        await profileStore.applyVerificationOutcome(outcome)
        result = outcome.record.status
    }

    private func skip() {
        // Override skip is still a server decision: it may grant the role while
        // recording the verification as skipped.
        Task {
            if let outcome = try? await environment.verificationRepository.skipWithOverride(kind: kind) {
                await profileStore.applyVerificationOutcome(outcome)
            }
            onFinish(false)
            dismiss()
        }
    }
}

#Preview {
    VerificationFlowView(kind: .kyb) { _ in }
        .environment(AppEnvironment.preview)
        .environment(previewProfileStore())
}
