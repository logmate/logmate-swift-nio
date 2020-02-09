// Copyright © 2020 Florent Pillet
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software
// and associated documentation files (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial
// portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
// LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
// OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import XCTest
@testable import Logmate

fileprivate enum TestsError: Error {
	case invalidHexString(String)
}

open class LogReaderTestCase: LogmateReadWriteTestCase {

	func testBufferIsEmpty() {
		var buffer = logDataFromHex("")
		XCTAssertNil(try buffer.readNextLogEntry())
	}

	func testBufferIsIncomplete() {
		var buffer = logDataFromHex("00 00 00")
		XCTAssertNil(try buffer.readNextLogEntry())
	}

	func testSizeFoundButBufferIsIncomplete() {
		var buffer = logDataFromHex("00 00 00 10 00 00 00")
		XCTAssertNil(try buffer.readNextLogEntry())
	}

	func testThrowsOnSpuriousMessageSize() {
		var buffer = logDataFromHex("3E EF FF C0 00 05")
		XCTAssertThrowsError(try buffer.readNextLogEntry())
	}

	func testThrowsOnMissingMessageType() {
		var buffer = logDataFromHex("00 00 00 02 00 00")
		XCTAssertThrowsError(try buffer.readNextLogEntry())
	}

	func testReadingShortIntegers() throws {
		var buffer = logDataFromHex(
			"""
			00 00 00 22
			00 04
			00 02 00 00
			01 03 5c 55 5d 1a
			07 00 00 00 00 0c 48 65 6C 6C 6F 2C 20 77 6F 72 6C 64
			0A 02 00 07
			""")

		let log = try buffer.readNextLogEntry()
		XCTAssertNotNil(log)
		XCTAssertTrue(log is LogTextMessage?)
		XCTAssertEqual(log!.sequence, 7)
	}

	func testReadingLongIntegers() throws {
		var buffer = logDataFromHex(
			"""
			00 00 00 28
			00 04
			00 02 00 00
			01 03 5c 55 5d 1a
			07 00 00 00 00 0c 48 65 6C 6C 6F 2C 20 77 6F 72 6C 64
			0A 04 00 00 00 00 00 00 00 07
			""")
		
		let log = try buffer.readNextLogEntry()
		XCTAssertNotNil(log)
		XCTAssertTrue(log is LogTextMessage?)
		XCTAssertEqual(log!.sequence, 7)
	}

	func testDecodeMinimalLogTextMessage() throws {
		var buffer = logDataFromHex(
			"""
			00 00 00 24
			00 04
			00 02 00 00
			01 03 5c 55 5d 1a
			07 00 00 00 00 0c 48 65 6C 6C 6F 2C 20 77 6F 72 6C 64
			0A 03 00 00 00 07
			""")
		let log = try buffer.readNextLogEntry()
		XCTAssertNotNil(log)
		XCTAssertTrue(log is LogTextMessage?)

		let message = log as! LogTextMessage
		XCTAssertEqual(message.sequence, 7)
		XCTAssertEqual(message.timestamp.tv_sec, 1549098266)
		XCTAssertEqual(message.timestamp.tv_usec, 0)
		XCTAssertEqual(message.tags, [])
		XCTAssertEqual(message.line, 0)
		XCTAssertEqual(message.filename, nil)
		XCTAssertEqual(message.function, nil)
		XCTAssertEqual(message.message, "Hello, world")
	}

	func testDecodeCompleteLogTextMessage() throws {
		var buffer = logDataFromHex(
			"""
			00 00 00 70
			00 0c
			00 02 00 00
			01 03 5c 55 5d 1a
			02 02 00 07
			03 03 00 00 10 05
			04 00 00 00 00 0b 4D 61 69 6E 20 74 68 72 65 61 64
			05 00 00 00 00 03 41 70 70
			06 02 00 01
			07 00 00 00 00 0c 48 65 6C 6C 6F 2C 20 77 6F 72 6C 64
			0A 03 00 00 00 07
			0B 00 00 00 00 06 6D 61 69 6E 2E 63
			0C 02 00 2a
			0D 00 00 00 00 0e 73 6F 6D 65 46 75 6E 63 74 69 6F 6E 28 29
			""")
		let log = try buffer.readNextLogEntry()
		XCTAssertNotNil(log)
		XCTAssertTrue(log is LogTextMessage?)

		let message = log as! LogTextMessage
		XCTAssertEqual(message.sequence, 7)
		XCTAssertEqual(message.timestamp.tv_sec, 1549098266)
		XCTAssertEqual(message.timestamp.tv_usec, 11101)
		XCTAssertEqual(message.tags, ["App"])
		XCTAssertEqual(message.level, 1)
		XCTAssertEqual(message.message, "Hello, world")
		XCTAssertEqual(message.thread, "Main thread")
		XCTAssertEqual(message.filename, "main.c")
		XCTAssertEqual(message.line, 42)
		XCTAssertEqual(message.function, "someFunction()")
	}

	func testDecodeBinaryDataMessage() throws {
		var buffer = logDataFromHex(
			"""
			00 00 00 6a
			00 0b
			00 02 00 00
			01 03 5c 55 5d 1a
			02 02 00 07
			04 00 00 00 00 0b 4D 61 69 6E 20 74 68 72 65 61 64
			05 00 00 00 00 03 41 70 70
			06 02 00 01
			07 01 00 00 00 0c 48 65 6C 6C 6F 2C 20 77 6F 72 6C 64
			0A 03 00 00 00 07
			0B 00 00 00 00 06 6D 61 69 6E 2E 63
			0C 02 00 2a
			0D 00 00 00 00 0e 73 6F 6D 65 46 75 6E 63 74 69 6F 6E 28 29
			""")
		let log = try buffer.readNextLogEntry()
		XCTAssertNotNil(log)
		XCTAssertTrue(log is LogBinaryDataMessage?)

		let message = log as! LogBinaryDataMessage
		XCTAssertEqual(message.sequence, 7)
		XCTAssertEqual(message.timestamp.tv_sec, 1549098266)
		XCTAssertEqual(message.timestamp.tv_usec, 7000)
		XCTAssertEqual(message.tags, ["App"])
		XCTAssertEqual(message.level, 1)
		XCTAssertEqual(message.data, "Hello, world".data(using: .utf8))
		XCTAssertEqual(message.thread, "Main thread")
		XCTAssertEqual(message.filename, "main.c")
		XCTAssertEqual(message.line, 42)
		XCTAssertEqual(message.function, "someFunction()")
	}

	func testDecodeEmptyBinaryDataMessage() throws {
		var buffer = logDataFromHex(
			"""
			00 00 00 1e
			00 05
			0A 03 00 00 00 03
			00 02 00 00
			01 03 5c 55 5d 1a
			04 00 00 00 00 00
			07 01 00 00 00 00
			""")
		let log = try buffer.readNextLogEntry()
		XCTAssertNotNil(log)
		XCTAssertTrue(log is LogBinaryDataMessage?)

		let message = log as! LogBinaryDataMessage
		XCTAssertEqual(message.sequence, 3)
		XCTAssertEqual(message.timestamp.tv_sec, 1549098266)
		XCTAssertEqual(message.timestamp.tv_usec, 0)
		XCTAssertEqual(message.tags, [])
		XCTAssertEqual(message.level, 0)
		XCTAssertEqual(message.data, Data())
		XCTAssertEqual(message.thread, "")
		XCTAssertNil(message.filename)
		XCTAssertNil(message.function)
	}

	func testDecodeImageDataMessageWithoutSize() throws {
		var buffer = logDataFromHex(
			"""
			00 00 00 3e
			00 07
			00 02 00 00
			01 03 5c 55 5d 1a
			04 00 00 00 00 0b 4D 61 69 6E 20 74 68 72 65 61 64
			05 00 00 00 00 03 41 70 70
			06 02 00 01
			07 05 00 00 00 0a 01 02 03 04 05 06 07 08 09 0A
			0A 03 00 00 00 01
			""")

		let log = try buffer.readNextLogEntry()
		XCTAssertNotNil(log)
		XCTAssertTrue(log is LogImageMessage?)

		let message = log as! LogImageMessage
		XCTAssertEqual(message.sequence, 1)
		XCTAssertEqual(message.timestamp.tv_sec, 1549098266)
		XCTAssertEqual(message.timestamp.tv_usec, 0)
		XCTAssertEqual(message.tags, ["App"])
		XCTAssertEqual(message.level, 1)
		XCTAssertEqual(message.imageData, dataFromHex("01 02 03 04 05 06 07 08 09 0A"))
		XCTAssertEqual(message.thread, "Main thread")
		XCTAssertNil(message.filename)
		XCTAssertNil(message.function)
		XCTAssertNil(message.imageWidth)
		XCTAssertNil(message.imageHeight)
	}

	func testDecodeImageDataMessageWithSize() throws {
		var buffer = logDataFromHex(
			"""
			00 00 00 4a
			00 09
			00 02 00 00
			01 03 5c 55 5d 1a
			04 00 00 00 00 0b 4D 61 69 6E 20 74 68 72 65 61 64
			05 00 00 00 00 03 41 70 70
			06 02 00 01
			07 05 00 00 00 0a 01 02 03 04 05 06 07 08 09 0A
			0A 03 00 00 00 01
			08 02 04 00
			09 03 00 00 03 00
			""")

		let log = try buffer.readNextLogEntry()
		XCTAssertNotNil(log)
		XCTAssertTrue(log is LogImageMessage?)

		let message = log as! LogImageMessage
		XCTAssertEqual(message.sequence, 1)
		XCTAssertEqual(message.timestamp.tv_sec, 1549098266)
		XCTAssertEqual(message.timestamp.tv_usec, 0)
		XCTAssertEqual(message.tags, ["App"])
		XCTAssertEqual(message.level, 1)
		XCTAssertEqual(message.imageData, dataFromHex("01 02 03 04 05 06 07 08 09 0A"))
		XCTAssertEqual(message.thread, "Main thread")
		XCTAssertNil(message.filename)
		XCTAssertNil(message.function)
		XCTAssertEqual(message.imageWidth, 1024)
		XCTAssertEqual(message.imageHeight, 768)
	}

	func testDecodeClientInfo() throws {
		var buffer = logDataFromHex(
			"""
			00 00 00 65
			00 06
			00 02 00 03
			14 00 00 00 00 0e 4D 79 20 41 70 70 6C 69 63 61 74 69 6F 6E
			15 00 00 00 00 03 31 2E 30
			19 00 00 00 00 24 36 38 37 31 41 42 32 45 2D 37 32 30 39 2D 34 36 36 31 2D 42 38 44 37 2D 39 31 45 44 37 46 34 41 45 44 30 45
			16 00 00 00 00 05 6D 61 63 4F 53
			17 00 00 00 00 07 31 30 2E 31 34 2E 31
			""")

		let log = try buffer.readNextLogEntry()
		XCTAssertNotNil(log)
		XCTAssertTrue(log is LogClientInfo?)

		let message = log as! LogClientInfo
		XCTAssertEqual(message.clientName, "My Application")
		XCTAssertEqual(message.clientVersion, "1.0")
		XCTAssertEqual(message.clientUID, "6871AB2E-7209-4661-B8D7-91ED7F4AED0E")
		XCTAssertEqual(message.clientModel, "")
		XCTAssertEqual(message.osName, "macOS")
		XCTAssertEqual(message.osVersion, "10.14.1")
	}

	func testDecodeDisconnectMessage() throws {
		var buffer = logDataFromHex(
			"""
			00 00 00 0A
			00 02
			00 02 00 04
			0A 02 00 01
			""")

		let log = try buffer.readNextLogEntry()
		XCTAssertNotNil(log)
		XCTAssertTrue(log is LogDisconnectMessage?)

		let disconnect = log as! LogDisconnectMessage
		XCTAssertEqual(disconnect.sequence, 1)
	}

	func testDecodeMultipleMessages() throws {
		// client info, complete log text message, binary data message, minimal log text message, image message
		var buffer = logDataFromHex(
			"""
			00 00 00 65
			00 06
			00 02 00 03
			14 00 00 00 00 0e 4D 79 20 41 70 70 6C 69 63 61 74 69 6F 6E
			15 00 00 00 00 03 31 2E 30
			19 00 00 00 00 24 36 38 37 31 41 42 32 45 2D 37 32 30 39 2D 34 36 36 31 2D 42 38 44 37 2D 39 31 45 44 37 46 34 41 45 44 30 45
			16 00 00 00 00 05 6D 61 63 4F 53
			17 00 00 00 00 07 31 30 2E 31 34 2E 31

			00 00 00 70
			00 0c
			00 02 00 00
			01 03 5c 55 5d 1a
			02 02 00 07
			03 03 00 00 10 05
			04 00 00 00 00 0b 4D 61 69 6E 20 74 68 72 65 61 64
			05 00 00 00 00 03 41 70 70
			06 02 00 01
			07 00 00 00 00 0c 48 65 6C 6C 6F 2C 20 77 6F 72 6C 64
			0A 03 00 00 00 07
			0B 00 00 00 00 06 6D 61 69 6E 2E 63
			0C 02 00 2a
			0D 00 00 00 00 0e 73 6F 6D 65 46 75 6E 63 74 69 6F 6E 28 29

			00 00 00 6a
			00 0b
			00 02 00 00
			01 03 5c 55 5d 1a
			02 02 00 07
			04 00 00 00 00 0b 4D 61 69 6E 20 74 68 72 65 61 64
			05 00 00 00 00 03 41 70 70
			06 02 00 01
			07 01 00 00 00 0c 48 65 6C 6C 6F 2C 20 77 6F 72 6C 64
			0A 03 00 00 00 07
			0B 00 00 00 00 06 6D 61 69 6E 2E 63
			0C 02 00 2a
			0D 00 00 00 00 0e 73 6F 6D 65 46 75 6E 63 74 69 6F 6E 28 29

			00 00 00 24
			00 05
			00 02 00 00
			01 03 5c 55 5d 1a
			07 00 00 00 00 0c 48 65 6C 6C 6F 2C 20 77 6F 72 6C 64
			0A 03 00 00 00 07

			00 00 00 4a
			00 09
			00 02 00 00
			01 03 5c 55 5d 1a
			04 00 00 00 00 0b 4D 61 69 6E 20 74 68 72 65 61 64
			05 00 00 00 00 03 41 70 70
			06 02 00 01
			07 05 00 00 00 0a 01 02 03 04 05 06 07 08 09 0A
			0A 03 00 00 00 01
			08 02 04 00
			09 03 00 00 03 00
			""")

		// first: client info
		let log = try buffer.readNextLogEntry()
		XCTAssertNotNil(log)
		XCTAssertTrue(log is LogClientInfo?)

		let message = log as! LogClientInfo
		XCTAssertEqual(message.clientName, "My Application")
		XCTAssertEqual(message.clientVersion, "1.0")
		XCTAssertEqual(message.clientUID, "6871AB2E-7209-4661-B8D7-91ED7F4AED0E")
		XCTAssertEqual(message.clientModel, "")
		XCTAssertEqual(message.osName, "macOS")
		XCTAssertEqual(message.osVersion, "10.14.1")

		// second: complete text message
		let log1 = try buffer.readNextLogEntry()
		XCTAssertNotNil(log1)
		XCTAssertTrue(log1 is LogTextMessage?)

		let message1 = log1 as! LogTextMessage
		XCTAssertEqual(message1.sequence, 7)
		XCTAssertEqual(message1.timestamp.tv_sec, 1549098266)
		XCTAssertEqual(message1.timestamp.tv_usec, 11101)
		XCTAssertEqual(message1.tags, ["App"])
		XCTAssertEqual(message1.level, 1)
		XCTAssertEqual(message1.message, "Hello, world")
		XCTAssertEqual(message1.thread, "Main thread")
		XCTAssertEqual(message1.filename, "main.c")
		XCTAssertEqual(message1.line, 42)
		XCTAssertEqual(message1.function, "someFunction()")

		// third: binary data message
		let log2 = try buffer.readNextLogEntry()
		XCTAssertNotNil(log2)
		XCTAssertTrue(log2 is LogBinaryDataMessage?)

		let message2 = log2 as! LogBinaryDataMessage
		XCTAssertEqual(message2.sequence, 7)
		XCTAssertEqual(message2.timestamp.tv_sec, 1549098266)
		XCTAssertEqual(message2.timestamp.tv_usec, 7000)
		XCTAssertEqual(message2.tags, ["App"])
		XCTAssertEqual(message2.level, 1)
		XCTAssertEqual(message2.data, "Hello, world".data(using: .utf8))
		XCTAssertEqual(message2.thread, "Main thread")
		XCTAssertEqual(message2.filename, "main.c")
		XCTAssertEqual(message2.line, 42)
		XCTAssertEqual(message2.function, "someFunction()")

		// fourth: minimal text message
		let log3 = try buffer.readNextLogEntry()
		XCTAssertNotNil(log3)
		XCTAssertTrue(log3 is LogTextMessage?)

		let message3 = log3 as! LogTextMessage
		XCTAssertEqual(message3.sequence, 7)
		XCTAssertEqual(message3.timestamp.tv_sec, 1549098266)
		XCTAssertEqual(message3.timestamp.tv_usec, 0)
		XCTAssertEqual(message3.tags, [])
		XCTAssertEqual(message3.line, 0)
		XCTAssertEqual(message3.filename, nil)
		XCTAssertEqual(message3.function, nil)
		XCTAssertEqual(message3.message, "Hello, world")

		// fifth: image messqge
		let log4 = try buffer.readNextLogEntry()
		XCTAssertNotNil(log4)
		XCTAssertTrue(log4 is LogImageMessage?)

		let message4 = log4 as! LogImageMessage
		XCTAssertEqual(message4.sequence, 1)
		XCTAssertEqual(message4.timestamp.tv_sec, 1549098266)
		XCTAssertEqual(message4.timestamp.tv_usec, 0)
		XCTAssertEqual(message4.tags, ["App"])
		XCTAssertEqual(message4.level, 1)
		XCTAssertEqual(message4.imageData, dataFromHex("01 02 03 04 05 06 07 08 09 0A"))
		XCTAssertEqual(message4.thread, "Main thread")
		XCTAssertNil(message4.filename)
		XCTAssertNil(message4.function)
		XCTAssertEqual(message4.imageWidth, 1024)
		XCTAssertEqual(message4.imageHeight, 768)
	}
}
