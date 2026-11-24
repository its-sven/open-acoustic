import SwiftUI

/// What the app can tell about the MIDI link from CoreMIDI alone (the pages then check the pedal's identity).
/// Port names are matched like upstream `pa-link.js` does.
struct MIDIStatus {
    enum Level { case pedal, adapter, other, none }
    let level: Level
    let text: String

    init(ports: [MIDIPortInfo]) {
        func match(_ pattern: String) -> MIDIPortInfo? {
            ports.first { $0.name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        }
        if let p = match(#"play\s*acoustic|play\s*electric|helicon"#) {
            level = .pedal; text = "Pedal on USB: \(p.name)"
        } else if let p = match(#"widi|bluetooth|\bble\b"#) {
            level = .adapter; text = "Bluetooth MIDI: \(p.name)"
        } else if let p = ports.first {
            level = .other; text = "MIDI: \(p.name)"
        } else {
            level = .none; text = "No MIDI device"
        }
    }

    var color: Color {
        switch level {
        case .pedal: return .green
        case .adapter: return .blue
        case .other: return .orange
        case .none: return .gray
        }
    }
}

struct StatusDot: View {
    let color: Color
    var body: some View {
        Circle().fill(color).frame(width: 10, height: 10)
            .shadow(color: color.opacity(0.8), radius: color == .gray ? 0 : 4)
    }
}
