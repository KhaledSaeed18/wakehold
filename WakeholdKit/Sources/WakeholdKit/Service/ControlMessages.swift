import Foundation

// Wire contract for the control endpoint. Kept trivial and stable: hook scripts and the CLI both
// speak this JSON.

struct StartRequest: Decodable {
    let kind: String
    let label: String?
    let ttl: TimeInterval?
    let pid: Int32?
    let port: Int?
}

struct IDRequest: Decodable {
    let id: String
}

struct IDResponse: Codable {
    let id: String
}

struct OKResponse: Codable {
    let ok: Bool
}

struct ErrorResponse: Codable {
    let error: String
}

public struct StatusResponse: Codable {
    public let awake: Bool
    public let sessions: [SessionInfo]
}

public struct SessionInfo: Codable {
    public let id: String
    public let label: String
    public let kind: String
    public let active: Bool
}
