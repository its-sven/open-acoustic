import CoreMIDI
import Foundation

/// Sends MIDI 1.0 messages strictly in order, one at a time.
///
/// SysEx goes through `MIDISendSysex`, which streams a message of any size to the destination at a rate it
/// can take and reports completion; the next message waits for that, so short messages can't overtake a
/// SysEx still on its way. Other messages are sent as single UMP words with `MIDISendEventList`.
final class MIDISender {
    var outputPort = MIDIPortRef()

    private enum Job {
        case short(UInt32, MIDIEndpointRef, String)
        case sysex([UInt8], MIDIEndpointRef, String)
        var portID: String {
            switch self { case .short(_, _, let id), .sysex(_, _, let id): return id }
        }
    }

    private let queue = DispatchQueue(label: "open-acoustic.midi.send", qos: .userInteractive)
    // Only touched on `queue`:
    private var jobs: [Job] = []
    private var busy = false
    private var generation: [String: Int] = [:]   // bumped by clear(); scheduled sends of an older generation are dropped

    func send(_ bytes: [UInt8], to dest: MIDIEndpointRef, portID: String, atHostMs: Double?) {
        // Split into messages (the Web MIDI side may pass several in one send).
        var messages: [[UInt8]] = []
        var parser = MIDI1StreamParser()
        parser.feed(bytes) { messages.append($0) }
        let newJobs: [Job] = messages.compactMap { m in
            if m.first == 0xF0 { return .sysex(m, dest, portID) }
            return UMP.word(forShortMessage: m).map { .short($0, dest, portID) }
        }
        guard !newJobs.isEmpty else { return }

        let delayMs = (atHostMs ?? 0) - HostClock.nowMs
        queue.async { [self] in
            if delayMs > 1 {
                let gen = generation[portID, default: 0]
                queue.asyncAfter(deadline: .now() + delayMs / 1000) { [self] in
                    guard generation[portID, default: 0] == gen else { return }
                    jobs.append(contentsOf: newJobs); pump()
                }
            } else {
                jobs.append(contentsOf: newJobs); pump()
            }
        }
    }

    func clear(portID: String) {
        queue.async { [self] in
            generation[portID, default: 0] += 1
            jobs.removeAll { $0.portID == portID }
        }
    }

    private func pump() {
        while !busy, !jobs.isEmpty {
            switch jobs.removeFirst() {
            case let .short(word, dest, _):
                sendShort(word, to: dest)
            case let .sysex(bytes, dest, _):
                busy = true
                SysexTransfer.start(bytes, to: dest, timeout: 2 + Double(bytes.count) / 2000) { [self] in
                    queue.async { [self] in busy = false; pump() }
                }
            }
        }
    }

    private func sendShort(_ word: UInt32, to dest: MIDIEndpointRef) {
        var list = MIDIEventList()
        let packet = MIDIEventListInit(&list, ._1_0)
        var w = word
        MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, 0, 1, &w)
        MIDISendEventList(outputPort, dest, &list)
    }
}

/// One `MIDISendSysex` call. CoreMIDI reads the bytes asynchronously, so the request and its data live on the
/// heap until CoreMIDI calls back. If it never does (e.g. the device vanished mid-transfer) a watchdog aborts
/// the transfer and lets the queue move on.
private final class SysexTransfer {
    private let data: UnsafeMutablePointer<UInt8>
    private let request: UnsafeMutablePointer<MIDISysexSendRequest>
    private let lock = NSLock()
    private var onDone: (() -> Void)?

    private init(_ bytes: [UInt8], dest: MIDIEndpointRef, onDone: @escaping () -> Void) {
        data = .allocate(capacity: bytes.count)
        data.initialize(from: bytes, count: bytes.count)
        request = .allocate(capacity: 1)
        self.onDone = onDone
        request.initialize(to: MIDISysexSendRequest(
            destination: dest, data: UnsafePointer(data), bytesToSend: UInt32(bytes.count),
            complete: false, reserved: (0, 0, 0),
            completionProc: { req in
                guard let refCon = req.pointee.completionRefCon else { return }
                Unmanaged<SysexTransfer>.fromOpaque(refCon).takeRetainedValue().finish()
            },
            completionRefCon: nil))
    }

    deinit {
        request.deinitialize(count: 1); request.deallocate()
        data.deallocate()
    }

    static func start(_ bytes: [UInt8], to dest: MIDIEndpointRef, timeout: Double, onDone: @escaping () -> Void) {
        let t = SysexTransfer(bytes, dest: dest, onDone: onDone)
        t.request.pointee.completionRefCon = Unmanaged.passRetained(t).toOpaque()   // released in finish()
        if MIDISendSysex(t.request) != noErr {
            Unmanaged<SysexTransfer>.fromOpaque(t.request.pointee.completionRefCon!).release()
            t.finish()
            return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak t] in
            guard let t else { return }
            t.request.pointee.complete = true                 // asks CoreMIDI to abort
            t.finish()
        }
    }

    /// Runs `onDone` exactly once, whichever comes first: completion or watchdog.
    private func finish() {
        lock.lock(); let done = onDone; onDone = nil; lock.unlock()
        done?()
    }
}
