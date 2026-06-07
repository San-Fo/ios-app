import Foundation
import os

/// Wraps the live `BusinessRepository` and falls back to sample data **only**
/// for read-only discovery (recommended / list / detail) when the live call
/// throws (network/transport/server error).
///
/// Scope is deliberately narrow:
/// - Only the three browse reads fall back. A successful-but-empty live response
///   is a real result and is returned as-is (no fallback).
/// - Writes, "my businesses", memories and uploads always go to live and
///   surface real errors — we never fake a write or hide a failure there.
final class FallbackBusinessRepository: BusinessRepository, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.san-fo.app", category: "fallback")

    private let live: BusinessRepository
    private let sample: BusinessRepository

    init(live: BusinessRepository, sample: BusinessRepository) {
        self.live = live
        self.sample = sample
    }

    func recommended(for profile: UserProfile?) async throws -> [Business] {
        do {
            return try await live.recommended(for: profile)
        } catch {
            Self.logFallback("recommended", error)
            return try await sample.recommended(for: profile)
        }
    }

    func list(query: BusinessQuery) async throws -> [Business] {
        do {
            return try await live.list(query: query)
        } catch {
            Self.logFallback("list", error)
            return try await sample.list(query: query)
        }
    }

    func detail(id: String) async throws -> BusinessDetail {
        do {
            return try await live.detail(id: id)
        } catch {
            Self.logFallback("detail", error)
            return try await sample.detail(id: id)
        }
    }

    // MARK: - Live-only (no fallback)

    func myBusinesses() async throws -> [Business] {
        try await live.myBusinesses()
    }

    func updateBusiness(id: String, description: String) async throws -> BusinessDetail {
        try await live.updateBusiness(id: id, description: description)
    }

    func addMemory(businessId: String, author: String, text: String) async throws -> CommunityMemory {
        try await live.addMemory(businessId: businessId, author: author, text: text)
    }

    func uploadPhoto(_ jpeg: Data) async throws -> String {
        try await live.uploadPhoto(jpeg)
    }

    private static func logFallback(_ op: String, _ error: Error) {
        MockMarker.hit(.mock, "FallbackBusinessRepository.\(op)", "live failed; using sample data")
        logger.warning("🟠 Live business \(op, privacy: .public) failed (\(String(describing: error), privacy: .public)) — falling back to sample data")
    }
}
