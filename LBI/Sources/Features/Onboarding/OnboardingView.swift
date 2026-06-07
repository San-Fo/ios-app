import SwiftUI

/// Four-step onboarding: language → interests → districts → intent.
struct OnboardingView: View {
    @Environment(ProfileStore.self) private var profileStore

    @State private var step = 0
    @State private var language: AppLanguage = .english
    @State private var interests: Set<BusinessCategory> = []
    @State private var districts: Set<District> = []
    @State private var intents: Set<UserIntent> = []
    @State private var isSaving = false

    private let totalSteps = 4

    var body: some View {
        ZStack {
            Theme.Palette.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar

                TabView(selection: $step) {
                    languageStep.tag(0)
                    interestsStep.tag(1)
                    districtsStep.tag(2)
                    intentStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)

                footer
            }
        }
    }

    // MARK: Progress

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Theme.Palette.red : Theme.Palette.paperDeep)
                    .frame(height: 5)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: Steps

    private var languageStep: some View {
        StepScaffold(
            title: "Choose your language",
            subtitle: "You can change this anytime. More languages are coming soon."
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        if lang.isAvailable { language = lang }
                    } label: {
                        HStack {
                            Text(lang.displayName).font(.lbiSubtitle).inkStyle()
                            if !lang.isAvailable {
                                TagChip(text: "Coming soon", style: .outline)
                            }
                            Spacer()
                            if language == lang {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Palette.red)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .stroke(language == lang ? Theme.Palette.red : Theme.Palette.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(lang.isAvailable ? 1 : 0.6)
                }
            }
        }
    }

    private var interestsStep: some View {
        StepScaffold(
            title: "What do you care about?",
            subtitle: "Pick the kinds of local businesses you'd love to help preserve. We'll show the closest matches first, but every public offer stays visible."
        ) {
            FlowLayout(spacing: 10) {
                ForEach(BusinessCategory.allCases) { category in
                    SelectableChip(
                        title: category.displayName,
                        systemImage: category.systemImage,
                        isSelected: interests.contains(category)
                    ) { toggle(category, in: &interests) }
                }
            }
        }
    }

    private var districtsStep: some View {
        StepScaffold(
            title: "Which neighbourhoods?",
            subtitle: "Choose the districts closest to your heart. These preferences change ranking only, not what you can see."
        ) {
            FlowLayout(spacing: 10) {
                ForEach(District.allCases) { district in
                    SelectableChip(
                        title: district.displayName,
                        isSelected: districts.contains(district)
                    ) { toggle(district, in: &districts) }
                }
            }
        }
    }

    private var intentStep: some View {
        StepScaffold(
            title: "How would you like to help?",
            subtitle: "This guides what appears first. You can do more than one, and you can still explore every public opportunity."
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(UserIntent.allCases) { intent in
                    Button {
                        toggle(intent, in: &intents)
                    } label: {
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            Image(systemName: intent.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.Palette.red)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(intent.displayName).font(.lbiSubtitle).inkStyle()
                                Text(intent.detail).font(.lbiCaption).inkSecondaryStyle()
                            }
                            Spacer()
                            Image(systemName: intents.contains(intent) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(intents.contains(intent) ? Theme.Palette.red : Theme.Palette.inkSecondary.opacity(0.4))
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .stroke(intents.contains(intent) ? Theme.Palette.red : Theme.Palette.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: Theme.Spacing.md) {
            if step > 0 {
                SecondaryButton("Back") { withAnimation { step -= 1 } }
                    .frame(width: 110)
            }
            PrimaryButton(step == totalSteps - 1 ? "Start exploring" : "Continue", isLoading: isSaving, isEnabled: canAdvance) {
                advance()
            }
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: Logic

    private var canAdvance: Bool {
        switch step {
        case 1: return !interests.isEmpty
        case 2: return !districts.isEmpty
        case 3: return !intents.isEmpty
        default: return true
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation { step += 1 }
        } else {
            Task {
                isSaving = true
                await profileStore.completeOnboarding(
                    language: language,
                    interests: interests,
                    districts: districts,
                    intents: intents
                )
                isSaving = false
            }
        }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

/// Shared layout for an onboarding step.
private struct StepScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(title).font(.lbiTitle).inkStyle()
                    Text(subtitle).font(.lbiBody).inkSecondaryStyle()
                }
                content
            }
            .padding(Theme.Spacing.lg)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(ProfileStore(repository: MockProfileRepository(), businessRepository: MockBusinessRepository()))
        .task {
            // no-op
        }
}
