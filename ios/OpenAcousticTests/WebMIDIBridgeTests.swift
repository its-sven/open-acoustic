import CoreMIDI
import WebKit
import XCTest
@testable import OpenAcoustic

/// Runs the whole path page JS → WebMIDIShim → Swift → CoreMIDI → (virtual loopback) → CoreMIDI → Swift → page JS,
/// in a real WKWebView, without hardware.
final class WebMIDIBridgeTests: XCTestCase {
    private static let loopbackName = "OA Loopback"
    private var window: UIWindow!
    private var controller: WebController!

    override func setUpWithError() throws {
        let status = MIDIManager.shared.createLoopback(name: Self.loopbackName)
        if status != noErr {
            MIDIManager.shared.removeLoopback()
            throw XCTSkip("CoreMIDI refused virtual endpoints here (\(status))")
        }
        // a page of the app's origin (a 404 is enough: the shim is injected into every page)
        controller = WebController(url: AppSchemeHandler.url(for: "__test__"))
        controller.webView.configuration.userContentController.add(UnplugHandler(), contentWorld: .page, name: "oaTest")
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        window.rootViewController = UIViewController()
        window.rootViewController!.view.addSubview(controller.webView)
        controller.webView.frame = window.bounds
        window.isHidden = false
        try waitForLoad()
    }

    override func tearDown() {
        MIDIManager.shared.removeLoopback()
        window?.isHidden = true
        window = nil
        controller = nil
    }

    private func waitForLoad() throws {
        let deadline = Date().addingTimeInterval(10)
        while controller.webView.isLoading || controller.webView.url == nil {
            if Date() > deadline { throw XCTSkip("page did not load") }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func run(_ js: String) throws -> Any? {
        let done = expectation(description: "js")
        var outcome: Result<Any, Error>!
        controller.webView.callAsyncJavaScript(js, arguments: ["name": Self.loopbackName], in: nil, in: .page) {
            outcome = $0; done.fulfill()
        }
        wait(for: [done], timeout: 15)
        return try outcome.get()
    }

    func testShimIsInstalledLikeANativeAPI() throws {
        let r = try run("""
            return [typeof navigator.requestMIDIAccess, Object.prototype.hasOwnProperty.call(Navigator.prototype, "requestMIDIAccess"),
                    typeof MIDIMessageEvent, typeof MIDIConnectionEvent, location.protocol]
            """) as? [Any]
        XCTAssertEqual(r?[0] as? String, "function")
        XCTAssertEqual(r?[1] as? Bool, true)
        XCTAssertEqual(r?[2] as? String, "function")
        XCTAssertEqual(r?[4] as? String, "app:")
    }

    func testLocalStorageWorksOnTheAppScheme() throws {
        let r = try run(#"localStorage.setItem("oa-test", "1"); const v = localStorage.getItem("oa-test"); localStorage.removeItem("oa-test"); return v"#)
        XCTAssertEqual(r as? String, "1")
    }

    func testRoundTripThroughCoreMIDI() throws {
        let r = try run("""
            const a = await navigator.requestMIDIAccess({ sysex: true });
            const out = [...a.outputs.values()].find(p => p.name === name);
            const inp = [...a.inputs.values()].find(p => p.name === name);
            if (!out || !inp) return { error: "loopback ports missing", ports: [...a.inputs.values(), ...a.outputs.values()].map(p => p.name) };
            const got = [];
            const big = [0xF0, 0x7D, ...Array.from({ length: 3000 }, (_, i) => i % 128), 0xF7];
            const all = new Promise(res => { inp.onmidimessage = e => { got.push(Array.from(e.data)); if (got.length === 4) res(); }; });
            out.send([0x90, 60, 100]);
            out.send([0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7]);
            out.send(big);
            out.send(new Uint8Array([0xC0, 5]));
            await Promise.race([all, new Promise(r => setTimeout(r, 8000))]);
            return { got, bigOK: JSON.stringify(got[2]) === JSON.stringify(big), inConn: inp.connection, outConn: out.connection,
                     sysexEnabled: a.sysexEnabled, type: inp.type, state: inp.state, hasId: !!inp.id };
            """) as? [String: Any]
        XCTAssertNil(r?["error"], "\(r ?? [:])")
        let got = r?["got"] as? [[Int]]
        XCTAssertEqual(got?.count, 4, "\(got ?? [])")
        XCTAssertEqual(got?.first, [0x90, 60, 100])
        XCTAssertEqual(got?[1], [0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7])
        XCTAssertEqual(r?["bigOK"] as? Bool, true, "a 3002-byte SysEx comes back intact and in order")
        XCTAssertEqual(got?.last, [0xC0, 5])
        XCTAssertEqual(r?["inConn"] as? String, "open")
        XCTAssertEqual(r?["outConn"] as? String, "open")
        XCTAssertEqual(r?["sysexEnabled"] as? Bool, true)
        XCTAssertEqual(r?["type"] as? String, "input")
        XCTAssertEqual(r?["state"] as? String, "connected")
    }

    func testSendValidation() throws {
        let r = try run("""
            const a = await navigator.requestMIDIAccess();
            const out = [...a.outputs.values()].find(p => p.name === name);
            const err = f => { try { f(); return "ok"; } catch (e) { return e.name; } };
            return [err(() => out.send([0x3C, 0x64])), err(() => out.send([0x90, 0x3C])), err(() => out.send([0x90, 300, 1])),
                    err(() => out.send([0xF0, 0x01, 0xF7])), err(() => out.send([0x90, 0x3C, 0x64, 0x80, 0x3C, 0x00]))];
            """) as? [String]
        XCTAssertEqual(r, ["TypeError", "TypeError", "TypeError", "InvalidAccessError", "ok"])
    }

    func testUnplugFiresStateChange() throws {
        let r = try run("""
            const a = await navigator.requestMIDIAccess({ sysex: true });
            const inp = [...a.inputs.values()].find(p => p.name === name);
            const events = [];
            a.onstatechange = e => events.push([e.port.name, e.port.type, e.port.state]);
            window.webkit.messageHandlers.oaTest.postMessage("unplug");
            await new Promise(r => setTimeout(r, 1500));
            return { events, stillListed: [...a.inputs.values()].some(p => p.name === name), state: inp.state };
            """) as? [String: Any]
        let events = r?["events"] as? [[String]] ?? []
        XCTAssertTrue(events.contains([Self.loopbackName, "input", "disconnected"]), "\(events)")
        XCTAssertTrue(events.contains([Self.loopbackName, "output", "disconnected"]), "\(events)")
        XCTAssertEqual(r?["stillListed"] as? Bool, false)
        XCTAssertEqual(r?["state"] as? String, "disconnected")
    }
}

/// Lets a test page "unplug" the loopback while its script waits.
private final class UnplugHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        MIDIManager.shared.removeLoopback()
    }
}
