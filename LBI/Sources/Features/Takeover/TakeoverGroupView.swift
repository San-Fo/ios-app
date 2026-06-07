import SwiftUI

/// Takeover group page: overview, members, channels, collective offer, Q&A.
struct TakeoverGroupView: View {
    let businessId: String
    let businessName: String

    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileStore.self) private var profileStore

    @State private var group: TakeoverGroup?
    @State private var isLoading = true
    @State private var showOffer = false
    @State private var hasJoined = false

    var body: some View {
        Group {
            if let group {
                content(group)
            } else if isLoading {
                ProgressView().tint(Theme.Palette.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        }
        .background(Theme.Palette.paper)
        .navigationTitle("Takeover Group")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showOffer) {
            if let group { CollectiveOfferView(group: group) }
        }
    }

    private func content(_ group: TakeoverGroup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                overview(group)
                if !group.roles.isEmpty {
                    rolesSection(group)
                }
                membersSection(group)
                channelsSection(group)
                founderQASection(group)
                Color.clear.frame(height: 80)
            }
            .padding(Theme.Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: Theme.Spacing.sm) {
                if hasJoined {
                    SecondaryButton("Joined", systemImage: "checkmark") {}
                } else {
                    SecondaryButton("Join group", systemImage: "person.badge.plus") {
                        Task { await join(group) }
                    }
                }
                PrimaryButton("Submit collective offer", systemImage: "paperplane.fill") {
                    showOffer = true
                }
            }
            .padding(Theme.Spacing.md)
            .background(.ultraThinMaterial)
        }
    }

    private func overview(_ group: TakeoverGroup) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text("Preserving \(group.businessName)").font(.lbiHeadline).inkStyle()
                    Spacer()
                    TagChip(text: group.status.displayName, style: group.status.chipStyle)
                }
                ProgressGoalBar(
                    progress: Double(group.memberCount) / Double(max(1, group.targetMembers)),
                    raisedLabel: "\(group.memberCount) members",
                    goalLabel: "Target \(group.targetMembers)",
                    tint: Theme.Palette.jade
                )
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    StatPill(label: "Pooled", value: Money.hkd(group.pooledCommitment, abbreviated: true), icon: "banknote.fill")
                    StatPill(label: "Members", value: "\(group.memberCount)", icon: "person.3.fill")
                    if let offer = group.collectiveOfferAmount {
                        StatPill(label: "Collective offer", value: Money.hkd(offer, abbreviated: true), icon: "paperplane.fill")
                    }
                }
            }
        }
    }

    private func rolesSection(_ group: TakeoverGroup) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Roles", subtitle: "What the group needs")
            ForEach(group.roles) { role in
                CardContainer(padding: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: role.isFilled ? "checkmark.circle.fill" : "person.crop.circle.badge.plus")
                            .font(.system(size: 20))
                            .foregroundStyle(role.isFilled ? Theme.Palette.jade : Theme.Palette.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(role.title).font(.lbiSubtitle).inkStyle()
                            Text(role.detail).font(.lbiCaption).inkSecondaryStyle()
                        }
                        Spacer()
                        if role.isFilled, let name = role.occupantName {
                            TagChip(text: name, style: .neutral)
                        } else {
                            TagChip(text: "Open", style: .red)
                        }
                    }
                }
            }
        }
    }

    private func membersSection(_ group: TakeoverGroup) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Members & roles")
            ForEach(group.members) { member in
                HStack {
                    Circle().fill(Theme.Palette.paperDeep).frame(width: 36, height: 36)
                        .overlay(Text(String(member.name.prefix(1))).font(.lbiCaption).inkStyle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(member.name).font(.lbiBody).inkStyle()
                        if let amount = member.committedAmount {
                            Text("Committed \(Money.hkd(amount, abbreviated: true))").font(.lbiLabel).inkSecondaryStyle()
                        }
                    }
                    Spacer()
                    TagChip(text: member.role.displayName, style: member.role == .lead ? .red : .neutral)
                }
            }
        }
    }

    private func channelsSection(_ group: TakeoverGroup) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Discussion channels")
            ForEach(group.channels) { channel in
                NavigationLink {
                    GroupChannelView(groupId: group.id, channel: channel)
                } label: {
                    CardContainer {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("# \(channel.name)").font(.lbiSubtitle).inkStyle()
                                Text(channel.topic).font(.lbiCaption).inkSecondaryStyle()
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(channel.messages.count)").font(.lbiSubtitle).foregroundStyle(Theme.Palette.red)
                                Image(systemName: "chevron.right").font(.system(size: 12)).inkSecondaryStyle()
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func founderQASection(_ group: TakeoverGroup) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Founder Q&A")
            ForEach(group.founderQAndA) { qa in
                CardContainer {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Label(qa.question, systemImage: "questionmark.circle.fill")
                            .font(.lbiSubtitle).inkStyle()
                        if let answer = qa.answer {
                            Text(answer).font(.lbiBody).inkSecondaryStyle()
                        } else {
                            Text("Awaiting the founder's reply…").font(.lbiCaption).foregroundStyle(Theme.Palette.gold)
                        }
                        Text("Asked by \(qa.askedBy)").font(.lbiLabel).inkSecondaryStyle()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("No active group yet").font(.lbiHeadline).inkStyle()
            Text("Be the first to start a takeover group for \(businessName).")
                .font(.lbiBody).inkSecondaryStyle().multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    private func load() async {
        isLoading = true
        group = try? await environment.takeoverRepository.group(forBusiness: businessId)
        if let group { hasJoined = profileStore.profile?.joinedGroupIds.contains(group.id) ?? false }
        isLoading = false
    }

    private func join(_ group: TakeoverGroup) async {
        try? await environment.takeoverRepository.join(groupId: group.id)
        await profileStore.update { $0.joinedGroupIds.insert(group.id) }
        hasJoined = true
        await load()
    }
}

extension TakeoverStatus {
    var chipStyle: TagChip.Style {
        switch self {
        case .forming: return .neutral
        case .negotiating: return .gold
        case .dueDiligence: return .gold
        case .completed: return .jade
        case .failed: return .outline
        }
    }
}

#Preview {
    NavigationStack {
        TakeoverGroupView(businessId: "biz-002", businessName: "Leung's Master Tailoring")
            .environment(AppEnvironment.preview)
            .environment(previewProfileStore())
    }
}
