import SwiftUI

/// Pro-investor AI investment memo: score, confidence, summary, strengths,
/// risks, and the AI's recommended next action.
///
/// Visible only on the commercial-investor side. Owners and public users
/// never see AI screening output.
struct AIMemoCard: View {
    let evaluation: SaleEvaluation
    /// When `false`, only the headline strip is shown (compact list rows).
    var expanded: Bool = true

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                headline

                if expanded {
                    if !evaluation.summary.isEmpty {
                        Text(evaluation.summary)
                            .font(.lbiBody)
                            .inkSecondaryStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !evaluation.strengths.isEmpty {
                        labelledChips(
                            "Strengths",
                            items: evaluation.strengths,
                            icon: "checkmark.seal.fill",
                            style: .jade
                        )
                    }

                    if !evaluation.risks.isEmpty {
                        labelledChips(
                            "Risks",
                            items: evaluation.risks,
                            icon: "exclamationmark.triangle.fill",
                            style: .outline
                        )
                    }

                    if !evaluation.recommendedAction.isEmpty {
                        recommendedAction
                    }
                }
            }
        }
    }

    private var headline: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            scoreBadge

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.red)
                    Text("AI investment memo")
                        .font(.lbiHeadline)
                        .inkStyle()
                }
                Text("\(evaluation.rating.displayName) · \(evaluation.verdict.displayName)")
                    .font(.lbiCaption)
                    .inkSecondaryStyle()
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var scoreBadge: some View {
        VStack(spacing: 1) {
            Text("\(evaluation.score)")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(Theme.Palette.ink)
            Text("/100")
                .font(.lbiLabel)
                .inkSecondaryStyle()
        }
        .frame(width: 58, height: 58)
        .background(Theme.Palette.gold.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Palette.gold.opacity(0.45), lineWidth: 1)
        )
    }

    private func labelledChips(_ title: String, items: [String], icon: String, style: TagChip.Style) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.lbiLabel)
                .inkSecondaryStyle()
            FlowLayout(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    TagChip(text: item, systemImage: icon, style: style)
                }
            }
        }
    }

    private var recommendedAction: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.red)
                Text("Recommended action")
                    .font(.lbiLabel)
                    .inkSecondaryStyle()
                Spacer()
                Text("Confidence \(evaluation.confidencePercent)%")
                    .font(.lbiMonoSmall)
                    .inkSecondaryStyle()
            }
            Text(evaluation.recommendedAction)
                .font(.lbiBody)
                .inkStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.paperDeep)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}

#Preview {
    ScrollView {
        AIMemoCard(evaluation: SampleData.professionalSales[0].aiEvaluation!)
            .padding()
    }
    .background(Theme.Palette.paper)
}
