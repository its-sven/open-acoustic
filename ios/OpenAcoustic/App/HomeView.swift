import SwiftUI

struct HomeView: View {
    let open: (WebPage) -> Void
    @EnvironmentObject private var midi: MIDIManager
    @State private var showBluetooth = false

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(WebPage.allCases) { page in
                        Button { open(page) } label: { PageCard(page: page) }
                            .buttonStyle(.plain)
                    }
                }
                midiSection
                footer
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(white: 0.07).ignoresSafeArea())
        .sheet(isPresented: $showBluetooth) { BluetoothMIDIView() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open Acoustic").font(.largeTitle.weight(.bold))
            Text("Offline remote for the Play Acoustic vocal and guitar pedal, over USB or Bluetooth MIDI.")
                .foregroundColor(.secondary)
        }
    }

    private var midiSection: some View {
        let status = MIDIStatus(ports: midi.ports)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                StatusDot(color: status.color)
                Text(status.text).font(.headline)
                Spacer()
                Button { showBluetooth = true } label: {
                    Label("Bluetooth MIDI…", systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(.bordered)
            }
            if let error = midi.setupError {
                Text(error).foregroundColor(.red).font(.footnote)
            }
            if midi.ports.isEmpty {
                Text("Connect the pedal's USB port through a camera adapter (Lightning or USB-C), or pair a Bluetooth MIDI adapter.")
                    .font(.footnote).foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(midi.ports) { p in
                        HStack(spacing: 8) {
                            Image(systemName: p.type == .input ? "arrow.down.circle" : "arrow.up.circle")
                                .foregroundColor(.secondary)
                            Text(p.name)
                            if !p.manufacturer.isEmpty { Text(p.manufacturer).foregroundColor(.secondary) }
                        }
                        .font(.footnote)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.12)))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Unofficial. Not affiliated with or endorsed by TC-Helicon or Music Tribe. The pages are the open-acoustic web tools, bundled for offline use; they never write MIDI CTRL or FILTER, which can lock USB SysEx out until a factory reset.")
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}

private struct PageCard: View {
    let page: WebPage
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: page.symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(page.title).font(.title3.weight(.semibold)).foregroundColor(.primary)
                Text(page.subtitle).font(.subheadline).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.14)))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
