import XCTest
@testable import OpenAcoustic

final class MIDI1StreamParserTests: XCTestCase {
    private func parse(_ chunks: [[UInt8]]) -> [[UInt8]] {
        var parser = MIDI1StreamParser()
        var out: [[UInt8]] = []
        for c in chunks { parser.feed(c) { out.append($0) } }
        return out
    }

    // A real Play Acoustic exchange: identity reply and a 22 (value) reply.
    let identityReply: [UInt8] = [0xF0, 0x7E, 0x00, 0x06, 0x02, 0x00, 0x01, 0x38, 0x70, 0x00, 0x01, 0x04, 0x00, 0xF7]
    let valueReply: [UInt8] = [0xF0, 0x00, 0x01, 0x38, 0x00, 0x70, 0x22, 0x01, 0x39, 0x00, 0x00, 0x00, 0x05, 0xF7]

    func testSysexInOnePacket() {
        XCTAssertEqual(parse([identityReply]), [identityReply])
    }

    func testSysexSplitAtEveryPosition() {
        for cut in 1..<valueReply.count {
            let chunks = [Array(valueReply[..<cut]), Array(valueReply[cut...])]
            XCTAssertEqual(parse(chunks), [valueReply], "split at \(cut)")
        }
    }

    func testSysexOneBytePerPacket() {
        XCTAssertEqual(parse(valueReply.map { [$0] }), [valueReply])
    }

    func testLargeSysexAcrossManyPackets() {
        let body = (0..<5000).map { UInt8($0 % 128) }
        let msg: [UInt8] = [0xF0] + body + [0xF7]
        let chunks = stride(from: 0, to: msg.count, by: 3).map { Array(msg[$0..<min($0 + 3, msg.count)]) }
        XCTAssertEqual(parse(chunks), [msg])
    }

    func testRealTimeInsideSysexIsEmittedOnItsOwn() {
        var stream = valueReply
        stream.insert(0xF8, at: 5)          // timing clock in the middle
        stream.insert(0xFE, at: 9)          // active sensing too
        XCTAssertEqual(parse([Array(stream[..<7]), Array(stream[7...])]), [[0xF8], [0xFE], valueReply])
    }

    func testRealTimeBetweenStatusAndData() {
        XCTAssertEqual(parse([[0x90, 0xF8, 0x3C], [0xFA, 0x64]]), [[0xF8], [0xFA], [0x90, 0x3C, 0x64]])
    }

    func testRunningStatus() {
        XCTAssertEqual(parse([[0x90, 0x3C, 0x64, 0x3E, 0x64], [0x40, 0x00]]),
                       [[0x90, 0x3C, 0x64], [0x90, 0x3E, 0x64], [0x90, 0x40, 0x00]])
    }

    func testProgramChangeAndChannelPressureTakeOneDataByte() {
        XCTAssertEqual(parse([[0xC0, 0x05, 0x06, 0xD1, 0x7F]]), [[0xC0, 0x05], [0xC0, 0x06], [0xD1, 0x7F]])
    }

    func testMixedSequence() {
        let stream: [UInt8] = [0xC0, 0x02] + identityReply + [0xB0, 0x07, 0x64] + valueReply
        XCTAssertEqual(parse([stream]), [[0xC0, 0x02], identityReply, [0xB0, 0x07, 0x64], valueReply])
    }

    func testSysexAfterRunningStatusDoesNotReuseIt() {
        // SysEx clears running status: the data bytes after it have no status and are dropped.
        XCTAssertEqual(parse([[0x90, 0x3C, 0x64, 0xF0, 0x7D, 0xF7, 0x3C, 0x64]]), [[0x90, 0x3C, 0x64], [0xF0, 0x7D, 0xF7]])
    }

    func testSysexInterruptedByStatusIsDropped() {
        XCTAssertEqual(parse([[0xF0, 0x00, 0x01, 0x38], [0x90, 0x3C, 0x64]]), [[0x90, 0x3C, 0x64]])
        XCTAssertEqual(parse([[0xF0, 0x00, 0x01, 0xF0, 0x7D, 0x01, 0xF7]]), [[0xF0, 0x7D, 0x01, 0xF7]])
    }

    func testStrayBytesAreIgnored() {
        XCTAssertEqual(parse([[0x3C, 0x64, 0xF7, 0xF4, 0x01, 0xC0, 0x01]]), [[0xC0, 0x01]])
    }

    func testSystemCommonHasNoRunningStatus() {
        XCTAssertEqual(parse([[0xF2, 0x10, 0x20, 0x30, 0xF3, 0x05, 0x06, 0xF6, 0xF1, 0x11]]),
                       [[0xF2, 0x10, 0x20], [0xF3, 0x05], [0xF6], [0xF1, 0x11]])
    }

    func testOversizedSysexIsDroppedAndParsingContinues() {
        let huge = [0xF0] + [UInt8](repeating: 0x01, count: MIDI1StreamParser.maxSysexLength + 10) + [0xF7]
        XCTAssertEqual(parse([huge, [0xC0, 0x03]]), [[0xC0, 0x03]])
    }

    func testReset() {
        var parser = MIDI1StreamParser()
        var out: [[UInt8]] = []
        parser.feed([0xF0, 0x01, 0x02]) { out.append($0) }
        parser.reset()
        parser.feed([0x03, 0xF7, 0xC0, 0x01]) { out.append($0) }
        XCTAssertEqual(out, [[0xC0, 0x01]])
    }
}
