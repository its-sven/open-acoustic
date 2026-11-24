import SwiftUI

@main
struct OpenAcousticApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var midi = MIDIManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(midi)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
        .onChange(of: scenePhase) { phase in
            // On stage the screen must not dim or lock while the app is in front.
            UIApplication.shared.isIdleTimerDisabled = phase == .active
            if phase == .active { midi.refresh() }
        }
    }
}

/// The bundled pages the app opens.
enum WebPage: String, CaseIterable, Identifiable {
    case remote, views, simulator, verify
    var id: String { rawValue }

    var path: String {
        switch self {
        case .remote: return "pa-remote.html"
        case .views: return "views/index.html"
        case .simulator: return "views/index.html?sim"
        case .verify: return "verify.html"
        }
    }

    var url: URL { AppSchemeHandler.url(for: path) }

    var title: String {
        switch self {
        case .remote: return "Remote"
        case .views: return "Touch Views"
        case .simulator: return "Simulator"
        case .verify: return "Verify"
        }
    }

    var subtitle: String {
        switch self {
        case .remote: return "The full virtual front panel: LCD, knob, menus, footswitches and a MIDI log."
        case .views: return "Five touch layouts for the stage and the studio, all in step with the pedal."
        case .simulator: return "The touch views against a simulated pedal. Nothing is sent to MIDI."
        case .verify: return "The hardware checklist: read, set and confirm what the pedal does."
        }
    }

    var symbol: String {
        switch self {
        case .remote: return "slider.horizontal.3"
        case .views: return "hand.tap"
        case .simulator: return "play.rectangle"
        case .verify: return "checklist"
        }
    }
}

struct RootView: View {
    @State private var page: WebPage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let page {
                WebScreen(page: page) { self.page = nil }
                    .id(page)
                    .transition(.opacity)
            } else {
                HomeView { page = $0 }
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: page)
    }
}
