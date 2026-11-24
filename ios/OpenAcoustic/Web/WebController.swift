import SwiftUI
import WebKit

/// Owns one WKWebView set up for the bundled pages: the `app://` scheme, Web MIDI, no network,
/// JS dialogs, downloads (shared via the share sheet) and external links (opened in Safari).
final class WebController: NSObject, ObservableObject {
    let webView: SizedWebView
    private let bridge = WebMIDIBridge()
    private var pendingURL: URL?
    private var rulesReady = false
    fileprivate var downloads: [ObjectIdentifier: URL] = [:]   // download → file it's written to
    /// The page's own background colour, so the safe-area margins around the web view blend in.
    @Published private(set) var pageBackground = UIColor.black

    /// Page size like a browser's zoom: the page is laid out for a viewport of (view width ÷ zoom) CSS pixels
    /// and scaled to fit, so it reflows and always fills the screen. 1 = 100 %.
    var zoom: Double = 1 {
        didSet {
            guard zoom != oldValue else { return }
            installUserScripts()      // later page loads start at the new size
            applyZoom()               // and the current page changes now
        }
    }

    init(url: URL, zoom: Double = 1) {
        self.zoom = zoom
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(AppSchemeHandler(), forURLScheme: AppSchemeHandler.scheme)
        config.websiteDataStore = .default()                      // keep localStorage (saved ports, checklists)
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        bridge.install(into: config)

        webView = SizedWebView(frame: .zero, configuration: config)
        super.init()
        installUserScripts()
        webView.onWidthChange = { [weak self] _ in self?.applyZoom() }   // rotation, split view
        bridge.webView = webView
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.allowsBackForwardNavigationGestures = false      // an edge swipe on stage must not leave the page
        if #available(iOS 16.4, *) { webView.isInspectable = true }   // Safari ▸ Develop, for debugging on a device

        pendingURL = url
        Self.offlineRules { [weak self] rules in
            guard let self else { return }
            if let rules { self.webView.configuration.userContentController.add(rules) }
            self.rulesReady = true
            if let u = self.pendingURL { self.pendingURL = nil; self.webView.load(URLRequest(url: u)) }
        }
    }

    func load(_ url: URL) {
        if rulesReady { webView.load(URLRequest(url: url)) } else { pendingURL = url }
    }

    func reload() { webView.reload() }

    private static let pageShim: String? = Bundle.main.url(forResource: "AppPageShim", withExtension: "js")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }

    /// The Web MIDI shim (document start), the current zoom (document start) and the page tweaks (document end).
    private func installUserScripts() {
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        if let midi = WebMIDIBridge.userScript { ucc.addUserScript(midi) }
        ucc.addUserScript(WKUserScript(source: "window.__oaZoom = \(zoom);", injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .page))
        if let src = Self.pageShim {
            ucc.addUserScript(WKUserScript(source: src, injectionTime: .atDocumentEnd, forMainFrameOnly: false, in: .page))
        }
    }

    /// Re-applies the zoom to the current page with the exact width of the web view.
    fileprivate func applyZoom() {
        let width = webView.bounds.width
        webView.evaluateJavaScript("window.__oaZoom = \(zoom); window.__oaApplyZoom && window.__oaApplyZoom(\(zoom), \(width)); 0")
    }

    /// Reads the page's background colour (body, else html) once it has loaded.
    fileprivate func updatePageBackground() {
        let js = """
            (() => { const bg = e => e ? getComputedStyle(e).backgroundColor : "";
              const ok = c => c && c !== "transparent" && !/^rgba\\(.*,\\s*0\\)$/.test(c);
              const b = bg(document.body), h = bg(document.documentElement); return ok(b) ? b : ok(h) ? h : ""; })()
            """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self, let css = result as? String, let color = Self.color(fromCSS: css) else { return }
            self.pageBackground = color
            self.webView.backgroundColor = color
            self.webView.scrollView.backgroundColor = color
        }
    }

    /// Parses `rgb(r, g, b)` / `rgba(r, g, b, a)` as returned by getComputedStyle.
    static func color(fromCSS css: String) -> UIColor? {
        let parts = css.drop(while: { $0 != "(" }).dropFirst().prefix(while: { $0 != ")" })
            .split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 3, let r = parts[0], let g = parts[1], let b = parts[2] else { return nil }
        let a = parts.count > 3 ? (parts[3] ?? 1) : 1
        guard a > 0 else { return nil }
        return UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    /// Blocks every http(s) subresource. The pages are bundled; the one remote reference (a web font on
    /// pa-remote.html) is replaced by a bundled copy, and a render-blocking stylesheet request must not
    /// stall the page on a network without internet.
    private static func offlineRules(_ done: @escaping (WKContentRuleList?) -> Void) {
        let json = #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "open-acoustic-offline", encodedContentRuleList: json) { list, error in
            if let error { NSLog("Open Acoustic: content rules failed: \(error)") }
            DispatchQueue.main.async { done(list) }
        }
    }

    fileprivate var presenter: UIViewController? {
        var vc = webView.window?.rootViewController
        while let next = vc?.presentedViewController { vc = next }
        return vc
    }
}

// MARK: - Navigation

extension WebController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if #available(iOS 14.5, *), action.shouldPerformDownload { return decisionHandler(.download) }
        guard let url = action.request.url, let scheme = url.scheme?.lowercased() else { return decisionHandler(.cancel) }
        switch scheme {
        case AppSchemeHandler.scheme, "about", "blob", "data":
            decisionHandler(.allow)
        default:
            // Links to the web (docs, GitHub) open in Safari; the app itself stays offline.
            if action.targetFrame?.isMainFrame ?? true, UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if #available(iOS 14.5, *), !response.canShowMIMEType { return decisionHandler(.download) }
        decisionHandler(.allow)
    }

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        bridge.reset()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyZoom()
        updatePageBackground()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - Downloads (verify.html exports its checklist as a file)

@available(iOS 14.5, *)
extension WebController: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = suggestedFilename.isEmpty ? "download" : suggestedFilename
        let file = dir.appendingPathComponent(name)
        downloads[ObjectIdentifier(download)] = file
        completionHandler(file)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let file = downloads.removeValue(forKey: ObjectIdentifier(download)), let presenter else { return }
        let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = webView
        share.popoverPresentationController?.sourceRect = CGRect(x: webView.bounds.midX, y: webView.bounds.midY, width: 1, height: 1)
        presenter.present(share, animated: true)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloads[ObjectIdentifier(download)] = nil
    }
}

// MARK: - JS dialogs and window.open

extension WebController: WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, orElse: completionHandler)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert) { completionHandler(false) }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in completionHandler(alert?.textFields?.first?.text) })
        present(alert) { completionHandler(nil) }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // target=_blank / window.open: open in place (or in Safari, via the navigation policy).
        if action.targetFrame == nil { webView.load(action.request) }
        return nil
    }

    private func present(_ alert: UIAlertController, orElse fallback: @escaping () -> Void) {
        guard let presenter else { return fallback() }
        presenter.present(alert, animated: true)
    }
}

// MARK: - SwiftUI

/// A WKWebView that reports when its width changes, so the page size can follow rotation.
final class SizedWebView: WKWebView {
    var onWidthChange: ((CGFloat) -> Void)?
    private var lastWidth: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width > 0, bounds.width != lastWidth {
            lastWidth = bounds.width
            onWidthChange?(bounds.width)
        }
    }
}

struct WebContainer: UIViewRepresentable {
    let controller: WebController
    func makeUIView(context: Context) -> WKWebView { controller.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
