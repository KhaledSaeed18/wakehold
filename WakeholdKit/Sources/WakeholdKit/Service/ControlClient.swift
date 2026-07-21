import Foundation
import Darwin

// A thin client for the control endpoint over the Unix domain socket. The CLI is built on this;
// hook scripts use curl against the same contract.
public final class ControlClient {
    private let path: String

    public init(path: String) {
        self.path = path
    }

    public func startProcess(pid: Int32, label: String) throws -> UUID {
        try startSession(["kind": "process", "pid": Int(pid), "label": label])
    }

    public func startPort(_ port: UInt16, label: String) throws -> UUID {
        try startSession(["kind": "port", "port": Int(port), "label": label])
    }

    public func startAgent(key: String? = nil, label: String, ttl: TimeInterval) throws -> UUID {
        var json: [String: Any] = ["kind": "agent", "label": label, "ttl": ttl]
        if let key { json["key"] = key }
        return try startSession(json)
    }

    public func renew(_ id: UUID) throws {
        _ = try send("POST", "/session/renew", json: ["id": id.uuidString])
    }

    public func renew(key: String) throws {
        _ = try send("POST", "/session/renew", json: ["key": key])
    }

    public func end(_ id: UUID) throws {
        _ = try send("POST", "/session/end", json: ["id": id.uuidString])
    }

    public func end(key: String) throws {
        _ = try send("POST", "/session/end", json: ["key": key])
    }

    public func off() throws {
        _ = try send("POST", "/off", body: Data())
    }

    public func status() throws -> StatusResponse {
        let (_, body) = try send("GET", "/status", body: Data())
        guard let status = try? JSONDecoder().decode(StatusResponse.self, from: body) else {
            throw WakeholdError.controlError(status: 0, message: "malformed status response")
        }
        return status
    }

    private func startSession(_ json: [String: Any]) throws -> UUID {
        let (_, body) = try send("POST", "/session/start", json: json)
        guard let decoded = try? JSONDecoder().decode(IDResponse.self, from: body),
              let id = UUID(uuidString: decoded.id) else {
            throw WakeholdError.controlError(status: 0, message: "malformed start response")
        }
        return id
    }

    private func send(_ method: String, _ uri: String, json: [String: Any]) throws -> (Int, Data) {
        try send(method, uri, body: try JSONSerialization.data(withJSONObject: json))
    }

    private func send(_ method: String, _ uri: String, body: Data) throws -> (Int, Data) {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw WakeholdError.endpointUnreachable }
        defer { close(fd) }

        var addr = unixSocketAddress(path: path)
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { throw WakeholdError.endpointUnreachable }

        let head = "\(method) \(uri) HTTP/1.1\r\nHost: wakehold\r\n"
            + "Content-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var request = Data(head.utf8)
        request.append(body)
        writeAll(fd, request)

        let (status, responseBody) = parseHTTPResponse(readToEnd(fd))
        guard (200...299).contains(status) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: responseBody))?.error ?? "request failed"
            throw WakeholdError.controlError(status: status, message: message)
        }
        return (status, responseBody)
    }
}

// Split an HTTP response into (status, body).
private func parseHTTPResponse(_ data: Data) -> (Int, Data) {
    guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else { return (0, Data()) }
    let header = String(data: Data(data[data.startIndex..<separator.lowerBound]), encoding: .utf8) ?? ""
    let statusLine = header.components(separatedBy: "\r\n").first ?? ""
    let fields = statusLine.split(separator: " ")
    let status = fields.count >= 2 ? Int(fields[1]) ?? 0 : 0
    return (status, Data(data[separator.upperBound...]))
}
