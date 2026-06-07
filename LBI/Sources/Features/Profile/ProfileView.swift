import SwiftUI

/// The user's profile: interests, districts, investments, groups, sign out.
struct ProfileView: View {
    @Environment(AuthState.self) private var auth
    @Environment(ProfileStore.self) private var profileStore
    @Environment(AppEnvironment.self) private var environment

    @State private var activeVerification: VerificationKind?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    profileHeader

                    if let profile = profileStore.profile {
                        accountModeSection(profile)
                        verificationSection(profile)
                        switch profile.role {
                        case .retail:
                            preferencesSection(profile)
                            investmentsSection(profile)
                            groupsSection(profile)
                        case .professional:
                            commercialAccountSection
                        case .owner:
                            ownerAccountSection
                        }
                    }

                    SecondaryButton("Sign out", systemImage: "rectangle.portrait.and.arrow.right") {
                        Task { await auth.signOut() }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activeVerification) { kind in
                VerificationFlowView(kind: kind) { _ in }
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(Theme.Palette.red)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(initials)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(profileStore.profile?.displayName ?? "Friend")
                    .font(.lbiTitle).inkStyle()
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let email = profileStore.profile?.email {
                    Text(email).font(.lbiCaption).inkSecondaryStyle()
                        .lineLimit(1).truncationMode(.middle)
                }
                if let tier = profileStore.profile?.tier {
                    HStack(spacing: 4) {
                        if tier.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Palette.jade)
                        }
                        Text(tier.displayName)
                            .font(.lbiLabel)
                            .foregroundStyle(tier.isVerified ? Theme.Palette.jade : Theme.Palette.red)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var initials: String {
        let name = profileStore.profile?.displayName ?? "?"
        return String(name.prefix(1)).uppercased()
    }

    private func accountModeSection(_ profile: UserProfile) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    Image(systemName: "building.columns.fill")
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Theme.Palette.red)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Demo account mode")
                            .font(.lbiHeadline)
                            .inkStyle()
                        Text("Preview each account experience without changing backend data.")
                            .font(.lbiBody)
                            .inkSecondaryStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Picker("Account mode", selection: roleBinding(profile)) {
                    ForEach(AccountRole.allCases, id: \.self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .pickerStyle(.segmented)

                Text(accountModeDescription(profile.role))
                    .font(.lbiCaption)
                    .inkSecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Local demo preview switch only — lets reviewers preview each account
    /// shell without going through verification. Real, access-granting role
    /// assignment happens server-side via `VerificationRepository` (submit or
    /// override-skip). This binding does not represent a verified grant.
    private func roleBinding(_ profile: UserProfile) -> Binding<AccountRole> {
        Binding(
            get: { profileStore.profile?.role ?? profile.role },
            set: { role in
                Task {
                    await profileStore.update { $0.role = role }
                }
            }
        )
    }

    private func accountModeDescription(_ role: AccountRole) -> String {
        switch role {
        case .retail:
            return "Public supporter view: discover businesses, collect support cards, save favourites, and join takeover groups."
        case .professional:
            return "Commercial investor view: active bids, AI-screened acquisitions, confidential financials, and revenue-share loan searches."
        case .owner:
            return "Owner view: submitted listings, backend AI review, commercial bid decisions, and retail fallback controls."
        }
    }

    private func verificationSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Verification", subtitle: "Unlock listing, financing and investor features")
            verificationRow(profile, kind: .kyc)
            verificationRow(profile, kind: .kyb)
            verificationRow(profile, kind: .proInvestor)

            if profile.isProInvestorVerified && profile.role != .professional {
                // Already verified: re-request the grant from the server, which
                // returns the professional role for the client to apply.
                PrimaryButton("Switch to commercial investor", systemImage: "arrow.up.right.circle.fill") {
                    Task {
                        if let outcome = try? await environment.verificationRepository.skipWithOverride(kind: .proInvestor) {
                            await profileStore.applyVerificationOutcome(outcome)
                        }
                    }
                }
            }
        }
    }

    private func verificationRow(_ profile: UserProfile, kind: VerificationKind) -> some View {
        let status = profile.verificationStatus(kind)
        return CardContainer {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: status.isApproved ? "checkmark.seal.fill" : "checkmark.shield")
                    .foregroundStyle(status.isApproved ? Theme.Palette.jade : Theme.Palette.red)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.shortTitle).font(.lbiSubtitle).inkStyle()
                    Text(status.displayName).font(.lbiCaption).inkSecondaryStyle()
                }
                Spacer()
                if status.needsAction {
                    SecondaryButton(status == .rejected ? "Resubmit" : "Verify") {
                        activeVerification = kind
                    }
                    .fixedSize()
                } else if status == .approved {
                    TagChip(text: "Verified", systemImage: "checkmark", style: .jade)
                } else {
                    TagChip(text: status.displayName, style: .gold)
                }
            }
        }
    }

    private var commercialAccountSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Commercial investor account", subtitle: "Approved buyer tools and private market access")
            let sales = SampleData.professionalSales
            let revenueDeals = SampleData.businesses.filter { $0.revenueShareTerms != nil }
            CardContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    StatPill(label: "Private sales", value: "\(sales.count)", icon: "briefcase.fill")
                    StatPill(label: "Loan deals", value: "\(revenueDeals.count)", icon: "percent")
                    StatPill(label: "Highest ask", value: Money.hkd(sales.map(\.askingPrice).max() ?? 0, abbreviated: true), icon: "tag.fill")
                    StatPill(label: "Open bids", value: "\(sales.flatMap(\.bids).filter { $0.status == .submitted }.count)", icon: "hammer.fill")
                }
            }
        }
    }

    private var ownerAccountSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Owner account", subtitle: "Listing submissions and sale decisions")
            let sales = SampleData.professionalSales
            CardContainer {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    StatPill(label: "Submitted", value: "\(sales.count)", icon: "storefront.fill")
                    StatPill(label: "With bids", value: "\(sales.filter { !$0.bids.isEmpty }.count)", icon: "hammer.fill")
                    StatPill(label: "Need decision", value: "\(sales.filter { [.commercialBidding, .ownerDecision].contains($0.stage) && !$0.bids.isEmpty }.count)", icon: "exclamationmark.circle.fill")
                    StatPill(label: "Fallback open", value: "\(sales.filter { $0.stage == .openToRetail }.count)", icon: "person.3.fill")
                }
            }
            CardContainer {
                Text("Use the Owner Desk tab to accept or decline commercial bids and configure retail fallback options.")
                    .font(.lbiBody)
                    .inkSecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func preferencesSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Your interests")
            if profile.interests.isEmpty {
                Text("No interests yet.").font(.lbiBody).inkSecondaryStyle()
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(profile.interests)) { c in
                        TagChip(text: c.displayName, systemImage: c.systemImage)
                    }
                }
            }

            SectionHeader(title: "Your districts")
            FlowLayout(spacing: 8) {
                ForEach(Array(profile.districts)) { d in
                    TagChip(text: d.displayName, style: .outline)
                }
            }

            SectionHeader(title: "How you help")
            FlowLayout(spacing: 8) {
                ForEach(Array(profile.intents)) { i in
                    TagChip(text: i.displayName, systemImage: i.systemImage, style: .neutral)
                }
            }
        }
    }

    private func investmentsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Your support", subtitle: "Businesses you're helping keep alive")
            if profile.investments.isEmpty {
                CardContainer {
                    Text("You haven't supported any businesses yet.")
                        .font(.lbiBody).inkSecondaryStyle()
                }
            } else {
                ForEach(profile.investments) { record in
                    CardContainer {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.businessName).font(.lbiSubtitle).inkStyle()
                                Text(record.kind.displayName).font(.lbiCaption).inkSecondaryStyle()
                            }
                            Spacer()
                            Text(Money.hkd(record.amount)).font(.lbiSubtitle).foregroundStyle(Theme.Palette.red)
                        }
                    }
                }
            }
        }
    }

    private func groupsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Your groups", subtitle: "Takeover groups you've joined")
            if profile.joinedGroupIds.isEmpty {
                CardContainer {
                    Text("You haven't joined any takeover groups yet.")
                        .font(.lbiBody).inkSecondaryStyle()
                }
            } else {
                Text("\(profile.joinedGroupIds.count) group\(profile.joinedGroupIds.count == 1 ? "" : "s") joined")
                    .font(.lbiBody).inkStyle()
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthState(service: MockAuthService()))
        .environment(previewProfileStore())
}
