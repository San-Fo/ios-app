import Kingfisher
import SwiftUI

/// Loads and caches a remote image via Kingfisher, with a warm placeholder.
/// All business/founder imagery from the backend flows through here.
struct RemoteImage: View {
    let url: URL?
    var aspectRatio: CGFloat?
    var contentMode: SwiftUI.ContentMode = .fill

    var body: some View {
        KFImage(url)
            .placeholder { placeholder }
            .resizable()
            .fade(duration: 0.25)
            .aspectRatio(aspectRatio, contentMode: contentMode)
            .clipped()
            .background(Theme.Palette.paperDeep)
    }

    private var placeholder: some View {
        ZStack {
            Theme.Palette.paperDeep
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 32))
                .foregroundStyle(Theme.Palette.inkSecondary.opacity(0.4))
        }
    }
}
