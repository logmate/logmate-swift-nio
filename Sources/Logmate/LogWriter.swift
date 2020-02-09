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

public protocol LogWriter {
	mutating func write(_ entry: LogEntry) throws
}

public protocol _LogWriter {
	var nextWritePosition: Int { get }
	
	mutating func write<T: FixedWidthInteger>(integer: T)
	mutating func update<T: FixedWidthInteger>(integer: T, at: Int)
	mutating func write(data: Data)
	mutating func write(string: String) -> Int?
}

extension LogWriter where Self: _LogWriter {
	public mutating func write(_ entry: LogEntry) throws {
		switch entry {
		case let message as LogMessage:
			try append(message)
		case let clientInfo as LogClientInfo:
			try append(clientInfo)
		case let delimiter as LogBlockDelimiter:
			try append(delimiter)
		case let marker as LogMarker:
			try append(marker)
		case let disconnect as LogDisconnectMessage:
			try append(disconnect)
		default:
			throw LogWriterError.unsupportedLogType
		}
	}

	fileprivate mutating func append(_ disconnect: LogDisconnectMessage) throws {
		let startIndex = try prepareMessage(disconnect.sequence)
		try write(key: .messageType, integer: Int16(MessageType.disconnect.rawValue))
		finalizeMessage(startIndex, partCount: 1 + 1)
	}

	fileprivate mutating func append(_ clientInfo: LogClientInfo) throws {
		let startIndex = try prepareMessage(clientInfo.sequence)
		try write(key: .messageType, integer: Int16(MessageType.clientInfo.rawValue))
		try write(key: .clientName, string: clientInfo.clientName)
		try write(key: .clientModel, string: clientInfo.clientModel)
		try write(key: .clientUniqueID, string: clientInfo.clientUID)
		try write(key: .clientVersion, string: clientInfo.clientVersion)
		try write(key: .osName, string: clientInfo.osName)
		try write(key: .osVersion, string: clientInfo.osVersion)
		finalizeMessage(startIndex, partCount: 7 + 1)
	}

	fileprivate mutating func append(_ mark: LogMarker) throws {
		let startIndex = try prepareMessage(mark.sequence)
		try write(key: .messageType, integer: Int16(MessageType.mark.rawValue))
		try write(key: .logMessage, string: mark.mark)
		finalizeMessage(startIndex, partCount: 2 + 1)
	}

	fileprivate mutating func append(_ delimiter: LogBlockDelimiter) throws {
		let startIndex = try prepareMessage(delimiter.sequence)
		try write(key: .messageType, integer: Int16(delimiter.start ? MessageType.blockstart.rawValue : MessageType.blockend.rawValue))
		finalizeMessage(startIndex, partCount: 1 + 1)
	}

	fileprivate mutating func append(_ log: LogMessage) throws {
		let startIndex = try prepareMessage(log.sequence)
		try write(key: .messageType, integer: Int16(MessageType.log.rawValue))
		try write(key: .timestampSeconds, integer: log.timestamp.tv_sec)
		try write(key: .timestampMicroseconds, integer: log.timestamp.tv_usec)
		try write(key: .threadID, string: log.thread)

		var parts = 5 + 1 // +1 = future write of LogMessage
		for tag in log.tags {
			parts += 1
			try write(key: .tag, string: tag)
		}

		if log.level > 0 {
			parts += 1
			try writeShortly(key: .level, integer: log.level)
		}

		if let userInfo = log.userInfo {
			for (key,data) in userInfo {
				parts += 1
				write(integer: Int16(key) << 8 | Int16(PartType.binaryData.rawValue))
				write(integer: UInt32(data.count))
				if data.count > 0 {
					write(data: data)
				}
			}
		}

		if let filename = log.filename, !filename.isEmpty {
			parts += 1
			try write(key: .file, string: filename)
		}

		if let function = log.function, !function.isEmpty {
			parts += 1
			try write(key: .function, string: function)
		}

		if let line = log.line, line != 0 {
			parts += 1
			try writeShortly(key: .line, integer: line)
		}

		switch log {
		case let textMessage as LogTextMessage:
			try write(key: .logMessage, string: textMessage.message)
		case let binaryDataMessage as LogBinaryDataMessage:
			write(key: .logMessage, data: binaryDataMessage.data)
		case let imageDataMessage as LogImageMessage:
			write(key: .logMessage, image: imageDataMessage.imageData)
			if let imageWidth = imageDataMessage.imageWidth, imageWidth > 0 {
				parts += 1
				try writeShortly(key: .imageWidth, integer: imageWidth)
			}
			if let imageHeight = imageDataMessage.imageHeight, imageHeight > 0 {
				parts += 1
				try writeShortly(key: .imageHeight, integer: imageHeight)
			}
		default:
			throw LogWriterError.unsupportedLogType
		}

		finalizeMessage(startIndex, partCount: parts)
	}

	fileprivate mutating func prepareMessage(_ seq: Int) throws -> Int {
		let index = self.nextWritePosition
		write(integer: UInt32(2))
		write(integer: UInt16(1))
		try writeShortly(key: PartKey.sequenceNumber, integer: seq)
		return index
	}

	fileprivate mutating func finalizeMessage(_ startIndex: Int, partCount: Int) {
		let size = UInt32(self.nextWritePosition - startIndex - MemoryLayout<UInt32>.size)
		update(integer: size, at: startIndex)
		update(integer: UInt16(partCount), at: startIndex + MemoryLayout<UInt32>.size)
	}

	fileprivate mutating func write(key: PartKey, string: String) throws {
		write(integer: UInt16(key.rawValue) << 8 | UInt16(PartType.utf8String.rawValue))
		let offset = self.nextWritePosition
		write(integer: UInt32(0))
		guard let size = write(string: string) else {
			throw LogWriterError.stringWriteError
		}
		update(integer: UInt32(size), at: offset)
	}

	fileprivate mutating func write(key: PartKey, data: Data) {
		write(integer: UInt16(key.rawValue) << 8 | UInt16(PartType.binaryData.rawValue))
		write(integer: UInt32(data.count))
		write(data: data)
	}

	fileprivate mutating func write(key: PartKey, image data: Data) {
		write(integer: UInt16(key.rawValue) << 8 | UInt16(PartType.imageData.rawValue))
		write(integer: UInt32(data.count))
		write(data: data)
	}

	fileprivate mutating func writeShortly(key: PartKey, integer value: Int) throws {
		if value <= Int16.max {
			try write(key: key, integer: Int16(value))
		} else if value <= Int32.max {
			try write(key: key, integer: Int32(value))
		} else {
			try write(key: key, integer: value)
		}
	}

	fileprivate mutating func write<T: FixedWidthInteger>(key: PartKey, integer value: T) throws {
		switch value.bitWidth {
			case 8:
				try write(key: key, integer: UInt16(value))
			case 16:
				write(integer: UInt16(key.rawValue) << 8 | UInt16(PartType.int16.rawValue))
				write(integer: value)
			case 32:
				write(integer: UInt16(key.rawValue) << 8 | UInt16(PartType.int32.rawValue))
				write(integer: value)
			case 64:
				write(integer: UInt16(key.rawValue) << 8 | UInt16(PartType.int64.rawValue))
				write(integer: value)
			default:
				throw LogWriterError.unsupportedIntegerSize(value.bitWidth)
		}
	}

}
