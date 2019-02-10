// Copyright © 2019 Florent Pillet
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
import NIO
@testable import LogmateNIO

final class ByteBuffer_LogWriterTests: XCTestCase {
	
	lazy var referenceTime: LogTimestamp = timeval(tv_sec: Int(Date().timeIntervalSinceReferenceDate), tv_usec: 12345)
	
	func testShortIntegerWrites() throws {
		let entry = LogDisconnectMessage(sequence: Int(Int16.max))
		var buffer = ByteBufferAllocator().buffer(capacity: 0)
		try buffer.write(entry)
		XCTAssertEqual(buffer.writerIndex,
					   MemoryLayout<UInt32>.size +
						MemoryLayout<UInt16>.size +
						MemoryLayout<UInt16>.size + MemoryLayout<UInt16>.size +		// seq. number
						MemoryLayout<UInt16>.size + MemoryLayout<UInt16>.size)		// message type

	}

	func testMediumIntegerWrites() throws {
		let entry = LogDisconnectMessage(sequence: Int(Int32.max))
		var buffer = ByteBufferAllocator().buffer(capacity: 0)
		try buffer.write(entry)
		XCTAssertEqual(buffer.writerIndex,
					   MemoryLayout<UInt32>.size +
						MemoryLayout<UInt16>.size +
						MemoryLayout<UInt16>.size + MemoryLayout<UInt32>.size +		// seq. number
						MemoryLayout<UInt16>.size + MemoryLayout<UInt16>.size)		// message type
		
	}

	func testLongIntegerWrites() throws {
		let entry = LogDisconnectMessage(sequence: Int(Int64.max))
		var buffer = ByteBufferAllocator().buffer(capacity: 0)
		try buffer.write(entry)
		XCTAssertEqual(buffer.writerIndex,
					   MemoryLayout<UInt32>.size +
						MemoryLayout<UInt16>.size +
						MemoryLayout<UInt16>.size + MemoryLayout<UInt64>.size +		// seq. number
						MemoryLayout<UInt16>.size + MemoryLayout<UInt16>.size)		// message type
		
	}

	func testMinimalEmptyLogTextMessage() throws {
		let message = LogTextMessage(sequence: 1,
									 timestamp: referenceTime,
									 thread: "",
									 level: 0,
									 message: "")
		try	writeConsumeAndCompareMessage(message)
	}
	
	func testMinimalLogTextMessage() throws {
		let message = LogTextMessage(sequence: 1,
										 timestamp: referenceTime,
										 thread: "Main thread",
										 level: 0,
										 message: "Some log message")
		try	writeConsumeAndCompareMessage(message)
	}
	
	func testCompleteLogTextMessage() throws {
		let message = LogTextMessage(sequence: 2342,
									 timestamp: referenceTime,
									 tag: "some tag",
									 thread: "Main thread",
									 level: 8,
									 filename: "main.swift",
									 function: "main()",
									 line: 19,
									 message: "Some log message")
		try	writeConsumeAndCompareMessage(message)
	}
	
	func testLogTextMessageWithEmptyUserInfo() throws {
		let message = LogTextMessage(sequence: 1,
									 timestamp: referenceTime,
									 thread: "Main thread",
									 level: 0,
									 userInfo: [:],
									 message: "Some log message")
		try	writeConsumeAndCompareMessage(message)
	}
	
	func testLogTextMessageWithUserInfo() throws {
		let message = LogTextMessage(sequence: 1,
									 timestamp: referenceTime,
									 thread: "Main thread",
									 level: 0,
									 userInfo: [
										PartKey.firstCustomDataKey.rawValue: Data(),
										PartKey.firstCustomDataKey.rawValue + 1: dataFromHex("FF CC 43 43 62 10 01 0E")],
									 message: "Some log message")
		try	writeConsumeAndCompareMessage(message)
	}
	
	func testMinimalEmptyBinaryDataMessage() throws {
		let message = LogBinaryDataMessage(sequence: 6534534,
										   timestamp: referenceTime,
										   thread: "some thread",
										   level: 0,
										   data: Data())
		try	writeConsumeAndCompareMessage(message)
	}
	
	func testMinimalBinaryDataMessage() throws {
		let message = LogBinaryDataMessage(sequence: 6534534,
										   timestamp: referenceTime,
										   thread: "some thread",
										   level: 0,
										   data: dataFromHex("01 02 03 04 05 06 07 08 09 AA BB CC DD EE FF 00"))
		try	writeConsumeAndCompareMessage(message)
	}

	func testCompleteBinaryDataMessage() throws {
		let message = LogBinaryDataMessage(sequence: 234523423,
										   timestamp: referenceTime,
										   tag: "some tag",
										   thread: "some thread",
										   level: 1,
										   userInfo: nil,
										   filename: "someFile.swift",
										   function: "someLongFunctionName(withArguments:andMore:)",
										   line: 123456,
										   data: dataFromHex("01 02 03 04 05 06 07 08 09 AA BB CC DD EE FF 00"))
		try	writeConsumeAndCompareMessage(message)
	}
	
	func testBinaryDataMessageWithUserInfo() throws {
		let message = LogBinaryDataMessage(sequence: 6534534,
										   timestamp: referenceTime,
										   thread: "some thread",
										   level: 0,
										   userInfo: [
											PartKey.firstCustomDataKey.rawValue: Data(),
											PartKey.firstCustomDataKey.rawValue + 1: dataFromHex("FF CC 43 43 62 10 01 0E")],
										   data: dataFromHex("01 02 03 04 05 06 07 08 09 AA BB CC DD EE FF 00"))
		try	writeConsumeAndCompareMessage(message)
	}

	func testMinimalEmptyImageDataMessage() throws {
		let message = LogImageMessage(sequence: 6534534,
									  timestamp: referenceTime,
									  thread: "some thread",
									  level: 0,
									  imageData: Data())
		try	writeConsumeAndCompareMessage(message)
	}
	
	func testMinimalImageDataMessage() throws {
		let message = LogImageMessage(sequence: 6534534,
										   timestamp: referenceTime,
										   thread: "some thread",
										   level: 0,
										   imageData: dataFromHex("01 02 03 04 05 06 07 08 09 AA BB CC DD EE FF 00"))
		try	writeConsumeAndCompareMessage(message)
	}
	
	func testCompleteImageDataMessage() throws {
		let message = LogImageMessage(sequence: 234523423,
										   timestamp: referenceTime,
										   tag: "some tag",
										   thread: "some thread",
										   level: 1,
										   userInfo: nil,
										   filename: "someFile.swift",
										   function: "someLongFunctionName(withArguments:andMore:)",
										   line: 123456,
										   imageData: dataFromHex("01 02 03 04 05 06 07 08 09 AA BB CC DD EE FF 00"),
										   imageWidth: 640,
										   imageHeight: 480)
		
		try writeConsumeAndCompareMessage(message)
	}
	
	func testDisconnectMessage() throws {
		let message = LogDisconnectMessage(sequence: 12345)
		try writeConsumeAndCompareMessage(message)
	}

	func testClientInfoMessage() throws {
		let message = LogClientInfo(sequence: 1,
									clientName: "TestApplication",
									clientVersion: "1.0",
									clientModel: "MacBookPro",
									clientUID: "2312313131231312312312312",
									osName: "macOS",
									osVersion: "10.14")
		try writeConsumeAndCompareMessage(message)
	}
	
	func testLogMarkerMessage() throws {
		let message = LogMarker(sequence: 23423, mark: "Some test mark")
		try writeConsumeAndCompareMessage(message)
	}
	
	func testBlockStartDelimiterMessage() throws {
		let message = LogBlockDelimiter(sequence: 121231, start: true)
		try writeConsumeAndCompareMessage(message)
	}
	
	func testBlockEndDelimiterMessage() throws {
		let message = LogBlockDelimiter(sequence: 121231, start: false)
		try writeConsumeAndCompareMessage(message)
	}
	
	func testMultipleMessagesInSameBuffer() throws {
		let message1 = LogClientInfo(sequence: 1,
									clientName: "TestApplication",
									clientVersion: "1.0",
									clientModel: "MacBookPro",
									clientUID: "2312313131231312312312312",
									osName: "macOS",
									osVersion: "10.14")

		let message2 = LogTextMessage(sequence: 1,
									 timestamp: referenceTime,
									 thread: "Main thread",
									 level: 0,
									 userInfo: [
										PartKey.firstCustomDataKey.rawValue: Data(),
										PartKey.firstCustomDataKey.rawValue + 1: dataFromHex("FF CC 43 43 62 10 01 0E")],
									 message: "Some log message")

		let message3 = LogImageMessage(sequence: 6534534,
									  timestamp: referenceTime,
									  thread: "some thread",
									  level: 0,
									  imageData: dataFromHex("01 02 03 04 05 06 07 08 09 AA BB CC DD EE FF 00"))
		
		let message4 = LogBinaryDataMessage(sequence: 6534534,
										   timestamp: referenceTime,
										   thread: "some thread",
										   level: 0,
										   userInfo: [
											PartKey.firstCustomDataKey.rawValue: Data(),
											PartKey.firstCustomDataKey.rawValue + 1: dataFromHex("FF CC 43 43 62 10 01 0E")],
										   data: dataFromHex("01 02 03 04 05 06 07 08 09 AA BB CC DD EE FF 00"))

		let message5 = LogMarker(sequence: 23423, mark: "Some test mark")

		let message6 = LogDisconnectMessage(sequence: 12345)

		var buffer = ByteBufferAllocator().buffer(capacity: 0)
		try buffer.write(message1)
		try buffer.write(message2)
		try buffer.write(message3)
		try buffer.write(message4)
		try buffer.write(message5)
		try buffer.write(message6)

		try consumeAndCompareMessage(buffer: &buffer, message: message1)
		try consumeAndCompareMessage(buffer: &buffer, message: message2)
		try consumeAndCompareMessage(buffer: &buffer, message: message3)
		try consumeAndCompareMessage(buffer: &buffer, message: message4)
		try consumeAndCompareMessage(buffer: &buffer, message: message5)
		try consumeAndCompareMessage(buffer: &buffer, message: message6)
	}
	
	fileprivate func consumeAndCompareMessage<T:LogEntry>(buffer: inout ByteBuffer, message: T) throws {
		let result = try buffer.consumeLogEntry()
		XCTAssertNotNil(result)
		XCTAssertTrue(result is T)
		XCTAssertEqual(result as! T, message)
	}

	fileprivate func writeConsumeAndCompareMessage<T:LogEntry>(_ message: T) throws {
		var buffer = ByteBufferAllocator().buffer(capacity: 0)
		try buffer.write(message)
		XCTAssertNotEqual(buffer.writerIndex, 0)
		
		try consumeAndCompareMessage(buffer: &buffer, message: message)
	}
}
