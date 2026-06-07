import SwiftUI

/// Guided support/investment flow: amount → type → risk → confirm → done.
struct InvestFlowView: View {
    let detail: BusinessDetail

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileStore.self) private var profileStore

    @State private var amountText: String = ""
    @State private var selectedKind: FundingKind = .revenueShare
    @State private var isSubmitting = false
    @State private var confirmation: InvestmentRecord?

    /// Funding options the current user may actually choose in this flow.
    /// - Takeover groups are handled by a separate flow, so they're excluded.
    /// - Revenue-share loans are restricted to approved commercial investors;
    ///   public users see the locked notice instead.
    private var availableKinds: [FundingKind] {
        Array(detail.summary.fundingOptions)
            .filter { $0 != .takeoverGroup }
            .filter { kind in
                kind != .revenueShare || (profileStore.profile?.isInstitutionalInvestor ?? false)
            }
            .sorted { $0.rawValue < $1.rawValue }
    }

    private var amount: Decimal? {
        guard let value = Decimal(string: amountText), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Group {
                if let confirmation {
                    confirmationView(confirmation)
                } else {
                    form
                }
            }
            .background(Theme.Palette.paper)
            .navigationTitle(confirmation == nil ? "Support \(detail.summary.name)" : "Thank you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }
        .onAppear {
            if let first = availableKinds.first { selectedKind = first }
        }
    }

    private var form: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if availableKinds.isEmpty {
                        institutionalAccessOnly
                    } else {
                        amountSection
                        if availableKinds.count > 1 { typeSection }
                        riskSection
                        Color.clear.frame(height: 60)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .safeAreaInset(edge: .bottom) {
                if !availableKinds.isEmpty {
                    PrimaryButton("Confirm \(amount.map { Money.hkd($0) } ?? "support")", isLoading: isSubmitting, isEnabled: amount != nil) {
                        Task { await submit() }
                    }
                    .padding(Theme.Spacing.lg)
                    .background(Theme.Palette.paper)
                }
            }
    }

    private var institutionalAccessOnly: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Label("Approved commercial investors only", systemImage: "lock.shield.fill")
                    .font(.lbiHeadline)
                    .foregroundStyle(Theme.Palette.red)
                Text("This opportunity is structured as a revenue-share loan. For demo purposes, switch your account mode in Profile to approved commercial investor to review terms and submit interest.")
                    .font(.lbiBody)
                    .inkSecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryButton("Close", systemImage: "xmark") { dismiss() }
            }
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Choose your contribution")
            HStack {
                Text("HK$").font(.lbiTitle).inkSecondaryStyle()
                TextField("0", text: $amountText)
                    .font(.lbiHero)
                    .keyboardType(.numberPad)
                    .inkStyle()
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))

            HStack(spacing: 8) {
                ForEach([1000, 5000, 10000, 25000], id: \.self) { preset in
                    Button {
                        amountText = String(preset)
                    } label: {
                        Text(Money.hkd(Decimal(preset), abbreviated: true))
                            .font(.lbiCaption)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 8)
                    .foregroundStyle(Theme.Palette.ink)
                    .background(Theme.Palette.paperDeep)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous))
                }
            }
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "How you'd like to help")
            ForEach(availableKinds) { kind in
                Button { selectedKind = kind } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: kind.systemImage)
                            .foregroundStyle(Theme.Palette.red).frame(width: 24)
                        Text(kind.displayName).font(.lbiSubtitle).inkStyle()
                        Spacer()
                        Image(systemName: selectedKind == kind ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedKind == kind ? Theme.Palette.red : Theme.Palette.inkSecondary.opacity(0.4))
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(selectedKind == kind ? Theme.Palette.red : Theme.Palette.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var riskSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label(selectedKind == .revenueShare ? "Commercial investor loan note" : "Good to know", systemImage: selectedKind == .revenueShare ? "building.columns.fill" : "heart.text.square.fill")
                    .font(.lbiSubtitle).foregroundStyle(Theme.Palette.red)
                Text(selectedKind == .revenueShare ? "Revenue-share loans are available only to approved commercial investors. Terms remain subject to diligence, documents, and final approval." : "This is community support, not a financial product. Contribute because you want to help keep this place alive — and enjoy the supporter perks the owner offers along the way.")
                    .font(.lbiBody).inkSecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func confirmationView(_ record: InvestmentRecord) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64)).foregroundStyle(Theme.Palette.jade)
            Text("You're helping keep\n\(record.businessName) alive.")
                .font(.lbiTitle).inkStyle().multilineTextAlignment(.center)
            Text("\(Money.hkd(record.amount)) · \(record.kind.displayName)")
                .font(.lbiSubtitle).foregroundStyle(Theme.Palette.red)
            Text("We'll be in touch with the next steps. Thank you for being part of your neighbourhood's story.")
                .font(.lbiBody).inkSecondaryStyle().multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
            Spacer()
            PrimaryButton("Done") { dismiss() }.padding(Theme.Spacing.lg)
        }
    }

    private func submit() async {
        guard let amount else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let record = try await environment.listingRepository.recordInvestment(
                businessId: detail.id,
                businessName: detail.summary.name,
                kind: selectedKind,
                amount: amount
            )
            await profileStore.update { $0.investments.append(record) }
            Haptics.notify(.success)
            confirmation = record
        } catch {
            // Keep the form; a production build would surface an inline error.
        }
    }
}

#Preview {
    InvestFlowView(detail: SampleData.wongNoodleShop)
        .environment(AppEnvironment.preview)
        .environment(previewProfileStore())
}
