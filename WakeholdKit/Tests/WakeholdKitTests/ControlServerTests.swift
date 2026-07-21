import Testing
import Foundation
import Darwin
@testable import WakeholdKit

@MainActor
struct ControlServerTests {
    @Test func startsSessionAndReportsStatusOverSocket() async throws {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        let path = socketPath()
        let server = ControlServer(path: path, wake: wake, registry: registry)
        try server.start()
        defer { server.stop() }

        // Run the blocking client off the main actor so the server's hop to main can proceed.
        let start = try await Task.detached {
            try sendUnixHTTP(path: path, method: "POST", uri: "/session/start",
                             body: #"{"kind":"agent","label":"claude-code","ttl":600}"#)
        }.value
        #expect(start.contains("200 OK"))
        #expect(start.contains("\"id\""))
        #expect(wake.isAwake)
        #expect(wake.isHoldingAssertion)

        let status = try await Task.detached {
            try sendUnixHTTP(path: path, method: "GET", uri: "/status", body: nil)
        }.value
        #expect(status.contains("200 OK"))
        #expect(status.contains("claude-code"))
        #expect(status.contains("\"awake\":true"))
    }

    @Test func rejectsUnknownPath() async throws {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        let path = socketPath()
        let server = ControlServer(path: path, wake: wake, registry: registry)
        try server.start()
        defer { server.stop() }

        let response = try await Task.detached {
            try sendUnixHTTP(path: path, method: "GET", uri: "/nope", body: nil)
        }.value
        #expect(response.contains("404"))
    }

    // The real hook scenario: a curl one-liner over --unix-socket.
    @Test func respondsToCurlOverUnixSocket() async throws {
        let wake = WakeController()
        let registry = SessionRegistry(wake: wake)
        let path = socketPath()
        let server = ControlServer(path: path, wake: wake, registry: registry)
        try server.start()
        defer { server.stop() }

        let output = try await Task.detached {
            try runCurl(["--unix-socket", path, "-s", "-X", "POST",
                         "http://localhost/session/start",
                         "-H", "Content-Type: application/json",
                         "-d", #"{"kind":"agent","label":"hook","ttl":600}"#])
        }.value
        #expect(output.contains("\"id\""))
        #expect(wake.isAwake)
    }
}

// Runs curl and returns its stdout.
private func runCurl(_ args: [String]) throws -> String {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
    proc.arguments = args
    let out = Pipe()
    proc.standardOutput = out
    proc.standardError = Pipe()
    try proc.run()
    proc.waitUntilExit()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

private func socketPath() -> String {
    "/tmp/wh-\(UUID().uuidString.prefix(8)).sock"
}

// Minimal blocking UDS HTTP client for tests.
private func sendUnixHTTP(path: String, method: String, uri: String, body: String?) throws -> String {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw POSIXError(.ECONNREFUSED) }
    defer { close(fd) }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let capacity = MemoryLayout.size(ofValue: addr.sun_path)
    path.withCString { cstr in
        withUnsafeMutablePointer(to: &addr.sun_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: capacity) {
                _ = strncpy($0, cstr, capacity - 1)
            }
        }
    }
    let connected = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard connected == 0 else { throw POSIXError(.ECONNREFUSED) }

    let bodyData = body.map { Data($0.utf8) } ?? Data()
    let head = "\(method) \(uri) HTTP/1.1\r\nHost: wakehold\r\n"
        + "Content-Type: application/json\r\nContent-Length: \(bodyData.count)\r\nConnection: close\r\n\r\n"
    var request = Data(head.utf8)
    request.append(bodyData)
    _ = request.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }

    var response = Data()
    var chunk = [UInt8](repeating: 0, count: 4096)
    while true {
        let n = read(fd, &chunk, chunk.count)
        guard n > 0 else { break }
        response.append(contentsOf: chunk[0..<n])
    }
    return String(data: response, encoding: .utf8) ?? ""
}
