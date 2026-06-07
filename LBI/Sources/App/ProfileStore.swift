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
    /// Durable, device-local source of truth for bookmarks (works offline / as
    /// a guest, and survives relaunches even without a backend session).
    private let bookmarks: LocalBookmarkStore

    init(
        repository: ProfileRepository,
        businessRepository: BusinessRepository,
        bookmarks: LocalBookmarkStore = LocalBookmarkStore()
    ) {
        self.repository = repository
        self.businessRepository = businessRepository
        self.bookmarks = bookmarks
    }

    /// Whether the user owns at least one business (i.e. acts as an owner).
    var ownsBusiness: Bool { !myBusinesses.isEmpty }

    /// When true, a demo-owned business is injected so reviewers can preview the
    /// owner experience (extra "My Business" tab, owner-gated detail UI) without
    /// listing a real business. Dev/demo tool only.
    private(set) var demoOwnerEnabled = false

    /// True if the given business belongs to the signed-in user. Recognises both
    /// real ownership and the demo-owned sample business.
    func isMyBusiness(_ business: BusinessDetail) -> Bool {
        if demoOwnerEnabled, business.id == ProfileStore.demoBusinessId { return true }
        guard let me = profile?.id, let owner = business.ownerUserId else { return false }
        return me == owner
    }

    /// Loads the profile for a signed-in user; failures leave `profile` nil.
    func load(for user: AuthenticatedUser) async {
        isLoading = true
        defer { isLoading = false }
        var loaded = try? await repository.loadProfile(user: user)
        // Reconcile bookmarks: union server-saved ids into the durable local
        // store, then make the local set the source of truth on the profile so
        // the UI is consistent whether or not the backend is reachable.
        if let serverSaved = loaded?.savedBusinessIds {
            bookmarks.merge(serverSaved)
        }
        loaded?.savedBusinessIds = bookmarks.all()
        profile = loaded
        await loadMyBusinesses()
    }

    /// Refreshes the user's own listings (call after submitting/verifying one).
    func loadMyBusinesses() async {
        let real = (try? await businessRepository.myBusinesses()) ?? []
        myBusinesses = demoOwnerEnabled ? real + [ProfileStore.demoBusiness] : real
    }

    /// Toggles the demo business-owner preview (dev tool only).
    func setDemoOwner(_ enabled: Bool) async {
        demoOwnerEnabled = enabled
        await loadMyBusinesses()
    }

    /// A stable id used to recognise the demo-owned sample business.
    static let demoBusinessId = "demo-owned-business"

    /// The sample business shown as "owned" in demo-owner mode.
    private static var demoBusiness: Business {
        Business(
            id: demoBusinessId,
            ownerUserId: "demo-owner",
            name: "Your Demo Business",
            category: .restaurant,
            district: .central,
            storyHeadline: "A demo listing to preview the owner experience.",
            heroImageURL: nil,
            status: .seekingBuyer,
            fundingGoal: 0,
            fundingRaised: 0,
            fundingOptions: []
        )
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

    /// Toggles a business's saved/bookmarked state, with haptic feedback.
    ///
    /// The local store is the source of truth (so saving works as a guest,
    /// offline, or when the backend save endpoint is unavailable). If a real
    /// profile/session exists, the change is also mirrored into the profile and
    /// best-effort synced to the backend.
    func toggleSaved(_ businessId: String) async {
        let wasSaved = bookmarks.contains(businessId)
        Haptics.impact(wasSaved ? .light : .medium)
        let nowSaved = bookmarks.toggle(businessId)

        // Mirror onto the in-memory profile (if loaded) for instant UI updates.
        // Mutate directly rather than via `update`, which would re-PUT the whole
        // profile; the dedicated save endpoint below is the right sync path.
        if var p = profile {
            if nowSaved { p.savedBusinessIds.insert(businessId) }
            else { p.savedBusinessIds.remove(businessId) }
            profile = p
        }
        // Best-effort backend sync; ignored if there's no valid session.
        try? await repository.setSaved(businessId: businessId, saved: nowSaved)
    }

    /// Whether the given business is currently saved by the user (local truth).
    func isSaved(_ businessId: String) -> Bool {
        bookmarks.contains(businessId)
    }

    /// All locally-saved business ids (source of truth for the Saved tab).
    var savedBusinessIds: Set<String> {
        bookmarks.all()
    }

    /// Seeds a profile directly (previews/tests only).
    func setProfileForPreview(_ profile: UserProfile) {
        self.profile = profile
    }
}
