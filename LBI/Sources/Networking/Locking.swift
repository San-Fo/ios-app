import Foundation
import os

/// A small mutual-exclusion helper for the in-memory mock repositories.
///
/// `withLock` runs its body while holding the lock and returns synchronously,
/// which avoids the "instance method 'lock' is unavailable from asynchronous
/// contexts" warning that arises from calling `NSLock.lock()`/`unlock()`
/// directly inside `async` functions. Backed by `os_unfair_lock`.
final class Mutex: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock()

    /// Run `body` while holding the lock and return its result.
    func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    /// Throwing variant of `withLock`.
    func withLock<T>(_ body: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
