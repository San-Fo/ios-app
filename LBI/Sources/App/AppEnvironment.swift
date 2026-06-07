import Foundation
import Observation
import os

/// Dependency container holding the app's services and repositories.
///
/// The choice between Live (real network) and Mock implementations is driven by
/// `APIConfiguration.useMockData`. The production path uses Live everywhere;
/// mocks exist only for development, previews and tests.
@Observable
final class AppEnvironment {
    private static let logger = Logger(subsystem: "com.san-fo.app", category: "startup")
    let configuration: APIConfiguration
    let authService: AuthService
    let businessRepository: BusinessRepository
    let profileRepository: ProfileRepository
    let takeoverRepository: TakeoverRepository
    let listingRepository: ListingRepository
    let saleRepository: SaleRepository
    let dealChatRepository: DealChatRepository
    let verificationRepository: VerificationRepository

    /// The signed-in user's backend id, set once the session is established.
    /// Live repositories read this (via a closure) to attribute chat messages
    /// ("You" vs counterparty) and resolve the current user in mappings.
    /// Thread-safe so repository background work can read it safely.
    private let currentUserIdBox = CurrentUserIdBox()

    /// Records the signed-in user's id so live repos can attribute data to them.
    func setCurrentUserId(_ id: String?) {
        currentUserIdBox.value = id
    }

    init(configuration: APIConfiguration = .live) {
        self.configuration = configuration

        // Loud, unmissable announcement of the data source at launch.
        if configuration.useMockData {
            Self.logger.warning("🟠🟠🟠 MOCK MODE — all data is in-memory sample data; NOTHING hits the backend. Set APIConfiguration.useMockData=false for real data. 🟠🟠🟠")
        } else {
            Self.logger.notice("🟢 LIVE MODE — using backend at \(configuration.baseURL.absoluteString, privacy: .public)")
        }

        let tokenStore: TokenStore = configuration.useMockData
            ? InMemoryTokenStore()
            : KeychainTokenStore()

        let client: APIClient = LiveAPIClient(
            configuration: configuration,
            tokenStore: tokenStore
        )

        if configuration.useMockData {
            let dealChat = MockDealChatRepository()
            authService = MockAuthService(tokenStore: tokenStore)
            businessRepository = MockBusinessRepository()
            profileRepository = MockProfileRepository()
            takeoverRepository = MockTakeoverRepository()
            listingRepository = MockListingRepository()
            saleRepository = MockSaleRepository(dealChat: dealChat)
            dealChatRepository = dealChat
            verificationRepository = MockVerificationRepository()
        } else {
            // Live repos read the current user id lazily via this closure so it
            // reflects the session as soon as `setCurrentUserId` is called.
            let box = currentUserIdBox
            let userId: () -> String? = { box.value }
            authService = LiveAuthService(client: client, tokenStore: tokenStore)
            businessRepository = LiveBusinessRepository(client: client)
            profileRepository = LiveProfileRepository(client: client)
            takeoverRepository = LiveTakeoverRepository(client: client, currentUserId: userId)
            listingRepository = LiveListingRepository(client: client)
            saleRepository = LiveSaleRepository(client: client, currentUserId: userId)
            dealChatRepository = LiveDealChatRepository(client: client, currentUserId: userId)
            verificationRepository = LiveVerificationRepository(client: client)
        }
    }

    /// Convenience environment for previews/tests (always mocks).
    static var preview: AppEnvironment { AppEnvironment(configuration: .preview) }
}

/// Thread-safe holder for the current user id, shared with live repositories.
private final class CurrentUserIdBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?
    var value: String? {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); defer { lock.unlock() }; stored = newValue }
    }
}
