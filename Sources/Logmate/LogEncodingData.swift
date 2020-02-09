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
import ObjectiveC

struct AssociatedKeys {
	static var readerIndexKey: UInt8 = 0
}

struct LogEncodingData {
	var data: Data
	var nextReadPosition: Int
	var nextWritePosition: Int {
		data.count
	}

	init(data: Data) {
		// initialize for reading existing, appending when writing
		self.data = data
		nextReadPosition = 0
	}

	init(referencing data: NSData) {
		// initialize for reading existing, appending when writing
		self.data = Data(referencing: data)
		nextReadPosition = 0
	}
}

extension LogEncodingData: _LogReader {
	var readableBytes: Int {
		data.count - nextReadPosition
	}

	public mutating func moveNextReadPosition(forwardBy increment: Int) {
		precondition(nextReadPosition + increment <= data.count)
		nextReadPosition += increment
	}

	public func getInteger<T: FixedWidthInteger>(at index: Int, as: T.Type) -> T? {
		precondition(index >= 0, "index must not be negative")
		precondition(index + MemoryLayout<T>.size <= data.count, "value size must not overflow data size")
		return data.withUnsafeBytes { dataPointer in
			guard index <= dataPointer.count - MemoryLayout<T>.size else {
				return nil
			}
// we can't directly use a `load` operation because this one requires
// the pointer to be aligned on the type size. Have to go for the
// slower options duh
			switch MemoryLayout<T>.size {
				case 1:
					return T(dataPointer[index])
				case 2:
					return (T(dataPointer[index]) << 8) | T(dataPointer[index + 1])
				case 4:
					return T((UInt32(dataPointer[index]) << 24) |
							 (UInt32(dataPointer[index + 1]) << 16) |
							 (UInt32(dataPointer[index + 2]) << 8) |
							 UInt32(dataPointer[index + 3]))
				case 8:
					let intermediate = (UInt64(dataPointer[index]) << 56) |
									   (UInt64(dataPointer[index + 1]) << 48) |
									   (UInt64(dataPointer[index + 2]) << 40) |
									   (UInt64(dataPointer[index + 3]) << 32) |
									   (UInt64(dataPointer[index + 4]) << 24) |
									   (UInt64(dataPointer[index + 5]) << 16) |
									   (UInt64(dataPointer[index + 6]) << 8) |
									   UInt64(dataPointer[index + 7])
					return T(intermediate)
				default:
					return 0
			}
		}
	}

	public func getString(at index: Int, length: Int) -> String? {
		guard let data = getData(at: index, length: length) else {
			return nil
		}
		return String(data: data, encoding: .utf8)
	}

	public func getData(at: Int, length: Int) -> Data? {
		guard length >= 0 else { return nil }
		if length == 0 {
			return Data()
		}
		let from = data.startIndex.advanced(by: at)
		let to = from.advanced(by: length)
		precondition(from >= data.startIndex && from < data.endIndex, "start index (\(at)) must be in Data range (\(data.startIndex) ... \(data.endIndex))")
		precondition(to <= data.endIndex, "length must reference bytes in Data range from start (0 ..< \(data.endIndex - from)")
		return data.subdata(in: from..<to)
	}
}

extension LogEncodingData: LogReader {
	public var totalSize: Int {
		data.count
	}
}

extension LogEncodingData: _LogWriter {
	public mutating func write<T>(integer: T) where T: FixedWidthInteger {
		let wantedCapacity = (((data.count + MemoryLayout<T>.size) / 128) + 1) * 128
		data.reserveCapacity(wantedCapacity)
		let value = integer.bigEndian
		Swift.withUnsafePointer(to: value) { valuePointer in
			data.append(UnsafeBufferPointer(start: valuePointer, count: 1))
		}
	}

	public mutating func update<T>(integer: T, at: Int) where T: FixedWidthInteger {
		data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
			var value = integer.bigEndian
			_ = Swift.withUnsafeBytes(of: &value) { (valuePointer: UnsafeRawBufferPointer) in
				for i in 0..<MemoryLayout<T>.size {
					let c: UInt8 = valuePointer[i]
					pointer.storeBytes(of: c, toByteOffset: at + i, as: UInt8.self)
				}
			}
		}
	}

	public mutating func write(data d: Data) {
		data.append(d)
	}

	public mutating func write(string: String) -> Int? {
		guard let d = string.data(using: .utf8) else {
			return nil
		}
		data.append(d)
		return d.count
	}
}

extension LogEncodingData: LogWriter {
}
