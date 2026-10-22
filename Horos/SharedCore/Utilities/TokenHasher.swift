import Foundation

/// Produces a process-stable identifier for opaque Screen Time tokens.
/// `Hashable.hashValue` is randomly seeded per process, so it cannot be used to
/// correlate an `ApplicationToken` seen by the ShieldAction extension with one
/// stored by the main app. Encoding the token and hashing the bytes (FNV-1a 64)
/// yields a stable key without exposing the bundle identifier.
enum TokenHasher {
    static func stableHash<Token: Encodable>(_ token: Token) -> String {
        guard let data = try? JSONEncoder().encode(token) else { return "unknown" }
        return fnv1a(data)
    }

    static func fnv1a(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16, uppercase: false)
    }
}
