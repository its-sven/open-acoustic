import SwiftUI

/// A bundled page, full screen, with a small app menu in the corner: home, reload, page size,
/// Bluetooth pairing, and the MIDI link status as a coloured dot.
struct WebScreen: View {
    let page: WebPage
    let home: () -> Void
    @StateObject private var controller: WebController
    @EnvironmentObject private var midi: MIDIManager
    @State private var showBluetooth = false
    @AppStorage(PageSize.key) private var size = PageSize.defaultValue

    init(page: WebPage, home: @escaping () -> Void) {
        self.page = page
        self.home = home
        _controller = StateObject(wrappedValue: WebController(url: page.url))
    }

    var body: some View {
        WebContainer(controller: controller)
            // the margins the web view leaves for the notch / home indicator take the page's colour
            .background(Color(controller.pageBackground).ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) { menu }
            .sheet(isPresented: $showBluetooth) { BluetoothMIDIView() }
            .onAppear { controller.zoom = CGFloat(size) }
            .onChange(of: size) { controller.zoom = CGFloat($0) }
    }

    private var menu: some View {
        let status = MIDIStatus(ports: midi.ports)
        return Menu {
            Section(status.text) {
                Button { home() } label: { Label("Home", systemImage: "house") }
                Button { controller.reload() } label: { Label("Reload page", systemImage: "arrow.clockwise") }
                Picker(selection: $size) {
                    ForEach(PageSize.steps, id: \.self) { Text("\(Int(($0 * 100).rounded())) %").tag($0) }
                } label: {
                    Label("Size: \(Int((size * 100).rounded())) %", systemImage: "textformat.size")
                }
                .pickerStyle(.menu)
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

/// The size the pages are shown at (WKWebView page zoom), kept per device.
enum PageSize {
    static let key = "pageSize"
    static let steps: [Double] = [0.6, 0.7, 0.75, 0.8, 0.85, 0.9, 1.0, 1.1, 1.25]
    /// Phones get a smaller default: the pages are laid out for tablets and laptops.
    static var defaultValue: Double { UIDevice.current.userInterfaceIdiom == .phone ? 0.8 : 1.0 }
}
