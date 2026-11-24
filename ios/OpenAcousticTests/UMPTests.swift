import CoreMIDI
import XCTest
@testable import OpenAcoustic

final class UMPTests: XCTestCase {
    /// Packs a MIDI 1.0 SysEx (with F0/F7) into SysEx7 UMPs the way CoreMIDI does: 6 bytes per packet.
    private func sysex7Words(_ msg: [UInt8]) -> [UInt32] {
        let body = Array(msg.dropFirst().dropLast())
        let chunks = stride(from: 0, to: max(body.count, 1), by: 6).map { Array(body[$0..<min($0 + 6, body.count)]) }
        var words: [UInt32] = []
        for (i, c) in chunks.enumerated() {
            let kind: UInt32 = chunks.count == 1 ? 0 : i == 0 ? 1 : i == chunks.count - 1 ? 3 : 2
            var b = c + [UInt8](repeating: 0, count: 6 - c.count)
            b = b.map { $0 & 0x7F }
            words.append(0x3 << 28 | kind << 20 | UInt32(c.count) << 16 | UInt32(b[0]) << 8 | UInt32(b[1]))
            words.append(UInt32(b[2]) << 24 | UInt32(b[3]) << 16 | UInt32(b[4]) << 8 | UInt32(b[5]))
        }
        return words
    }

    private func bytes(_ words: [UInt32]) -> [UInt8] {
        var out: [UInt8] = []
        UMP.appendBytes(from: words, to: &out)
        return out
    }

    let valueReply: [UInt8] = [0xF0, 0x00, 0x01, 0x38, 0x00, 0x70, 0x22, 0x01, 0x39, 0x00, 0x00, 0x00, 0x05, 0xF7]

    func testCompleteSysexInOnePacket() {
        let msg: [UInt8] = [0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7]
        XCTAssertEqual(bytes(sysex7Words(msg)), msg)
    }

    func testMultiPacketSysex() {
        XCTAssertEqual(bytes(sysex7Words(valueReply)), valueReply)
    }

    func testSysexPacketsSplitAcrossEventPacketsReassemble() {
        // Each UMP in its own CoreMIDI packet, with a clock between them: the parser still yields one SysEx.
        let words = sysex7Words(valueReply)
        var parser = MIDI1StreamParser()
        var out: [[UInt8]] = []
        for i in stride(from: 0, to: words.count, by: 2) {
            parser.feed(bytes(Array(words[i..<i + 2]))) { out.append($0) }
            parser.feed(bytes([0x10F8_0000])) { out.append($0) }       // type 1 timing clock
        }
        XCTAssertEqual(out.filter { $0 != [0xF8] }, [valueReply])
        XCTAssertEqual(out.filter { $0 == [0xF8] }.count, words.count / 2)
    }

    func testChannelVoiceAndSystemMessages() {
        XCTAssertEqual(bytes([0x2090_3C64]), [0x90, 0x3C, 0x64])
        XCTAssertEqual(bytes([0x20C0_0500]), [0xC0, 0x05])
        XCTAssertEqual(bytes([0x10F2_1020]), [0xF2, 0x10, 0x20])
        XCTAssertEqual(bytes([0x10FE_0000]), [0xFE])
    }

    func testOtherMessageTypesAreSkippedWithTheirLength() {
        // utility (1 word), MIDI 2.0 voice (2 words), data 128 (4 words), then a note on
        let words: [UInt32] = [0x0000_0000, 0x4090_3C00, 0xFFFF_0000, 0x5000_0000, 1, 2, 3, 0x2090_3C64]
        XCTAssertEqual(bytes(words), [0x90, 0x3C, 0x64])
    }

    func testShortMessageWords() {
        XCTAssertEqual(UMP.word(forShortMessage: [0x90, 0x3C, 0x64]), 0x2090_3C64)
        XCTAssertEqual(UMP.word(forShortMessage: [0xC0, 0x05]), 0x20C0_0500)
        XCTAssertEqual(UMP.word(forShortMessage: [0xF8]), 0x10F8_0000)
        XCTAssertNil(UMP.word(forShortMessage: [0x90, 0x3C]))           // incomplete
        XCTAssertNil(UMP.word(forShortMessage: [0xF0, 0x01, 0xF7]))     // SysEx goes another way
        XCTAssertNil(UMP.word(forShortMessage: [0x3C]))
        for m: [UInt8] in [[0x90, 0x3C, 0x64], [0xC0, 0x05], [0xF2, 0x01, 0x02], [0xFF]] {
            XCTAssertEqual(bytes([UMP.word(forShortMessage: m)!]), m)
        }
    }

    func testEventListReader() {
        let size = 1024
        let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: MIDIEventList.self, capacity: 1)
        var packet = MIDIEventListInit(list, ._1_0)
        var a: [UInt32] = [0x2090_3C64]
        packet = MIDIEventListAdd(list, size, packet, 100, 1, &a)
        var b = sysex7Words(valueReply)
        packet = MIDIEventListAdd(list, size, packet, 200, b.count, &b)

        var seen: [(MIDITimeStamp, [UInt32])] = []
        EventListReader.forEachPacket(UnsafePointer(list)) { seen.append(($0, Array($1))) }
        XCTAssertEqual(seen.map(\.0), [100, 200])
        XCTAssertEqual(seen.first?.1, a)
        XCTAssertEqual(seen.last?.1, b)
    }
}
