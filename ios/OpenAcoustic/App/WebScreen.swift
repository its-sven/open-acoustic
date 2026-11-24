import SwiftUI

/// A bundled page, full screen, with a small app menu in the corner: home, reload, Bluetooth pairing,
/// and the MIDI link status as a coloured dot.
struct WebScreen: View {
    let page: WebPage
    let home: () -> Void
    @StateObject private var controller: WebController
    @EnvironmentObject private var midi: MIDIManager
    @State private var showBluetooth = false

    init(page: WebPage, home: @escaping () -> Void) {
        self.page = page
        self.home = home
        _controller = StateObject(wrappedValue: WebController(url: page.url))
    }

    var body: some View {
        WebContainer(controller: controller)
            .background(Color.black.ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) { menu }
            .sheet(isPresented: $showBluetooth) { BluetoothMIDIView() }
    }

    private var menu: some View {
        let status = MIDIStatus(ports: midi.ports)
        return Menu {
            Section(status.text) {
                Button { home() } label: { Label("Home", systemImage: "house") }
                Button { controller.reload() } label: { Label("Reload page", systemImage: "arrow.clockwise") }
                Button { showBluetooth = true } label: { Label("Bluetooth MIDI…", systemImage: "dot.radiowaves.left.and.right") }
            }
        } label: {
            HStack(spacing: 6) {
                StatusDot(color: status.color)
                Image(systemName: "ellipsis").font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 10).frame(height: 30)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            .overlay(Capsule().stroke(Color.white.opacity(0.18)))
            .contentShape(Capsule())
        }
        .accessibilityLabel("App menu")
        .padding(10)
    }
}
