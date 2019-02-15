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
				guard s.count == 2, let byte = UInt8(s, radix: 16) else {
					fatalError("invalid hex string: \(data)")
				}
				return byte
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
