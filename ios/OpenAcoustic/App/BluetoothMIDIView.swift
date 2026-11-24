import CoreAudioKit
import SwiftUI

/// The system's Bluetooth LE MIDI browser (`CABTMIDICentralViewController`), for pairing an adapter such as
/// a WIDI. Once connected, the adapter shows up as an ordinary MIDI port to the pages.
struct BluetoothMIDIView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let central = CABTMIDICentralViewController()
        central.navigationItem.title = "Bluetooth MIDI"
        central.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { _ in context.coordinator.dismiss() })
        return UINavigationController(rootViewController: central)
    }

    func updateUIViewController(_ vc: UINavigationController, context: Context) {
        context.coordinator.dismiss = { dismiss() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var dismiss: () -> Void = {}
    }
}
