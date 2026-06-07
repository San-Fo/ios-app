import SwiftUI

/// A blocking gate shown before a verification-restricted feature. Offers a
/// verify action and a demo-friendly skip.
struct VerificationGateView: View {
    let kind: VerificationKind
    let message: String
    var onVerify: () -> Void
    var onSkip: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: Theme.Spacing.xl)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.Palette.red)

                VStack(spacing: Theme.Spacing.sm) {
                    Text(kind.title)
                        .font(.lbiTitle)
                        .inkStyle()
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.lbiBody)
                        .inkSecondaryStyle()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Spacing.lg)

                CardContainer {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("You'll need")
                            .font(.lbiLabel)
                            .inkSecondaryStyle()
                        ForEach(kind.requiredDocuments) { doc in
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(Theme.Palette.red)
                                    .frame(width: 20)
                                Text(doc.label).font(.lbiBody).inkStyle()
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                Spacer(minLength: 0)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.sm) {
                PrimaryButton("Start verification", systemImage: "checkmark.shield.fill", action: onVerify)
                Button("Skip for now (demo)", action: onSkip)
                    .font(.lbiSubtitle)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Palette.paper)
        }
        .background(Theme.Palette.paper)
    }
}

#Preview {
    VerificationGateView(
        kind: .kyb,
        message: "Verify your business before listing it.",
        onVerify: {},
        onSkip: {}
    )
}
