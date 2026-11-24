import CoreMIDI
import Foundation

/// A MIDI endpoint as the web side sees it (one Web MIDI `MIDIInput` or `MIDIOutput`).
struct MIDIPortInfo: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case input, output }
    let id: String
    let type: Kind
    let name: String
    let manufacturer: String
    let version: String
}

/// One complete MIDI message from a source, with its CoreMIDI timestamp in host milliseconds.
struct ReceivedMIDIMessage {
    let portID: String
    let hostMs: Double
    let bytes: [UInt8]
}

/// Owns the CoreMIDI client: keeps the list of ports current (hot-plug), turns incoming UMP into complete
/// MIDI 1.0 messages (SysEx reassembled) and sends messages out in order.
///
/// The public API is meant to be used from the main thread. Incoming messages and port changes are
/// delivered on the main thread.
final class MIDIManager: ObservableObject {
    static let shared = MIDIManager()

    @Published private(set) var ports: [MIDIPortInfo] = []
    /// Non-nil when CoreMIDI could not be set up (shown on the home screen).
    @Published private(set) var setupError: String?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var outputPort = MIDIPortRef()
    private var connectedSources = Set<MIDIEndpointRef>()
    private var refreshScheduled = false

    // Receive side (CoreMIDI's thread → main).
    private let rxLock = NSLock()
    private var parsers: [MIDIEndpointRef: MIDI1StreamParser] = [:]
    private var sourceIDs: [MIDIEndpointRef: String] = [:]
    private var pending: [ReceivedMIDIMessage] = []
    private var flushScheduled = false

    // Listeners, by token.
    private var messageSinks: [UUID: ([ReceivedMIDIMessage]) -> Void] = [:]
    private var portSinks: [UUID: ([MIDIPortInfo]) -> Void] = [:]

    private let sender = MIDISender()

    init() {
        setUp()
    }

    // MARK: - Setup

    private func setUp() {
        var status = MIDIClientCreateWithBlock("Open Acoustic" as CFString, &client) { [weak self] notification in
            // Any change in the MIDI setup (device plugged/unplugged, Bluetooth link, offline flag): rebuild.
            switch notification.pointee.messageID {
            case .msgSetupChanged, .msgObjectAdded, .msgObjectRemoved, .msgPropertyChanged:
                DispatchQueue.main.async { self?.scheduleRefresh() }
            default:
                break
            }
        }
        guard status == noErr else { setupError = "CoreMIDI client failed (\(status))"; return }

        status = MIDIInputPortCreateWithProtocol(client, "Open Acoustic In" as CFString, ._1_0, &inputPort) { [weak self] list, srcRefCon in
            self?.receive(list, srcRefCon: srcRefCon)
        }
        guard status == noErr else { setupError = "CoreMIDI input port failed (\(status))"; return }

        status = MIDIOutputPortCreate(client, "Open Acoustic Out" as CFString, &outputPort)
        guard status == noErr else { setupError = "CoreMIDI output port failed (\(status))"; return }
        sender.outputPort = outputPort

        refresh()
    }

    private func scheduleRefresh() {
        // Plugging in a device fires a burst of notifications; rebuild once after they settle.
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.refreshScheduled = false
            self?.refresh()
        }
    }

    /// Re-reads the endpoint list, connects new sources and tells listeners if anything changed.
    func refresh() {
        var list: [MIDIPortInfo] = []
        var ids: [MIDIEndpointRef: String] = [:]

        for i in 0..<MIDIGetNumberOfSources() {
            let src = MIDIGetSource(i)
            guard src != 0, let info = Self.info(for: src, type: .input) else { continue }
            list.append(info)
            ids[src] = info.id
        }
        for i in 0..<MIDIGetNumberOfDestinations() {
            let dst = MIDIGetDestination(i)
            guard dst != 0, let info = Self.info(for: dst, type: .output) else { continue }
            list.append(info)
        }

        rxLock.lock()
        sourceIDs = ids
        rxLock.unlock()

        // Connect sources we aren't listening to yet. Removed ones disconnect themselves.
        let present = Set(ids.keys)
        for src in present.subtracting(connectedSources) {
            rxLock.lock(); parsers[src] = MIDI1StreamParser(); rxLock.unlock()
            MIDIPortConnectSource(inputPort, src, UnsafeMutableRawPointer(bitPattern: UInt(src)))
        }
        connectedSources = present

        if list != ports {
            ports = list
            portSinks.values.forEach { $0(list) }
        }
    }

    private static func info(for endpoint: MIDIEndpointRef, type: MIDIPortInfo.Kind) -> MIDIPortInfo? {
        var offline: Int32 = 0
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyOffline, &offline)
        guard offline == 0 else { return nil }
        var uid: MIDIUniqueID = 0
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uid)
        let name = string(endpoint, kMIDIPropertyDisplayName) ?? string(endpoint, kMIDIPropertyName) ?? "MIDI \(type.rawValue)"
        var driverVersion: Int32 = 0
        let version = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyDriverVersion, &driverVersion) == noErr ? String(driverVersion) : ""
        return MIDIPortInfo(id: "\(type == .input ? "in" : "out")-\(uid)", type: type, name: name,
                            manufacturer: string(endpoint, kMIDIPropertyManufacturer) ?? "", version: version)
    }

    private static func string(_ obj: MIDIObjectRef, _ prop: CFString) -> String? {
        var value: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(obj, prop, &value) == noErr, let s = value?.takeRetainedValue() else { return nil }
        return s as String
    }

    // MARK: - Listeners

    /// Registers for incoming messages (batched, main thread). Keep the token; pass it to `removeListener`.
    func addMessageListener(_ sink: @escaping ([ReceivedMIDIMessage]) -> Void) -> UUID {
        let token = UUID(); messageSinks[token] = sink; return token
    }

    func addPortListener(_ sink: @escaping ([MIDIPortInfo]) -> Void) -> UUID {
        let token = UUID(); portSinks[token] = sink; return token
    }

    func removeListener(_ token: UUID) {
        messageSinks[token] = nil; portSinks[token] = nil
    }

    // MARK: - Receive

    private func receive(_ list: UnsafePointer<MIDIEventList>, srcRefCon: UnsafeMutableRawPointer?) {
        let src = MIDIEndpointRef(UInt(bitPattern: srcRefCon))
        var bytes: [UInt8] = []
        EventListReader.forEachPacket(list) { timeStamp, words in
            bytes.removeAll(keepingCapacity: true)
            UMP.appendBytes(from: words, to: &bytes)
            guard !bytes.isEmpty else { return }
            let ms = timeStamp == 0 ? HostClock.nowMs : HostClock.ms(fromHostTime: timeStamp)

            rxLock.lock()
            guard let id = sourceIDs[src] else { rxLock.unlock(); return }
            // Mutate the parser in place: a copy would duplicate a half-received SysEx on every packet.
            parsers[src, default: MIDI1StreamParser()].feed(bytes) { pending.append(ReceivedMIDIMessage(portID: id, hostMs: ms, bytes: $0)) }
            let schedule = !flushScheduled && !pending.isEmpty
            if schedule { flushScheduled = true }
            rxLock.unlock()

            if schedule { DispatchQueue.main.async { [weak self] in self?.flush() } }
        }
    }

    private func flush() {
        rxLock.lock()
        let batch = pending
        pending.removeAll(keepingCapacity: true)
        flushScheduled = false
        rxLock.unlock()
        guard !batch.isEmpty else { return }
        messageSinks.values.forEach { $0(batch) }
    }

    // MARK: - Send

    /// Sends one or more complete MIDI messages to the output `portID`. `atHostMs` (host clock) delays the
    /// send until then; nil or a time in the past sends at once. Messages go out in the order they're sent.
    /// Returns false if there is no such output.
    @discardableResult
    func send(_ bytes: [UInt8], to portID: String, atHostMs: Double? = nil) -> Bool {
        guard let dest = Self.destination(for: portID) else { return false }
        sender.send(bytes, to: dest, portID: portID, atHostMs: atHostMs)
        return true
    }

    /// Drops messages for `portID` that are scheduled for later and not yet sent (Web MIDI `MIDIOutput.clear()`).
    func clear(portID: String) {
        sender.clear(portID: portID)
    }

    static func destination(for portID: String) -> MIDIEndpointRef? {
        guard portID.hasPrefix("out-"), let uid = MIDIUniqueID(portID.dropFirst(4)) else { return nil }
        var obj = MIDIObjectRef()
        var type = MIDIObjectType.other
        guard MIDIObjectFindByUniqueID(uid, &obj, &type) == noErr,
              type == .destination || type == .externalDestination else { return nil }
        return obj
    }

    // MARK: - Virtual loopback (tests)

    private var loopbackSource = MIDIEndpointRef()
    private var loopbackDestination = MIDIEndpointRef()

    /// Creates a virtual output whose messages come straight back on a virtual input of the same name.
    /// Used by the integration tests to run the whole JS ↔ Swift ↔ CoreMIDI path without hardware.
    /// iOS may refuse virtual endpoints (kMIDINotPermitted) to apps without the audio background mode.
    func createLoopback(name: String) -> OSStatus {
        var status = MIDISourceCreateWithProtocol(client, name as CFString, ._1_0, &loopbackSource)
        guard status == noErr else { return status }
        let source = loopbackSource
        status = MIDIDestinationCreateWithProtocol(client, name as CFString, ._1_0, &loopbackDestination) { list, _ in
            MIDIReceivedEventList(source, list)
        }
        refresh()
        return status
    }

    func removeLoopback() {
        if loopbackDestination != 0 { MIDIEndpointDispose(loopbackDestination); loopbackDestination = 0 }
        if loopbackSource != 0 { MIDIEndpointDispose(loopbackSource); loopbackSource = 0 }
        refresh()
    }
}

/// Walks the packets of a `MIDIEventList` without the C inline helpers (which aren't imported on every arch).
enum EventListReader {
    static func forEachPacket(_ list: UnsafePointer<MIDIEventList>, _ body: (MIDITimeStamp, UnsafeBufferPointer<UInt32>) -> Void) {
        let count = Int(list.pointee.numPackets)
        guard count > 0,
              let packetOffset = MemoryLayout<MIDIEventList>.offset(of: \MIDIEventList.packet),
              let wordsOffset = MemoryLayout<MIDIEventPacket>.offset(of: \MIDIEventPacket.words) else { return }
        var p = UnsafeRawPointer(list) + packetOffset
        for _ in 0..<count {
            let timeStamp = p.loadUnaligned(as: MIDITimeStamp.self)
            let wordCount = Int(p.loadUnaligned(fromByteOffset: MemoryLayout<MIDITimeStamp>.size, as: UInt32.self))
            let words = (p + wordsOffset).assumingMemoryBound(to: UInt32.self)
            body(timeStamp, UnsafeBufferPointer(start: words, count: min(wordCount, 64)))
            p = p + wordsOffset + wordCount * MemoryLayout<UInt32>.size
        }
    }
}
