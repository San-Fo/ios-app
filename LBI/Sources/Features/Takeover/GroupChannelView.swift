import SwiftUI

/// A single takeover-group discussion channel with chat.
struct GroupChannelView: View {
    let groupId: String
    @State var channel: GroupChannel

    @Environment(AppEnvironment.self) private var environment
    @State private var draft = ""
    @State private var isSending = false
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(channel.topic)
                            .font(.lbiCaption).inkSecondaryStyle()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)

                        ForEach(channel.messages) { message in
                            messageBubble(message).id(message.id)
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .onChange(of: channel.messages.count) { _, _ in
                    if let last = channel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            composer
        }
        .background(Theme.Palette.paper)
        .navigationTitle("# \(channel.name)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                if Task.isCancelled { return }
                let lastSentAt = channel.messages.last?.sentAt
                if let newOnes = try? await environment.takeoverRepository.newMessages(
                    groupId: groupId,
                    channelId: channel.id,
                    after: lastSentAt
                ), !newOnes.isEmpty {
                    await MainActor.run {
                        let existing = Set(channel.messages.map(\.id))
                        channel.messages.append(contentsOf: newOnes.filter { !existing.contains($0.id) })
                    }
                }
            }
        }
    }

    private func messageBubble(_ message: GroupMessage) -> some View {
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

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        isSending = true
        defer { isSending = false }
        if let message = try? await environment.takeoverRepository.sendMessage(groupId: groupId, channelId: channel.id, text: text) {
            channel.messages.append(message)
        }
    }
}

#Preview {
    NavigationStack {
        GroupChannelView(groupId: "tg-002", channel: SampleData.takeoverGroups[0].channels[0])
            .environment(AppEnvironment.preview)
    }
}
