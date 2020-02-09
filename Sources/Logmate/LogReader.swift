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

fileprivate let entryHeaderSize = 2

public protocol LogReader {
	var totalSize: Int { get }

	mutating func readNextLogEntry() throws -> LogEntry?
}

public protocol _LogReader {
	var readableBytes: Int { get }
	var nextReadPosition: Int { get }
	
	mutating func moveNextReadPosition(forwardBy: Int)
	
	func getInteger<T: FixedWidthInteger>(at index: Int, as: T.Type) -> T?
	func getString(at index: Int, length: Int) -> String?
	func getData(at: Int, length: Int) -> Data?
}

extension LogReader where Self: _LogReader {
	var totalSize: Int { readableBytes }

	public mutating func readNextLogEntry() throws -> LogEntry? {
		guard let (entrySize, type, sequence) = try getNextLogEntry() else {
			return nil
		}
		
		defer { moveNextReadPosition(forwardBy: entrySize) }
		
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
}

extension _LogReader {
	fileprivate func getNextLogEntry() throws -> (entrySize: Int, type: MessageType, sequence: Int)? {
		guard self.readableBytes > MemoryLayout<UInt32>.size else {
			return nil
		}
		
		guard let size = getInteger(at: nextReadPosition, as: UInt32.self).map(Int.init), size > 0 && size < 1_000_000_000 else {
			throw LogReaderError.invalidLogPacket("Missing or spurious log message size")
		}
		
		guard self.readableBytes >= MemoryLayout<UInt32>.size + size else {
			return nil
		}
		
		guard let messageTypeInt: Int = getIntegerPart(key: .messageType),
			let messageType = MessageType(rawValue: messageTypeInt) else {
				throw LogReaderError.invalidLogPacket("Log entry missing required base components")
		}
		// sequence _may_ be 0, and in the original implementation in this case it is omitted
		let sequence: Int = getIntegerPart(key: .sequenceNumber) ?? 0
		return (entrySize: MemoryLayout<UInt32>.size + size, type: messageType, sequence: sequence)
	}

	fileprivate func getLogMarker(size: Int, sequence: Int) -> LogMarker {
		return LogMarker(sequence: sequence,
						 mark: getString(key: .logMessage) ?? "")
	}
	
	fileprivate func getDisconnect(sequence: Int) -> LogDisconnectMessage {
		return LogDisconnectMessage(sequence: sequence)
	}

	fileprivate func getLogMessage(type: MessageType, size: Int, sequence: Int) throws -> LogEntry? {
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

	fileprivate func getClientInfo(size: Int, sequence: Int) -> LogClientInfo? {
		return LogClientInfo(sequence: sequence,
							 clientName: getString(key: .clientName) ?? "",
							 clientVersion: getString(key: .clientVersion) ?? "",
							 clientModel: getString(key: .clientModel) ?? "",
							 clientUID: getString(key: .clientUniqueID) ?? "",
							 osName: getString(key: .osName) ?? "",
							 osVersion: getString(key: .osVersion) ?? "")
	}

	fileprivate func getBlockDelimiter(type: MessageType, size: Int, sequence: Int) -> LogEntry? {
		return LogBlockDelimiter(sequence: sequence,
								 start: type == .blockstart)
	}

	fileprivate func getPartInfo(at offset: Int, type: PartType) -> (dataOffset: Int, dataSize: Int)? {
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

	fileprivate func getPart(at offset: Int) -> (key: Int, type: PartType, dataOffset: Int, dataSize: Int)? {
		guard let key = getInteger(at: offset, as: UInt8.self),
			let type = getInteger(at: offset + 1, as: UInt8.self).flatMap(PartType.from),
			let partInfo = getPartInfo(at: offset + 2, type: type) else {
				return nil
		}
		return (key: Int(key), type: type, dataOffset: partInfo.dataOffset, dataSize: partInfo.dataSize)
	}

	fileprivate func collectUserDefinedValues() throws -> [Int:Data]? {
		var collection: [Int:Data]? = nil
		guard let numberOfParts = self.getInteger(at: nextReadPosition + MemoryLayout<UInt32>.size, as: UInt16.self).flatMap(Int.init) else {
			return nil
		}
		var currentOffset = nextReadPosition + MemoryLayout<UInt32>.size + MemoryLayout<UInt16>.size
		for _ in 0 ..< numberOfParts {
			guard let key = getInteger(at: currentOffset, as: UInt8.self),
				key >= PartKey.firstCustomDataKey.rawValue,
				let type = getInteger(at: currentOffset + 1, as: UInt8.self).flatMap(PartType.from),
				let (dataOffset, dataSize) = getPartInfo(at: currentOffset + 2, type: type) else {
					return nil
			}
			guard case .binaryData = type else {
				throw LogReaderError.unsupportedCustomDataType
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

	fileprivate func findPart(key: PartKey) -> (type: PartType, dataOffset: Int, dataSize: Int)? {
		let position = nextReadPosition
		guard let numberOfParts = self.getInteger(at: position + MemoryLayout<UInt32>.size, as: UInt16.self).flatMap(Int.init) else {
			return nil
		}
		var currentOffset = position + MemoryLayout<UInt32>.size + MemoryLayout<UInt16>.size
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

	fileprivate func getIntegerPart<T>(key: PartKey) -> T? where T: FixedWidthInteger {
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

	fileprivate func getTimestamp() -> LogTimestamp? {
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

	fileprivate func getString(key: PartKey) -> String? {
		guard let part = findPart(key: key), part.type == .utf8String else {
			return nil
		}
		return self.getString(at: part.dataOffset, length: part.dataSize)
	}

}
