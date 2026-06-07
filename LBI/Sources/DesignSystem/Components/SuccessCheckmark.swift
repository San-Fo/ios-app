import SwiftUI

/// An Apple-style animated success confirmation: a seal that springs in with a
/// soft expanding ring, a draw-on checkmark, and a one-shot success haptic.
///
/// Used after completing a flow (e.g. KYC / KYB verification) to give the same
/// satisfying confirmation feel as Apple Pay / system success sheets.
struct SuccessCheckmark: View {
    var tint: Color = Theme.Palette.jade
    var size: CGFloat = 96

    @State private var sealScale: CGFloat = 0.4
    @State private var sealOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0
    @State private var checkTrim: CGFloat = 0

    var body: some View {
        ZStack {
            // Expanding, fading ring behind the seal.
            Circle()
                .stroke(tint.opacity(0.35), lineWidth: 3)
                .frame(width: size, height: size)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            // Filled disc that springs in.
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: size, height: size)
                .scaleEffect(sealScale)
                .opacity(sealOpacity)

            // The check, drawn on with a trim animation.
            Checkmark()
                .trim(from: 0, to: checkTrim)
                .stroke(tint, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.46, height: size * 0.46)
                .scaleEffect(sealScale)
                .opacity(sealOpacity)
        }
        .frame(width: size * 1.6, height: size * 1.6)
        .onAppear { animate() }
    }

    private func animate() {
        // Seal springs in.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
            sealScale = 1
            sealOpacity = 1
        }
        // Check draws on just after the seal lands.
        withAnimation(.easeOut(duration: 0.35).delay(0.18)) {
            checkTrim = 1
        }
        // Ring pulses outward and fades.
        ringOpacity = 1
        withAnimation(.easeOut(duration: 0.7).delay(0.1)) {
            ringScale = 1.6
            ringOpacity = 0
        }
        // Success haptic synced with the seal landing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            Haptics.notify(.success)
        }
    }
}

/// A checkmark path normalised to its frame, for the trim draw-on effect.
private struct Checkmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: 0.05 * w, y: 0.55 * h))
        path.addLine(to: CGPoint(x: 0.38 * w, y: 0.88 * h))
        path.addLine(to: CGPoint(x: 0.95 * w, y: 0.12 * h))
        return path
    }
}

#Preview {
    SuccessCheckmark()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.paper)
}
