import Observation
import os

/// Dependency container holding the app's services and repositories.
///
/// The choice between Live (real network) and Mock implementations is driven by
/// `APIConfiguration.useMockData`. The production path uses Live everywhere;
/// mocks exist only for development, previews and tests.
@Observable
final class AppEnvironment {
    private static let logger = Logger(subsystem: "dev.tuist.LBI", category: "startup")
    let configuration: APIConfiguration
    let authService: AuthService
    let businessRepository: BusinessRepository
    let profileRepository: ProfileRepository
    let takeoverRepository: TakeoverRepository
    let listingRepository: ListingRepository
    let saleRepository: SaleRepository
    let dealChatRepository: DealChatRepository
    let verificationRepository: VerificationRepository

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
            authService = LiveAuthService(client: client, tokenStore: tokenStore)
            businessRepository = LiveBusinessRepository(client: client)
            profileRepository = LiveProfileRepository(client: client)
            takeoverRepository = LiveTakeoverRepository(client: client)
            listingRepository = LiveListingRepository(client: client)
            saleRepository = LiveSaleRepository(client: client)
            dealChatRepository = LiveDealChatRepository(client: client)
            verificationRepository = LiveVerificationRepository(client: client)
        }
    }

    /// Convenience environment for previews/tests (always mocks).
    static var preview: AppEnvironment { AppEnvironment(configuration: .preview) }
}
