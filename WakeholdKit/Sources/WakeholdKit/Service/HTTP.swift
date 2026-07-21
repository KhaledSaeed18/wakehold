import Foundation

// Minimal HTTP/1.1 for the control endpoint: just enough to read a curl request and write a JSON
// response, one request per connection. Not a general HTTP server.
enum HTTP {
    // Returns a Request once the buffer holds a complete request (headers plus a Content-Length
    // body), or nil if more bytes are still needed.
    static func parse(_ data: Data) -> Request? {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator) else { return nil }
        guard let header = String(data: Data(data[data.startIndex..<range.lowerBound]), encoding: .utf8),
              let requestLine = header.components(separatedBy: "\r\n").first else {
            return nil
        }
        let fields = requestLine.split(separator: " ")
        guard fields.count >= 2 else { return nil }

        var contentLength = 0
        for line in header.components(separatedBy: "\r\n").dropFirst()
        where line.lowercased().hasPrefix("content-length:") {
            let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
            contentLength = Int(value) ?? 0
        }

        let bodyStart = range.upperBound
        guard data.distance(from: bodyStart, to: data.endIndex) >= contentLength else { return nil }
        let bodyEnd = data.index(bodyStart, offsetBy: contentLength)
        return Request(method: String(fields[0]), path: String(fields[1]), body: Data(data[bodyStart..<bodyEnd]))
    }

    static func serialize(_ response: Response) -> Data {
        let head = "HTTP/1.1 \(response.status) \(reason(response.status))\r\n"
            + "Content-Type: application/json\r\n"
            + "Content-Length: \(response.body.count)\r\n"
            + "Connection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(response.body)
        return data
    }

    private static func reason(_ status: Int) -> String {
        switch status {
        case 200: "OK"
        case 400: "Bad Request"
        case 404: "Not Found"
        default: "Error"
        }
    }
}
