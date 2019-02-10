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
import NIO

enum LogDecoderError: Error {
	case incompletePacket
	case invalidLogPacket(String)
	case unsupportedCustomDataType
}

fileprivate let entryHeaderSize = 2

extension ByteBuffer {

	mutating func consumeLogEntry() throws -> LogEntry? {
		guard let (entrySize, type, sequence) = try getNextLogEntry() else {
			return nil
		}
		
		defer { moveReaderIndex(forwardBy: entrySize) }
		
		switch type {
			case .log:
				return try getLogMessage(type: type, size: entrySize, sequence: sequence)
			case .blockstart, .blockend:
				return getBlockDelimiter(type: type, size: entrySize, sequence: sequence)
			case .clientInfo:
				return getClientInfo(size: entrySize, sequence: sequence)
			case .mark:
				return getLogMarker(size: entrySize, sequence: sequence)
			case .disconnect:
				return getDisconnect(sequence: sequence)
		}
	}

	private func getNextLogEntry() throws -> (entrySize: Int, type: MessageType, sequence: Int)? {
		guard self.readableBytes > MemoryLayout<UInt32>.size else {
			return nil
		}
		
		guard let size = getInteger(at: self.readerIndex, as: UInt32.self).map(Int.init), size > 0 && size < 1_000_000_000 else {
			throw LogDecoderError.invalidLogPacket("Missing or spurious log message size")
		}
		
		guard self.readableBytes >= MemoryLayout<UInt32>.size + size else {
			return nil
		}
		
		guard let messageTypeInt: Int = getIntegerPart(key: .messageType),
			let messageType = MessageType(rawValue: messageTypeInt) else {
				throw LogDecoderError.invalidLogPacket("Log entry missing required base components")
		}
		// sequence _may_ be 0, and in the original implementation in this case it is omitted
		let sequence: Int = getIntegerPart(key: .sequenceNumber) ?? 0
		return (entrySize: MemoryLayout<UInt32>.size + size, type: messageType, sequence: sequence)
	}

	func getLogMarker(size: Int, sequence: Int) -> LogMarker {
		return LogMarker(sequence: sequence,
						 mark: getString(key: .logMessage) ?? "")
	}
	
	func getDisconnect(sequence: Int) -> LogDisconnectMessage {
		return LogDisconnectMessage(sequence: sequence)
	}

	func getLogMessage(type: MessageType, size: Int, sequence: Int) throws -> LogEntry? {
		guard let logPart = findPart(key: .logMessage),
			  let timestamp = getTimestamp() else {
			return nil
		}

		let tag = getString(key: .tag)
		let threadID = getString(key: .threadID) ?? ""
		let level: Int = getIntegerPart(key: .level) ?? 0
		let filename = getString(key: .file)
		let function = getString(key: .function)
		let line: Int = getIntegerPart(key: .line) ?? 0
		let userInfo: [Int:Data]? = try collectUserDefinedValues()

		switch logPart.type {
			case .utf8String:
				return LogTextMessage(sequence: sequence,
									  timestamp: timestamp,
									  tag: tag,
									  thread: threadID,
									  level: level,
									  userInfo: userInfo,
									  filename: filename,
									  function: function,
									  line: line,
									  message: getString(at: logPart.dataOffset, length: logPart.dataSize) ?? "")

			case .binaryData:
				guard let data = getData(at: logPart.dataOffset, length: logPart.dataSize) else {
					return nil
				}
				return LogBinaryDataMessage(sequence: sequence,
										timestamp: timestamp,
										tag: tag,
										thread: threadID,
										level: level,
										userInfo: userInfo,
										filename: filename,
										function: function,
										line: line,
										data: data)

			case .imageData:
				guard let data = getData(at: logPart.dataOffset, length: logPart.dataSize) else {
					return nil
				}
				return LogImageMessage(sequence: sequence,
								timestamp: timestamp,
								tag: tag,
								thread: threadID,
								level: level,
								userInfo: userInfo,
								filename: filename,
								function: function,
								line: line,
								imageData: data,
								imageWidth: getIntegerPart(key: .imageWidth),
								imageHeight: getIntegerPart(key: .imageHeight))

			default:
				return nil
		}
	}

	func getClientInfo(size: Int, sequence: Int) -> LogClientInfo? {
		return LogClientInfo(sequence: sequence,
							 clientName: getString(key: .clientName) ?? "",
							 clientVersion: getString(key: .clientVersion) ?? "",
							 clientModel: getString(key: .clientModel) ?? "",
							 clientUID: getString(key: .clientUniqueID) ?? "",
							 osName: getString(key: .osName) ?? "",
							 osVersion: getString(key: .osVersion) ?? "")
	}

	func getBlockDelimiter(type: MessageType, size: Int, sequence: Int) -> LogEntry? {
		return LogBlockDelimiter(sequence: sequence,
								 start: type == .blockstart)
	}

	func getPartInfo(at offset: Int, type: PartType) -> (dataOffset: Int, dataSize: Int)? {
		let dataSize: Int
		let dataOffset: Int
		switch type {
			case .utf8String, .binaryData, .imageData:
				guard let ps = self.getInteger(at: offset, as: UInt32.self) else {
					return nil
				}
				dataOffset = offset + MemoryLayout<UInt32>.size
				dataSize = Int(ps)

			case .int16:
				dataOffset = offset
				dataSize = MemoryLayout<UInt16>.size

			case .int32:
				dataOffset = offset
				dataSize = MemoryLayout<UInt32>.size

			case .int64:
				dataOffset = offset
				dataSize = MemoryLayout<UInt64>.size
		}
		return (dataOffset: dataOffset, dataSize: dataSize)
	}

	func getPart(at offset: Int) -> (key: Int, type: PartType, dataOffset: Int, dataSize: Int)? {
		guard let key: UInt8 = getInteger(at: offset),
			  let type = getInteger(at: offset + 1).flatMap(PartType.from),
			  let partInfo = getPartInfo(at: offset + 2, type: type) else {
			return nil
		}
		return (key: Int(key), type: type, dataOffset: partInfo.dataOffset, dataSize: partInfo.dataSize)
	}

	func collectUserDefinedValues() throws -> [Int:Data]? {
		var collection: [Int:Data]? = nil
		guard let numberOfParts = self.getInteger(at: self.readerIndex + MemoryLayout<UInt32>.size, as: UInt16.self).flatMap(Int.init) else {
			return nil
		}
		var currentOffset = self.readerIndex + MemoryLayout<UInt32>.size + MemoryLayout<UInt16>.size
		for _ in 0 ..< numberOfParts {
			guard let key = getInteger(at: currentOffset, as: UInt8.self),
				  key >= PartKey.firstCustomDataKey.rawValue,
				  let type = getInteger(at: currentOffset + 1).flatMap(PartType.from),
				  let (dataOffset, dataSize) = getPartInfo(at: currentOffset + 2, type: type) else {
				return nil
			}
			guard case .binaryData = type else {
				throw LogDecoderError.unsupportedCustomDataType
			}
			if let data = getData(at: dataOffset, length: dataSize) {
				if collection == nil {
					collection = [Int(key):data]
				} else {
					collection![Int(key)] = data
				}
			}
			currentOffset = dataOffset + dataSize
		}
		return collection
	}

	func findPart(key: PartKey) -> (type: PartType, dataOffset: Int, dataSize: Int)? {
		guard let numberOfParts = self.getInteger(at: self.readerIndex + MemoryLayout<UInt32>.size, as: UInt16.self).flatMap(Int.init) else {
			return nil
		}
		var currentOffset = self.readerIndex + MemoryLayout<UInt32>.size + MemoryLayout<UInt16>.size
		for _ in 0..<numberOfParts {
			guard let part = getPart(at: currentOffset) else {
				return nil
			}
			if part.key == key.rawValue {
				return (type: part.type, dataOffset: part.dataOffset, dataSize: part.dataSize)
			}
			currentOffset = part.dataOffset + part.dataSize
		}
		return nil
	}

	func getIntegerPart<T>(key: PartKey) -> T? where T: FixedWidthInteger {
		guard let (partType, dataOffset, _) = findPart(key: key) else {
			return nil
		}
		switch partType {
			case .int16:
				guard let partValue = self.getInteger(at: dataOffset, as: Int16.self) else {
					return nil
				}
				return T(partValue)
			case .int32:
				guard let partValue = self.getInteger(at: dataOffset, as: Int32.self) else {
					return nil
				}
				return T(partValue)
			case .int64:
				guard let partValue = self.getInteger(at: dataOffset, as: Int64.self) else {
					return nil
				}
				return T(partValue)
			default:
				return nil
		}
	}

	func getTimestamp() -> LogTimestamp? {
		guard let seconds: Int = getIntegerPart(key: .timestampSeconds) else {
			return nil
		}
		var microseconds: Int32 = 0
		if let ms: Int32 = getIntegerPart(key: .timestampMilliseconds) {
			microseconds = ms * 1000
		}
		if let us: Int32 = getIntegerPart(key: .timestampMicroseconds) {
			microseconds += us
		}
		return timeval(tv_sec: seconds, tv_usec: microseconds)
	}

	func getString(key: PartKey) -> String? {
		guard let part = findPart(key: key), part.type == .utf8String else {
			return nil
		}
		return self.getString(at: part.dataOffset, length: part.dataSize)
	}

	func getData(at offset: Int, length: Int) -> Data? {
		return self.withVeryUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> Data? in
			guard let baseAddress = pointer.baseAddress else {
				return nil
			}
			return Data(bytes: baseAddress.advanced(by: offset), count: length)
		}
	}
}
