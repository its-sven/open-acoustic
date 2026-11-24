import UniformTypeIdentifiers
import WebKit

/// Serves the bundled web files over `app://open-acoustic/…`.
///
/// A custom scheme instead of `file://` gives the pages a real origin, so relative links, `localStorage`,
/// `fetch` and script loading behave as on a web server. Nothing is fetched from the network.
///
/// - `app://open-acoustic/<path>` → `<bundle>/web/<path>` (a copy of upstream `tools/`, made at build time)
/// - `app://open-acoustic/_app/<file>` → a few app-owned resources (the LCD font)
final class AppSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "app"
    static let host = "open-acoustic"

    static func url(for path: String) -> URL {
        URL(string: "\(scheme)://\(host)/\(path)")!
    }

    /// Resources the pages may load from `/_app/`.
    private static let appResources: Set<String> = ["Silkscreen-Regular.ttf"]

    private let webRoot: URL

    init(webRoot: URL = Bundle.main.resourceURL!.appendingPathComponent("web", isDirectory: true)) {
        self.webRoot = webRoot.standardizedFileURL
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, url.host == Self.host else { return fail(task, 400) }
        let path = url.path

        let file: URL?
        if path.hasPrefix("/_app/") {
            let name = String(path.dropFirst("/_app/".count))
            file = Self.appResources.contains(name) ? Bundle.main.url(forResource: name, withExtension: nil) : nil
        } else {
            var candidate = webRoot.appendingPathComponent(String(path.drop(while: { $0 == "/" }))).standardizedFileURL
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                candidate.appendPathComponent("index.html")
            }
            // never serve anything outside the web root (no ../ escapes)
            file = candidate.path.hasPrefix(webRoot.path + "/") ? candidate : nil
        }

        guard let file, let data = try? Data(contentsOf: file) else { return fail(task, 404) }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Type": Self.mimeType(for: file),
            "Content-Length": String(data.count),
            "Cache-Control": "no-cache",
        ])!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        // Responses are produced synchronously in start; nothing to cancel.
    }

    private func fail(_ task: WKURLSchemeTask, _ status: Int) {
        guard let url = task.request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                             headerFields: ["Content-Type": "text/plain; charset=utf-8"]) else {
            task.didFailWithError(URLError(.badURL)); return
        }
        task.didReceive(response)
        task.didReceive(Data("\(status) \(url.path)".utf8))
        task.didFinish()
    }

    static func mimeType(for file: URL) -> String {
        switch file.pathExtension.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "md", "txt": return "text/plain; charset=utf-8"
        case "svg": return "image/svg+xml"
        case "ttf": return "font/ttf"
        default: return UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        }
    }
}
