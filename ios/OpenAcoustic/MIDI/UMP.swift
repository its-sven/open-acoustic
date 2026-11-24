import Foundation

/// Conversion between MIDI 1.0 byte messages and Universal MIDI Packets (UMP) in the MIDI 1.0 protocol,
/// as CoreMIDI's `MIDIInputPortCreateWithProtocol(…, ._1_0, …)` and `MIDISendEventList` use them.
enum UMP {
    /// Number of 32-bit words in a UMP, from the message type in its first word.
    static func wordCount(firstWord w: UInt32) -> Int {
        switch w >> 28 {
        case 0x0, 0x1, 0x2, 0x6, 0x7: return 1
        case 0x3, 0x4, 0x8, 0x9, 0xA: return 2
        case 0xB, 0xC: return 3
        default: return 4                                    // 0x5, 0xD, 0xE, 0xF
        }
    }

    /// Length of a MIDI 1.0 message (status byte included) that starts with `status`, for messages that fit
    /// in one UMP word. Returns 0 for SysEx and undefined bytes.
    static func shortMessageLength(status: UInt8) -> Int {
        switch status {
        case 0x80...0xBF, 0xE0...0xEF: return 3
        case 0xC0...0xDF: return 2
        case 0xF1, 0xF3: return 2
        case 0xF2: return 3
        case 0xF6, 0xF8...0xFF: return 1
        default: return 0
        }
    }

    /// Appends the MIDI 1.0 bytes carried by `words` (any number of UMPs) to `out`.
    /// SysEx arrives as a series of 7-bit data packets (type 3): start / continue / end, or complete.
    /// They are turned back into `F0 … F7` bytes here; reassembly across packets is up to `MIDI1StreamParser`.
    /// Message types other than system (1), MIDI 1.0 channel voice (2) and SysEx7 (3) are skipped.
    static func appendBytes<C: Collection>(from words: C, to out: inout [UInt8]) where C.Element == UInt32, C.Index == Int {
        var i = words.startIndex
        while i < words.endIndex {
            let w0 = words[i]
            let n = wordCount(firstWord: w0)
            defer { i += n }
            switch w0 >> 28 {
            case 0x1, 0x2:
                let status = UInt8((w0 >> 16) & 0xFF)
                let len = shortMessageLength(status: status)
                guard len > 0 else { continue }
                out.append(status)
                if len > 1 { out.append(UInt8((w0 >> 8) & 0x7F)) }
                if len > 2 { out.append(UInt8(w0 & 0x7F)) }
            case 0x3:
                guard i + 1 < words.endIndex else { return }
                let w1 = words[i + 1]
                let kind = (w0 >> 20) & 0xF                  // 0 complete, 1 start, 2 continue, 3 end
                let count = min(6, Int((w0 >> 16) & 0xF))
                let payload: [UInt8] = [UInt8((w0 >> 8) & 0xFF), UInt8(w0 & 0xFF),
                                        UInt8(w1 >> 24), UInt8((w1 >> 16) & 0xFF), UInt8((w1 >> 8) & 0xFF), UInt8(w1 & 0xFF)]
                if kind == 0 || kind == 1 { out.append(0xF0) }
                for b in payload.prefix(count) { out.append(b & 0x7F) }
                if kind == 0 || kind == 3 { out.append(0xF7) }
            default:
                continue
            }
        }
    }

    /// The single UMP word for a complete MIDI 1.0 message that isn't SysEx (channel voice, system common
    /// or real-time), on UMP group 0. Returns nil if `bytes` isn't exactly one such message.
    static func word(forShortMessage bytes: [UInt8]) -> UInt32? {
        guard let status = bytes.first, status >= 0x80, status != 0xF0, status != 0xF7 else { return nil }
        let len = shortMessageLength(status: status)
        guard len > 0, bytes.count == len else { return nil }
        let type: UInt32 = status < 0xF0 ? 0x2 : 0x1
        let d1 = len > 1 ? UInt32(bytes[1] & 0x7F) : 0
        let d2 = len > 2 ? UInt32(bytes[2] & 0x7F) : 0
        return type << 28 | UInt32(status) << 16 | d1 << 8 | d2
    }
}
