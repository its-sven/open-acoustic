import Foundation

/// Splits a raw MIDI 1.0 byte stream into complete messages, the way Web MIDI hands them to a page.
///
/// - SysEx (`F0 … F7`) is assembled across any number of `feed` calls, so a message that arrives
///   spread over several packets comes out in one piece.
/// - System real-time bytes (`F8`–`FF`) may appear anywhere, even inside a SysEx or between a status
///   byte and its data. They are emitted on their own, immediately, and don't disturb the message in progress.
/// - Running status is supported for channel messages.
/// - A SysEx cut short by another status byte is dropped (Chrome does the same); the new status byte is
///   then handled normally.
/// - A SysEx longer than `maxSysexLength` is dropped as a whole.
///
/// Not thread-safe: use one parser per MIDI source and feed it from one thread at a time.
struct MIDI1StreamParser {
    static let maxSysexLength = 1 << 20

    private var status: UInt8 = 0          // running status; 0 = none
    private var expected = 0               // data bytes the current status needs
    private var data: [UInt8] = []
    private var inSysex = false
    private var sysexOverflow = false
    private var sysex: [UInt8] = []

    init() {
        data.reserveCapacity(2)
    }

    mutating func reset() {
        status = 0; expected = 0; data.removeAll(keepingCapacity: true)
        inSysex = false; sysexOverflow = false; sysex.removeAll(keepingCapacity: true)
    }

    mutating func feed<S: Sequence>(_ bytes: S, emit: ([UInt8]) -> Void) where S.Element == UInt8 {
        for b in bytes { feed(byte: b, emit: emit) }
    }

    private mutating func feed(byte b: UInt8, emit: ([UInt8]) -> Void) {
        // Real-time: always a message of its own, never changes any state.
        if b >= 0xF8 { emit([b]); return }

        if inSysex {
            if b < 0x80 {
                if !sysexOverflow {
                    if sysex.count < Self.maxSysexLength { sysex.append(b) } else { sysexOverflow = true; sysex.removeAll() }
                }
                return
            }
            if b == 0xF7 {
                if !sysexOverflow { sysex.append(0xF7); emit(sysex) }
                inSysex = false; sysexOverflow = false; sysex = []
                return
            }
            // Any other status byte ends the SysEx without an F7: drop it, then handle this byte.
            inSysex = false; sysexOverflow = false; sysex = []
        }

        switch b {
        case 0xF0:
            inSysex = true; sysex = [0xF0]; status = 0; data.removeAll(keepingCapacity: true)
        case 0xF7:
            break                                                  // stray end-of-exclusive
        case 0x80...0xEF:
            status = b; data.removeAll(keepingCapacity: true)
            expected = (b & 0xF0 == 0xC0 || b & 0xF0 == 0xD0) ? 1 : 2
        case 0xF1, 0xF3:
            status = b; expected = 1; data.removeAll(keepingCapacity: true)
        case 0xF2:
            status = b; expected = 2; data.removeAll(keepingCapacity: true)
        case 0xF6:
            status = 0; data.removeAll(keepingCapacity: true); emit([b])
        case 0xF4, 0xF5:
            status = 0; data.removeAll(keepingCapacity: true)     // undefined system common: ignore
        default:                                                   // data byte
            guard status != 0 else { return }                      // no status to attach it to
            data.append(b)
            if data.count == expected {
                emit([status] + data)
                data.removeAll(keepingCapacity: true)
                if status >= 0xF0 { status = 0 }                   // system common has no running status
            }
        }
    }
}
