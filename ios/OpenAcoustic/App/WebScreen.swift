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
        let size = UserDefaults.standard.object(forKey: PageSize.key) as? Double ?? PageSize.defaultValue
        _controller = StateObject(wrappedValue: WebController(url: page.url, zoom: size))
    }

    var body: some View {
        GeometryReader { geo in
            WebContainer(controller: controller)
                .overlay(alignment: .bottomTrailing) {
                    let at = Self.menuOffset(for: geo.safeAreaInsets)
                    menu.offset(x: at.width, y: at.height)
                }
        }
        // the margins the web view leaves for the notch / home indicator take the page's colour
        .background(Color(controller.pageBackground).ignoresSafeArea())
        .sheet(isPresented: $showBluetooth) { BluetoothMIDIView() }
            .onAppear { controller.zoom = size }
            .onChange(of: size) { controller.zoom = $0 }
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
            .padding(.horizontal, 9).frame(height: 28)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            .overlay(Capsule().stroke(Color.white.opacity(0.18)))
            .contentShape(Capsule())
        }
        .accessibilityLabel("App menu")
    }

    /// Where the menu button goes, relative to the bottom-trailing corner of the web view. Where the screen
    /// leaves a margin (beside the notch in landscape, above the home indicator in portrait) the button sits
    /// in it, so it never covers the page; otherwise (e.g. iPads with a home button) it floats over the page.
    static func menuOffset(for inset: EdgeInsets) -> CGSize {
        let width: CGFloat = 54, height: CGFloat = 28
        if inset.trailing >= width + 4 { return CGSize(width: inset.trailing - 4, height: inset.bottom - 4) }
        if inset.bottom >= height + 2 { return CGSize(width: -8, height: inset.bottom - 2) }
        return CGSize(width: -10, height: -10)
    }
}

/// The size the pages are shown at (like a browser's zoom; see `WebController.zoom`), kept per device.
enum PageSize {
    static let key = "pageSize"
    static let steps: [Double] = [0.6, 0.7, 0.75, 0.8, 0.85, 0.9, 1.0, 1.1, 1.25]
    /// Phones get a smaller default: the pages are laid out for tablets and laptops.
    static var defaultValue: Double { UIDevice.current.userInterfaceIdiom == .phone ? 0.8 : 1.0 }
}
