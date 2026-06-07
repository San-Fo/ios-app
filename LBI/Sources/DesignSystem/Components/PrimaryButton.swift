import SwiftUI

/// Primary call-to-action button in signage red.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    if let systemImage { Image(systemName: systemImage) }
                    Text(title).font(.lbiSubtitle)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .foregroundStyle(.white)
            .background(Theme.Palette.red)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// Secondary outlined button.
struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.lbiSubtitle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .foregroundStyle(Theme.Palette.ink)
            .background(Theme.Palette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.Palette.ink.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton("Invest", systemImage: "heart.fill") {}
        SecondaryButton("Ask a Question", systemImage: "bubble.left") {}
    }
    .padding()
    .background(Theme.Palette.paper)
}
