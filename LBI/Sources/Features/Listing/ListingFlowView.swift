import SwiftUI
import PhotosUI

/// Multi-step flow for a business owner to create a listing.
struct ListingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileStore.self) private var profileStore

    @State private var step = 0
    @State private var draft = ListingDraft()
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var newRewardCards = ""
    @State private var newRewardTitle = ""
    /// Photos chosen via the system PhotosPicker (loaded into `draft.photos`).
    @State private var photoSelections: [PhotosPickerItem] = []
    /// The business id returned by the backend after the listing is created.
    /// KYB verification is locked to this specific business.
    @State private var createdBusinessId: String?
    @State private var showBusinessVerification = false
    /// True once KYB for the created business has been verified (or skipped).
    @State private var businessVerified = false

    private let totalSteps = 5

    var body: some View {
        Group {
            if submitted {
                successView
            } else {
                // The listing is created first (status `pending`); business
                // verification (KYB) happens per-business afterwards, from the
                // Owner Desk, because the backend verifies a specific listing.
                VStack(spacing: 0) {
                    progressBar
                    TabView(selection: $step) {
                        basicsStep.tag(0)
                        storyStep.tag(1)
                        financialsStep.tag(2)
                        outcomeStep.tag(3)
                        rewardsStep.tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    footer
                }
            }
        }
        .background(Theme.Palette.paper)
        .navigationTitle("List your business")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBusinessVerification) {
            if let businessId = createdBusinessId {
                BusinessVerificationView(businessId: businessId, businessName: draft.businessName) { verified in
                    businessVerified = verified
                    // Refresh ownership so the "My Business" tab appears.
                    Task { await profileStore.loadMyBusinesses() }
                }
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule().fill(index <= step ? Theme.Palette.red : Theme.Palette.paperDeep).frame(height: 5)
            }
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: Steps

    private var basicsStep: some View {
        StepScaffold(title: "Business basics", subtitle: "Tell us about your business.") {
            VStack(spacing: Theme.Spacing.md) {
                LabeledField(title: "Business name", text: $draft.businessName, placeholder: "e.g. Wing Kee Cha Chaan Teng")
                pickerRow("Category", selection: $draft.category, options: BusinessCategory.allCases) { $0.displayName }
                pickerRow("District", selection: $draft.district, options: District.allCases) { $0.displayName }
                LabeledField(title: "Address", text: $draft.address, placeholder: "e.g. 12 Apliu Street")
                LabeledField(title: "Founded year", text: $draft.foundedYear, placeholder: "1964", keyboard: .numberPad)
                LabeledField(title: "Contact email", text: $draft.contactEmail, placeholder: "you@example.hk", keyboard: .emailAddress)
            }
        }
    }

    private var storyStep: some View {
        StepScaffold(title: "Your story", subtitle: "Help people fall in love with your business.") {
            VStack(spacing: Theme.Spacing.md) {
                LabeledEditor(title: "Founder story", text: $draft.founderStory, placeholder: "How did it begin? Who built it?")
                LabeledEditor(title: "Why it matters", text: $draft.whyItMatters, placeholder: "What would the neighbourhood lose without you?")
                photoPlaceholder
            }
        }
    }

    private var financialsStep: some View {
        StepScaffold(title: "Financial snapshot", subtitle: "These figures are used by the backend AI to assess whether the business should enter commercial-investor bidding first.") {
            VStack(spacing: Theme.Spacing.md) {
                LabeledField(title: "Monthly revenue (HK$)", text: $draft.monthlyRevenue, placeholder: "180000", keyboard: .numberPad)
                LabeledField(title: "Number of employees", text: $draft.employees, placeholder: "6", keyboard: .numberPad)
            }
        }
    }

    private var outcomeStep: some View {
        StepScaffold(title: "Sale path", subtitle: "If you sell the whole business, strong submissions are AI-screened and offered to commercial investors first. If you decline those bids, you can set a public price for retail buyers or a group takeover.") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(ListingOutcome.allCases) { outcome in
                    Button {
                        toggle(outcome)
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: outcome.systemImage).foregroundStyle(Theme.Palette.red).frame(width: 24)
                            Text(outcome.displayName).font(.lbiSubtitle).inkStyle()
                            Spacer()
                            Image(systemName: draft.desiredOutcomes.contains(outcome) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(draft.desiredOutcomes.contains(outcome) ? Theme.Palette.red : Theme.Palette.inkSecondary.opacity(0.4))
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(draft.desiredOutcomes.contains(outcome) ? Theme.Palette.red : Theme.Palette.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                if !draft.desiredOutcomes.isDisjoint(with: ListingOutcome.ownershipOutcomes) {
                    VStack(spacing: Theme.Spacing.md) {
                        LabeledField(title: "Commercial guide price (HK$)", text: $draft.saleAskingPrice, placeholder: "2200000", keyboard: .numberPad)
                        if draft.desiredOutcomes.contains(.sellWhole) {
                            LabeledField(title: "Retail fallback price (HK$)", text: $draft.retailFallbackPrice, placeholder: "2500000", keyboard: .numberPad)
                            Toggle("Allow retail outright purchase", isOn: $draft.allowRetailOutrightPurchase)
                                .font(.lbiBody)
                                .tint(Theme.Palette.red)
                            Toggle("Allow group takeover fallback", isOn: $draft.allowRetailGroupTakeover)
                                .font(.lbiBody)
                                .tint(Theme.Palette.red)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Palette.paperDeep)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var photoPlaceholder: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PhotosPicker(selection: $photoSelections, maxSelectionCount: 8, matching: .images) {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "photo.badge.plus").font(.system(size: 28)).foregroundStyle(Theme.Palette.red)
                    Text(draft.photos.isEmpty ? "Add photos" : "\(draft.photos.count) photo\(draft.photos.count == 1 ? "" : "s") selected")
                        .font(.lbiCaption).inkSecondaryStyle()
                }
                .frame(maxWidth: .infinity).padding(Theme.Spacing.lg)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundStyle(Theme.Palette.hairline))
            }

            // Thumbnails of the selected photos.
            if !draft.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Array(draft.photos.enumerated()), id: \.offset) { _, data in
                            if let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: photoSelections) { _, items in
            Task { await loadPhotos(items) }
        }
    }

    /// Loads the picked photos into the draft as JPEG data.
    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var loaded: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let jpeg = image.jpegData(compressionQuality: 0.8) {
                loaded.append(jpeg)
            }
        }
        draft.photos = loaded
    }

    private var rewardsStep: some View {
        StepScaffold(
            title: "Supporter cards",
            subtitle: "Thank the people who back you. Supporters collect a card each time they donate — set perks they unlock by collecting more. This is optional."
        ) {
            VStack(spacing: Theme.Spacing.md) {
                if !draft.shareRewards.isEmpty {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(draft.shareRewards.sorted()) { reward in
                            HStack(spacing: Theme.Spacing.md) {
                                Text("\(reward.cardsRequired)")
                                    .font(.lbiMono).foregroundStyle(Theme.Palette.gold)
                                    .frame(width: 36)
                                Text(reward.cardsRequired == 1 ? "card" : "cards")
                                    .font(.lbiLabel).inkSecondaryStyle()
                                Text(reward.title).font(.lbiBody).inkStyle()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    draft.shareRewards.removeAll { $0.id == reward.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill").foregroundStyle(Theme.Palette.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
                        }
                    }
                }

                VStack(spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.sm) {
                        LabeledField(title: "Cards", text: $newRewardCards, placeholder: "5", keyboard: .numberPad)
                            .frame(width: 90)
                        LabeledField(title: "Reward", text: $newRewardTitle, placeholder: "e.g. A free coffee each month")
                    }
                    SecondaryButton("Add card tier", systemImage: "plus") { addReward() }
                        .disabled(!canAddReward)
                        .opacity(canAddReward ? 1 : 0.5)
                }
            }
        }
    }

    private var canAddReward: Bool {
        (Int(newRewardCards) ?? 0) > 0 && !newRewardTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func addReward() {
        guard let cards = Int(newRewardCards), cards > 0 else { return }
        let title = newRewardTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        draft.shareRewards.append(ShareReward(cardsRequired: cards, title: title))
        newRewardCards = ""
        newRewardTitle = ""
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.md) {
            if step > 0 {
                SecondaryButton("Back") { withAnimation { step -= 1 } }.frame(width: 110)
            }
            PrimaryButton(step == totalSteps - 1 ? "Submit listing" : "Continue", isLoading: isSubmitting, isEnabled: canAdvance) {
                advance()
            }
        }
        .padding(Theme.Spacing.lg)
    }

    private var successView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: businessVerified ? "checkmark.seal.fill" : "doc.badge.clock")
                .font(.system(size: 64))
                .foregroundStyle(businessVerified ? Theme.Palette.jade : Theme.Palette.gold)

            Text(businessVerified ? "Listing verified" : "Listing created — verify to publish")
                .font(.lbiTitle).inkStyle()
                .multilineTextAlignment(.center)

            if businessVerified {
                Text("Your business is verified and live. The backend AI will evaluate it; strong sale candidates go to commercial investors first, then your retail fallback can open to public buyers or a group takeover.")
                    .font(.lbiBody).inkSecondaryStyle().multilineTextAlignment(.center).padding(.horizontal, Theme.Spacing.lg)
            } else {
                Text("Your listing was created but stays private until you verify the business and your ownership. This locks the listing to a verified KYB.")
                    .font(.lbiBody).inkSecondaryStyle().multilineTextAlignment(.center).padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                if !businessVerified {
                    PrimaryButton("Verify business now", systemImage: "checkmark.shield.fill") {
                        showBusinessVerification = true
                    }
                    SecondaryButton("Verify later") { dismiss() }
                } else {
                    PrimaryButton("Done") { dismiss() }
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: Logic

    private var canAdvance: Bool {
        switch step {
        case 0: return !draft.businessName.isEmpty && !draft.contactEmail.isEmpty
        case 1: return !draft.founderStory.isEmpty
        case 3:
            guard !draft.desiredOutcomes.isEmpty else { return false }
            if draft.desiredOutcomes.contains(.sellWhole) {
                return Decimal(string: draft.saleAskingPrice) != nil && Decimal(string: draft.retailFallbackPrice) != nil
            }
            return true
        default: return true
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation { step += 1 }
        } else {
            Task {
                isSubmitting = true
                defer { isSubmitting = false }
                // Create the listing (pending), capture its id, then prompt KYB
                // so the listing can be locked to a verified business.
                createdBusinessId = try? await environment.listingRepository.submitListing(draft)
                submitted = true
                if createdBusinessId != nil {
                    showBusinessVerification = true
                }
            }
        }
    }

    private func toggle(_ outcome: ListingOutcome) {
        if draft.desiredOutcomes.contains(outcome) { draft.desiredOutcomes.remove(outcome) }
        else { draft.desiredOutcomes.insert(outcome) }
    }

    @ViewBuilder
    private func pickerRow<T: Hashable & Identifiable>(_ title: String, selection: Binding<T>, options: [T], label: @escaping (T) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.lbiLabel).inkSecondaryStyle()
            Menu {
                ForEach(options) { option in
                    Button(label(option)) { selection.wrappedValue = option }
                }
            } label: {
                HStack {
                    Text(label(selection.wrappedValue)).font(.lbiBody).inkStyle()
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).inkSecondaryStyle()
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
            }
        }
    }
}

// MARK: - Field helpers

private struct LabeledField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.lbiLabel).inkSecondaryStyle()
            TextField(placeholder, text: $text)
                .font(.lbiBody).keyboardType(keyboard).autocorrectionDisabled(keyboard == .emailAddress)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                .padding(Theme.Spacing.md)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
        }
    }
}

private struct LabeledEditor: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.lbiLabel).inkSecondaryStyle()
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder).font(.lbiBody).inkSecondaryStyle().padding(Theme.Spacing.md)
                }
                TextEditor(text: $text)
                    .font(.lbiBody).frame(minHeight: 110).padding(Theme.Spacing.sm).scrollContentBackground(.hidden)
            }
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
        }
    }
}

private struct StepScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(title).font(.lbiTitle).inkStyle()
                    Text(subtitle).font(.lbiBody).inkSecondaryStyle()
                }
                content
            }
            .padding(Theme.Spacing.lg)
        }
    }
}

#Preview {
    NavigationStack {
        ListingFlowView()
            .environment(AppEnvironment.preview)
    }
}
