import SwiftUI

/// Shows the owner-set supporter reward tiers (collect N support cards → perk).
/// Support cards are voluntary collectible keepsakes that show you helped —
/// not financial shares.
struct ShareRewardsCard: View {
    let rewards: [ShareReward]
    /// How many support cards the current supporter has collected.
    var ownedCards: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(
                title: "Supporter cards",
                subtitle: "Collect cards by donating — unlock thank-yous from the owner"
            )

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(rewards.sorted()) { reward in
                    rewardRow(reward)
                }
            }
        }
    }

    private func rewardRow(_ reward: ShareReward) -> some View {
        let unlocked = ownedCards >= reward.cardsRequired
        return CardContainer(padding: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(spacing: 2) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(unlocked ? Theme.Palette.gold : Theme.Palette.inkTertiary)
                    Text("\(reward.cardsRequired)")
                        .font(.lbiMonoLarge)
                        .foregroundStyle(unlocked ? Theme.Palette.gold : Theme.Palette.ink)
                    Text(reward.cardsRequired == 1 ? "card" : "cards")
                        .font(.lbiLabel)
                        .inkSecondaryStyle()
                }
                .frame(width: 64)

                Rectangle()
                    .fill(Theme.Palette.hairline)
                    .frame(width: 1, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(reward.title).font(.lbiSubtitle).inkStyle()
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = reward.detail {
                        Text(detail).font(.lbiCaption).inkSecondaryStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: Theme.Spacing.xs)

                Image(systemName: unlocked ? "checkmark.seal.fill" : "lock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(unlocked ? Theme.Palette.gold : Theme.Palette.inkTertiary)
            }
        }
    }
}

#Preview {
    ScrollView {
        ShareRewardsCard(rewards: SampleData.wongNoodleShop.shareRewards, ownedCards: 5)
            .padding()
    }
    .background(Theme.Palette.paper)
}
