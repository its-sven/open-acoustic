import WebKit

/// Connects the page-side Web MIDI implementation (`WebMIDIShim.js`) to `MIDIManager`.
///
/// JS → Swift: `webkit.messageHandlers.oaMIDIAccess` (with reply: `requestMIDIAccess`) and
/// `webkit.messageHandlers.oaMIDI` (fire-and-forget: send, clear, open, close).
/// Swift → JS: `window.__oaMIDI.deliver(…)` / `.ports(…)`, evaluated in every frame that asked for access.
/// Message bytes travel as JSON number arrays to Swift and as Base64 to JS.
final class WebMIDIBridge: NSObject, WKScriptMessageHandler, WKScriptMessageHandlerWithReply {
    weak var webView: WKWebView?
    private let midi: MIDIManager
    private var frames: [String: WKFrameInfo] = [:]   // shim frame token → frame
    private var tokens: [UUID] = []

    init(midi: MIDIManager = .shared) {
        self.midi = midi
        super.init()
        tokens.append(midi.addMessageListener { [weak self] in self?.deliver($0) })
        tokens.append(midi.addPortListener { [weak self] in self?.portsChanged($0) })
    }

    deinit {
        let midi = self.midi, tokens = self.tokens
        DispatchQueue.main.async { tokens.forEach(midi.removeListener) }
    }

    /// Adds the message handlers and the shim (at document start, all frames, page world).
    func install(into config: WKWebViewConfiguration) {
        let ucc = config.userContentController
        ucc.addScriptMessageHandler(self, contentWorld: .page, name: "oaMIDIAccess")
        ucc.add(self, contentWorld: .page, name: "oaMIDI")
        if let url = Bundle.main.url(forResource: "WebMIDIShim", withExtension: "js"), let src = try? String(contentsOf: url, encoding: .utf8) {
            ucc.addUserScript(WKUserScript(source: src, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .page))
        } else {
            assertionFailure("WebMIDIShim.js missing from the bundle")
        }
    }

    /// The main frame navigated: every frame's MIDIAccess is gone.
    func reset() {
        frames.removeAll()
    }

    // MARK: JS → Swift

    private static func isTrusted(_ message: WKScriptMessage) -> Bool {
        // Only the bundled pages get MIDI.
        message.frameInfo.securityOrigin.protocol == AppSchemeHandler.scheme
            && message.frameInfo.securityOrigin.host == AppSchemeHandler.host
    }

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard Self.isTrusted(message) else { return replyHandler(nil, "MIDI is only available to the app's own pages") }
        guard let body = message.body as? [String: Any], body["op"] as? String == "requestAccess",
              let frame = body["frame"] as? String else { return replyHandler(nil, "bad request") }
        if let error = midi.setupError { return replyHandler(["error": error], nil) }
        frames[frame] = message.frameInfo
        replyHandler(["now": HostClock.nowMs, "ports": Self.jsonObject(midi.ports)], nil)
    }

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard Self.isTrusted(message), let body = message.body as? [String: Any],
              let op = body["op"] as? String, let port = body["port"] as? String else { return }
        switch op {
        case "send":
            guard let raw = body["data"] as? [Any] else { return }
            var bytes = [UInt8](); bytes.reserveCapacity(raw.count)
            for v in raw {
                guard let n = (v as? NSNumber)?.intValue, (0...255).contains(n) else { return }
                bytes.append(UInt8(n))
            }
            midi.send(bytes, to: port, atHostMs: (body["at"] as? NSNumber)?.doubleValue)
        case "clear":
            midi.clear(portID: port)
        default:
            break   // open/close: inputs are always listened to; the shim filters by connection state
        }
    }

    // MARK: Swift → JS

    private func deliver(_ batch: [ReceivedMIDIMessage]) {
        guard !frames.isEmpty else { return }
        let items: [[Any]] = batch.map { [$0.portID, $0.hostMs, Data($0.bytes).base64EncodedString()] }
        guard let json = try? JSONSerialization.data(withJSONObject: items), let s = String(data: json, encoding: .utf8) else { return }
        evaluate("window.__oaMIDI && window.__oaMIDI.deliver(\(s))")
    }

    private func portsChanged(_ ports: [MIDIPortInfo]) {
        guard !frames.isEmpty, let data = try? JSONEncoder().encode(ports), let s = String(data: data, encoding: .utf8) else { return }
        evaluate("window.__oaMIDI && window.__oaMIDI.ports(\(s))")
    }

    private func evaluate(_ js: String) {
        guard let webView else { return }
        for (token, frame) in frames {
            webView.evaluateJavaScript(js + "; 0", in: frame, in: .page) { [weak self] result in
                // the frame went away: stop sending to it (other errors are left alone)
                if case .failure(let error) = result, (error as? WKError)?.code == .javaScriptInvalidFrameTarget {
                    self?.frames[token] = nil
                }
            }
        }
    }

    private static func jsonObject<T: Encodable>(_ value: T) -> Any {
        guard let data = try? JSONEncoder().encode(value), let obj = try? JSONSerialization.jsonObject(with: data) else { return [] }
        return obj
    }
}
