import Foundation

/// Uploads images and returns the hosted URL string the backend stores in
/// `galleryImageUrls`.
///
/// This is the single seam for image hosting. Today there is no upload
/// endpoint, so `LiveImageUploader` encodes the bytes as a `data:` URL (the
/// backend accepts arbitrary strings). When the real endpoint lands, only the
/// `upload(_:)` body below changes — call sites stay the same.
protocol ImageUploader: Sendable {
    /// Uploads a single JPEG and returns the URL the backend should persist.
    func upload(_ jpeg: Data) async throws -> String
}

extension ImageUploader {
    /// Uploads many images, preserving order.
    func upload(_ jpegs: [Data]) async throws -> [String] {
        var urls: [String] = []
        urls.reserveCapacity(jpegs.count)
        for jpeg in jpegs {
            urls.append(try await upload(jpeg))
        }
        return urls
    }
}

/// Live uploader.
///
/// NO_BACKEND: there is no image-upload endpoint yet, so the bytes are embedded
/// as a base64 `data:` URL. TODO(API): replace the body of `upload(_:)` with a
/// real multipart / pre-signed-URL request via `client` — nothing else needs
/// to change.
final class LiveImageUploader: ImageUploader, @unchecked Sendable {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func upload(_ jpeg: Data) async throws -> String {
        MockMarker.hit(.noBackend, "LiveImageUploader.upload", "no upload endpoint; using data URL")
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }
}

/// ⚠️ MOCK — returns a stable fake URL without hosting anything.
/// Active only when `APIConfiguration.useMockData == true`.
final class MockImageUploader: ImageUploader, @unchecked Sendable {
    func upload(_ jpeg: Data) async throws -> String {
        MockMarker.hit(.mock, "MockImageUploader.upload", "fake URL; nothing hosted")
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }
}
