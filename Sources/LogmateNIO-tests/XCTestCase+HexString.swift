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

fileprivate let hex = [Character("0"),
					   Character("1"),
					   Character("2"),
					   Character("3"),
					   Character("4"),
					   Character("5"),
					   Character("6"),
					   Character("7"),
					   Character("8"),
					   Character("9"),
					   Character("A"),
					   Character("B"),
					   Character("C"),
					   Character("D"),
					   Character("E"),
					   Character("F")]

extension XCTestCase {
	func bytesFromHex(_ data: String) -> [UInt8] {
		guard !data.isEmpty else {
			return []
		}
		return data
			.uppercased()
			.components(separatedBy: .whitespacesAndNewlines)
			.compactMap { (string: String) -> UInt8? in
				let s = string.trimmingCharacters(in: .whitespacesAndNewlines)
				guard !s.isEmpty else {
					return nil
				}
				guard s.count == 2,
					  let high = hex.firstIndex(of: string[string.startIndex]),
					  let low = hex.firstIndex(of: string[string.index(after: string.startIndex)]) else {
					fatalError("invalid hex string: \(data)")
				}
				return UInt8(high) << 4 | UInt8(low)
			}
	}

	func dataFromHex(_ data: String) -> Data {
		return Data(bytes: bytesFromHex(data))
	}

	func bufferFromHex(_ data: String) -> ByteBuffer {
		let bytes = bytesFromHex(data)
		var buffer = ByteBufferAllocator().buffer(capacity: bytes.count)
		buffer.write(bytes: bytes)
		return buffer
	}
}
