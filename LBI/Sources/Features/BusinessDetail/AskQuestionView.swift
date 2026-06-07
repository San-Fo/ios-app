import SwiftUI

/// Lets a user send a question to a business / founder.
struct AskQuestionView: View {
    let businessName: String

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var sent = false

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
                        SectionHeader(title: "Ask a question", subtitle: "About \(businessName)")
                        TextEditor(text: $text)
                            .font(.lbiBody)
                            .frame(minHeight: 160)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Palette.hairline, lineWidth: 1))
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
                    PrimaryButton("Send question", systemImage: "paperplane.fill", isEnabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        sent = true
                    }
                    .padding(Theme.Spacing.lg)
                    .background(Theme.Palette.paper)
                }
            }
        }
    }
}

#Preview {
    AskQuestionView(businessName: "Wing Kee Cha Chaan Teng")
}
