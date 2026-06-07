import SwiftUI

/// A private, server-backed deal conversation between the owner and the party
/// whose offer was accepted (commercial bidder, solo buyer, or takeover group).
///
/// Messages are loaded from and sent to the backend; while open, the view
/// polls for new messages so both sides stay in sync.
struct DealChatView: View {
    let conversationId: String
    /// Seeds the initial state so the view renders instantly after acceptance.
    @State var conversation: DealConversation

    @Environment(AppEnvironment.self) private var environment
    @State private var draft = ""
    @State private var isSending = false
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            dealHeader

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ForEach(conversation.messages) { message in
                            messageRow(message).id(message.id)
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .onChange(of: conversation.messages.count) { _, _ in
                    if let last = conversation.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            composer
        }
        .background(Theme.Palette.paper)
        .navigationTitle(conversation.businessName.isEmpty ? "Deal" : conversation.businessName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Mark payment pending") { Task { await updateStatus(.paymentPending) } }
                    Button("Mark completed") { Task { await updateStatus(.completed) } }
                    Button("Cancel deal", role: .destructive) { Task { await updateStatus(.cancelled) } }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.Palette.red)
                }
            }
        }
        .task { await refresh() }
        .onAppear { startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    private var dealHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: conversation.dealKind.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.red)
                Text(conversation.counterpartyName)
                    .font(.lbiSubtitle)
                    .inkStyle()
                Spacer()
                TagChip(text: conversation.status.displayName, style: statusStyle)
            }
            HStack {
                Text(conversation.dealKind.displayName)
                    .font(.lbiCaption).inkSecondaryStyle()
                Spacer()
                // Hide the agreed amount when unknown (e.g. opened from the
                // conversation list, where the sale amount isn't loaded).
                if conversation.agreedAmount > 0 {
                    Text("Agreed \(Money.hkd(conversation.agreedAmount))")
                        .font(.lbiMonoSmall)
                        .foregroundStyle(Theme.Palette.red)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Palette.hairline).frame(height: 1)
        }
    }

    private var statusStyle: TagChip.Style {
        switch conversation.status {
        case .negotiating: return .gold
        case .paymentPending: return .red
        case .completed: return .jade
        case .cancelled: return .outline
        }
    }

    @ViewBuilder
    private func messageRow(_ message: DealMessage) -> some View {
        if message.isSystem {
            Text(message.text)
                .font(.lbiCaption)
                .inkSecondaryStyle()
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
        } else {
            HStack {
                if message.isCurrentUser { Spacer(minLength: 40) }
                VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 2) {
                    if !message.isCurrentUser {
                        Text(message.authorName).font(.lbiLabel).foregroundStyle(Theme.Palette.red)
                    }
                    Text(message.text)
                        .font(.lbiBody)
                        .foregroundStyle(message.isCurrentUser ? .white : Theme.Palette.ink)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(message.isCurrentUser ? Theme.Palette.red : Theme.Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(message.isCurrentUser ? .clear : Theme.Palette.hairline, lineWidth: 1))
                }
                if !message.isCurrentUser { Spacer(minLength: 40) }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Message…", text: $draft, axis: .vertical)
                .font(.lbiBody)
                .padding(Theme.Spacing.sm)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(canSend ? Theme.Palette.red : Theme.Palette.inkSecondary.opacity(0.4))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
        }
        .padding(Theme.Spacing.md)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    // MARK: Networking

    private func refresh() async {
        if let fresh = try? await environment.dealChatRepository.conversation(id: conversationId) {
            conversation = fresh
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                if Task.isCancelled { return }
                let lastSentAt = conversation.messages.last?.sentAt
                if let newOnes = try? await environment.dealChatRepository.newMessages(
                    conversationId: conversationId,
                    after: lastSentAt
                ), !newOnes.isEmpty {
                    await MainActor.run {
                        let existing = Set(conversation.messages.map(\.id))
                        conversation.messages.append(contentsOf: newOnes.filter { !existing.contains($0.id) })
                    }
                }
            }
        }
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        isSending = true
        defer { isSending = false }
        if (try? await environment.dealChatRepository.sendMessage(conversationId: conversationId, text: text)) != nil {
            await refresh()
        }
    }

    private func updateStatus(_ status: DealStatus) async {
        if let updated = try? await environment.dealChatRepository.updateStatus(conversationId: conversationId, status: status) {
            conversation = updated
        }
    }
}

#Preview {
    NavigationStack {
        DealChatView(
            conversationId: "preview",
            conversation: DealConversation(
                id: "preview",
                saleId: "sale-002",
                businessId: "biz-002",
                businessName: "Leung's Master Tailoring",
                dealKind: .commercialBid,
                agreedAmount: 2_050_000,
                counterpartyName: "M. Cheng (independent)",
                messages: [
                    DealMessage(id: "1", authorName: "System", text: "Offer accepted. Discuss handover and payment here.", sentAt: Date(), isCurrentUser: false, isSystem: true)
                ]
            )
        )
        .environment(AppEnvironment.preview)
    }
}
