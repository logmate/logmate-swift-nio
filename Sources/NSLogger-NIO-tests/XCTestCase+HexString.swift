//
// Created by Florent Pillet on 2019-02-02.
//

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
