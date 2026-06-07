import SwiftUI

/// Lets a user post a public question to a business / founder.
struct AskQuestionView: View {
    let businessId: String
    let businessName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @State private var text = ""
    @State private var sent = false
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if sent {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 48)).foregroundStyle(Theme.Palette.jade)
                            Text("Question sent").font(.lbiTitle).inkStyle()
                            Text("The team behind \(businessName) will get back to you.")
                                .font(.lbiBody).inkSecondaryStyle().multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.top, Theme.Spacing.xxl)
                    } else {
                        SectionHeader(title: "Ask a question", subtitle: "Public — the owner can answer for everyone")
                        TextEditor(text: $text)
                            .font(.lbiBody)
                            .frame(minHeight: 160)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
                        if let errorMessage {
                            Text(errorMessage).font(.lbiCaption).foregroundStyle(Theme.Palette.red)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.paper)
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }.foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !sent {
                    PrimaryButton("Send question", systemImage: "paperplane.fill", isLoading: isSending, isEnabled: !trimmed.isEmpty) {
                        Task { await send() }
                    }
                    .padding(Theme.Spacing.lg)
                    .background(Theme.Palette.paper)
                }
            }
        }
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await environment.businessRepository.askQuestion(businessId: businessId, question: trimmed)
            sent = true
        } catch {
            errorMessage = "Couldn't send your question. Please try again."
        }
    }
}

#Preview {
    AskQuestionView(businessId: "preview", businessName: "Wing Kee Cha Chaan Teng")
        .environment(AppEnvironment.preview)
}
