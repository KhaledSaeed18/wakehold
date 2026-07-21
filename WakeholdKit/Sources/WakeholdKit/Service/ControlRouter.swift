import Foundation

// A parsed request and the response to write back, independent of the HTTP/socket transport so
// the routing logic can be tested without a socket.
struct Request {
    let method: String
    let path: String
    let body: Data
}

struct Response {
    let status: Int
    let body: Data
}

extension Response {
    static func json<T: Encodable>(_ status: Int, _ value: T) -> Response {
        Response(status: status, body: (try? JSONEncoder().encode(value)) ?? Data())
    }
    static func id(_ id: UUID) -> Response { json(200, IDResponse(id: id.uuidString)) }
    static func ok() -> Response { json(200, OKResponse(ok: true)) }
    static func error(_ status: Int, _ message: String) -> Response { json(status, ErrorResponse(error: message)) }
}

// Maps control-endpoint requests to registry actions. The one place that knows the wire contract;
// the server below only moves bytes.
@MainActor
final class ControlRouter {
    private let wake: WakeController
    private let registry: SessionRegistry

    init(wake: WakeController, registry: SessionRegistry) {
        self.wake = wake
        self.registry = registry
    }

    func handle(_ request: Request) -> Response {
        switch (request.method, request.path) {
        case ("POST", "/session/start"): return start(request.body)
        case ("POST", "/session/renew"): return renew(request.body)
        case ("POST", "/session/end"): return end(request.body)
        case ("GET", "/status"): return status()
        default: return .error(404, "not found")
        }
    }

    private func start(_ body: Data) -> Response {
        guard let req = try? JSONDecoder().decode(StartRequest.self, from: body) else {
            return .error(400, "invalid request body")
        }
        switch req.kind {
        case "agent":
            return .id(registry.startAgent(label: req.label ?? "agent", ttl: req.ttl ?? 600))
        case "process":
            guard let pid = req.pid else { return .error(400, "process requires pid") }
            guard let id = registry.startProcess(pid: pid, label: req.label ?? "pid \(pid)") else {
                return .error(400, "no such process")
            }
            return .id(id)
        case "port":
            guard let portValue = req.port, (1...65535).contains(portValue) else {
                return .error(400, "port requires a valid port")
            }
            let port = UInt16(portValue)
            return .id(registry.startPort(port, label: req.label ?? ":\(port)"))
        default:
            return .error(400, "unknown kind")
        }
    }

    private func renew(_ body: Data) -> Response {
        guard let id = decodeID(body) else { return .error(400, "invalid request body") }
        return registry.renew(id) ? .ok() : .error(404, "unknown session")
    }

    private func end(_ body: Data) -> Response {
        guard let id = decodeID(body) else { return .error(400, "invalid request body") }
        registry.end(id)
        return .ok()
    }

    private func status() -> Response {
        let sessions = wake.sessions.map {
            SessionInfo(id: $0.id.uuidString, label: $0.label, kind: $0.kind.name, active: $0.isActive)
        }
        return .json(200, StatusResponse(awake: wake.isAwake, sessions: sessions))
    }

    private func decodeID(_ body: Data) -> UUID? {
        guard let req = try? JSONDecoder().decode(IDRequest.self, from: body) else { return nil }
        return UUID(uuidString: req.id)
    }
}
