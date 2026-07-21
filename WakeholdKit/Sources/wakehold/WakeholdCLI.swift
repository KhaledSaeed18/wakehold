import Foundation
import WakeholdKit

@main
struct WakeholdCLI {
    static func main() {
        // WAKEHOLD_SOCKET overrides the default path, for tests and custom setups.
        let path = ProcessInfo.processInfo.environment["WAKEHOLD_SOCKET"] ?? WakeholdPaths.socket()
        let client = ControlClient(path: path)
        do {
            try run(Array(CommandLine.arguments.dropFirst()), client: client)
        } catch let error as CLIError {
            fail(error.text)
        } catch let error as WakeholdError {
            fail(describe(error))
        } catch {
            fail(String(describing: error))
        }
    }

    static func run(_ args: [String], client: ControlClient) throws {
        guard let command = args.first else {
            printUsage()
            exit(2)
        }
        switch command {
        case "status":
            printStatus(try client.status())
        case "off":
            try client.off()
            print("Released endpoint sessions.")
        case "hook":
            guard args.count >= 2 else { throw CLIError.usage("hook needs start, renew, or end") }
            try hook(args[1], client: client)
        case "--keep":
            guard args.count >= 2 else { throw CLIError.usage("--keep needs a pid or :port") }
            try keep(args[1], client: client)
        case "--":
            let rest = Array(args.dropFirst())
            guard !rest.isEmpty else { throw CLIError.usage("-- needs a command") }
            try runCommand(rest, client: client)
        case "-h", "--help":
            printUsage()
        default:
            printUsage()
            exit(2)
        }
    }

    static func keep(_ target: String, client: ControlClient) throws {
        if target.hasPrefix(":") {
            guard let port = UInt16(target.dropFirst()) else {
                throw CLIError.usage("not a valid port: \(target)")
            }
            print(try client.startPort(port, label: target).uuidString)
        } else {
            guard let pid = Int32(target) else {
                throw CLIError.usage("not a valid pid: \(target)")
            }
            print(try client.startProcess(pid: pid, label: "pid \(pid)").uuidString)
        }
    }

    // Hold awake while the command runs. We open a process session on our own pid, so the app
    // releases even if this wrapper is killed, then run the command to completion.
    static func runCommand(_ command: [String], client: ControlClient) throws {
        let id = try client.startProcess(pid: ProcessInfo.processInfo.processIdentifier,
                                         label: command.joined(separator: " "))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        do {
            try process.run()
        } catch {
            try? client.end(id)
            throw CLIError.failure("cannot run \(command[0]): \(error.localizedDescription)")
        }
        process.waitUntilExit()
        try? client.end(id)
        exit(process.terminationStatus)
    }

    // Agent hook lifecycle: read the tool's event JSON on stdin and key the lease by the agent's
    // own session id, so renew and end find the lease start opened. A missing endpoint is not an
    // error: a hook must never break the agent, so an unreachable Wakehold just exits quietly.
    static func hook(_ action: String, client: ControlClient) throws {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        let json = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] ?? [:]
        guard let key = firstString(json, ["session_id", "sessionId", "session", "id"]) else {
            throw CLIError.failure("no session id in hook input")
        }
        do {
            switch action {
            case "start":
                let cwd = firstString(json, ["cwd", "workingDirectory", "working_dir", "project_dir"])
                let label = cwd.map { ($0 as NSString).lastPathComponent } ?? "agent"
                let ttl = TimeInterval(ProcessInfo.processInfo.environment["WAKEHOLD_TTL"] ?? "") ?? 900
                _ = try client.startAgent(key: key, label: label, ttl: ttl)
            case "renew":
                try client.renew(key: key)
            case "end":
                try client.end(key: key)
            default:
                throw CLIError.usage("hook needs start, renew, or end")
            }
        } catch WakeholdError.endpointUnreachable {
            // Wakehold is not running; a hook stays out of the way.
        }
    }

    static func firstString(_ json: [String: Any], _ keys: [String]) -> String? {
        for key in keys {
            if let value = json[key] as? String, !value.isEmpty { return value }
        }
        return nil
    }

    static func printStatus(_ status: StatusResponse) {
        guard !status.sessions.isEmpty else {
            print("Nothing's keeping you awake.")
            return
        }
        print(status.awake ? "Awake" : "Idle")
        for session in status.sessions {
            print("  \(session.kind): \(session.label)\(session.active ? "" : " (inactive)")")
        }
    }

    static func printUsage() {
        print("""
        wakehold: hold your Mac awake while work is alive

        usage:
          wakehold -- <command>      run a command, release when it exits
          wakehold --keep <pid>      hold while a process is alive
          wakehold --keep :<port>    hold while something listens on a port
          wakehold status            show what is holding the Mac awake
          wakehold off               release sessions opened over the endpoint
          wakehold hook <phase>      agent hook lifecycle (start/renew/end), reads stdin JSON
        """)
    }

    static func describe(_ error: WakeholdError) -> String {
        switch error {
        case .endpointUnreachable: "cannot reach Wakehold. Is the app running?"
        case .controlError(_, let message): message
        case .assertionFailed(let code): "assertion failed (\(code))"
        case .endpointFailed(let step): "endpoint \(step) failed"
        }
    }

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("wakehold: \(message)\n".utf8))
        exit(1)
    }
}

enum CLIError: Error {
    case usage(String)
    case failure(String)

    var text: String {
        switch self {
        case .usage(let message), .failure(let message): message
        }
    }
}
