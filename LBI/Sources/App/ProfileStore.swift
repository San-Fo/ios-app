import Observation

/// Observable holder for the signed-in user's profile, backed by the repository.
///
/// Acts as the single source of truth for profile state across the UI. Mutations
/// go through `update`, which applies the change locally (for instant UI feedback)
/// and then persists it via the repository. `@MainActor` keeps all state changes
/// on the main thread so SwiftUI observation is safe.
@MainActor
@Observable
final class ProfileStore {
    /// The current profile, or nil before it has loaded.
    private(set) var profile: UserProfile?
    /// The user's own business listings (any status). Drives "owner" UI: a
    /// normal user becomes an owner simply by listing & verifying a business —
    /// there is no separate owner account type.
    private(set) var myBusinesses: [Business] = []
    /// True while the initial profile load is in flight.
    var isLoading = false

    private let repository: ProfileRepository
    private let businessRepository: BusinessRepository

    init(repository: ProfileRepository, businessRepository: BusinessRepository) {
        self.repository = repository
        self.businessRepository = businessRepository
    }

    /// Whether the user owns at least one business (i.e. acts as an owner).
    var ownsBusiness: Bool { !myBusinesses.isEmpty }

    /// Whether the user owns at least one *verified* (published) business.
    var ownsVerifiedBusiness: Bool {
        myBusinesses.contains { $0.status != .raising || true } && ownsBusiness
    }

    /// True if the given business belongs to the signed-in user.
    func isMyBusiness(_ business: BusinessDetail) -> Bool {
        guard let me = profile?.id, let owner = business.ownerUserId else { return false }
        return me == owner
    }

    /// Loads the profile for a signed-in user; failures leave `profile` nil.
    func load(for user: AuthenticatedUser) async {
        isLoading = true
        defer { isLoading = false }
        profile = try? await repository.loadProfile(user: user)
        await loadMyBusinesses()
    }

    /// Refreshes the user's own listings (call after submitting/verifying one).
    func loadMyBusinesses() async {
        myBusinesses = (try? await businessRepository.myBusinesses()) ?? []
    }

    /// Applies a mutation to the profile, updates the UI immediately, then
    /// persists the result. No-op if there is no loaded profile.
    func update(_ transform: (inout UserProfile) -> Void) async {
        guard var profile else { return }
        transform(&profile)
        self.profile = profile
        try? await repository.save(profile)
    }

    /// Stores the onboarding selections and marks onboarding complete so the
    /// root view switches from onboarding to the main tabs.
    func completeOnboarding(
        language: AppLanguage,
        interests: Set<BusinessCategory>,
        districts: Set<District>,
        intents: Set<UserIntent>
    ) async {
        await update { profile in
            profile.language = language
            profile.interests = interests
            profile.districts = districts
            profile.intents = intents
            profile.hasCompletedOnboarding = true
        }
    }

    /// Record a verification programme's status on the local profile.
    func setVerification(_ kind: VerificationKind, status: VerificationStatus) async {
        await update { $0.verifications[kind] = status }
    }

    /// Applies a server verification outcome: records the new status and adopts
    /// the role the server granted (if any). The client never sets elevated
    /// roles itself — it only mirrors the server's decision here.
    func applyVerificationOutcome(_ outcome: VerificationOutcome) async {
        await update { profile in
            profile.verifications[outcome.record.kind] = outcome.record.status
            if let role = outcome.grantedRole {
                profile.role = role
            }
        }
    }

    /// Toggles a business's saved/bookmarked state, with haptic feedback, and
    /// syncs the change to the backend.
    func toggleSaved(_ businessId: String) async {
        guard let profile else { return }
        let isSaved = profile.savedBusinessIds.contains(businessId)
        Haptics.impact(isSaved ? .light : .medium)
        await update { p in
            if isSaved { p.savedBusinessIds.remove(businessId) }
            else { p.savedBusinessIds.insert(businessId) }
        }
        try? await repository.setSaved(businessId: businessId, saved: !isSaved)
    }

    /// Whether the given business is currently saved by the user.
    func isSaved(_ businessId: String) -> Bool {
        profile?.savedBusinessIds.contains(businessId) ?? false
    }

    /// Seeds a profile directly (previews/tests only).
    func setProfileForPreview(_ profile: UserProfile) {
        self.profile = profile
    }
}
