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

public typealias LogTimestamp = timeval

public class LogEntry {
	public let sequence: Int

	public init(sequence: Int) {
		self.sequence = sequence
	}
}

public final class LogDisconnectMessage: LogEntry {
}

public final class LogBlockDelimiter: LogEntry {
	public let start: Bool

	public init(sequence: Int, start: Bool) {
		self.start = start
		super.init(sequence: sequence)
	}
}

public final class LogMarker: LogEntry {
	public let mark: String

	public init(sequence: Int, mark: String) {
		self.mark = mark
		super.init(sequence: sequence)
	}
}

public final class LogClientInfo: LogEntry {
	public let clientName: String
	public let clientVersion: String
	public let clientModel: String
	public let clientUID: String
	public let osName: String
	public let osVersion: String

	public init(sequence: Int, clientName: String, clientVersion: String, clientModel: String, clientUID: String, osName: String, osVersion: String) {
		self.clientName = clientName
		self.clientVersion = clientVersion
		self.clientModel = clientModel
		self.clientUID = clientUID
		self.osName = osName
		self.osVersion = osVersion
		super.init(sequence: sequence)
	}
}

public class LogMessage: LogEntry {
	public let timestamp: LogTimestamp
	public let tags: [String]
	public let thread: String
	public let level: Int
	public let userInfo: [Int:Data]?
	public let filename: String?
	public let function: String?
	public let line: Int?

	init(sequence: Int, timestamp: LogTimestamp, tags: [String], thread: String, level: Int, userInfo: [Int:Data]?, filename: String?, function: String?, line: Int?) {
		self.timestamp = timestamp
		self.tags = tags
		self.thread = thread
		self.level = level
		self.userInfo = userInfo
		self.filename = filename
		self.function = function
		self.line = line
		super.init(sequence: sequence)
	}
}

extension LogMessage {
	public var date: Date {
		#if os(Linux)
		return Date(timeIntervalSince1970: TimeInterval(timestamp.tv_sec) +
										   TimeInterval(timestamp.tv_usec) / 1_000_000.0)
		#else
		return Date(timeIntervalSince1970: TimeInterval(timestamp.tv_sec) +
										   TimeInterval(timestamp.tv_usec) / 1_000_000.0)
		#endif
	}
}

public final class LogTextMessage: LogMessage {
	public let message: String

	public init(sequence: Int, timestamp: LogTimestamp, tags: [String], thread: String, level: Int, userInfo: [Int:Data]? = nil, filename: String? = nil, function: String? = nil, line: Int? = nil, message: String) {
		self.message = message
		super.init(sequence: sequence, timestamp: timestamp, tags: tags, thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}

	public init(sequence: Int, timestamp: LogTimestamp, tag: String? = nil, thread: String, level: Int, userInfo: [Int:Data]? = nil, filename: String? = nil, function: String? = nil, line: Int? = nil, message: String) {
		self.message = message
		super.init(sequence: sequence, timestamp: timestamp, tags: tag.flatMap { [$0] } ?? [], thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}
}

public final class LogBinaryDataMessage: LogMessage {
	public let data: Data

	public init(sequence: Int, timestamp: LogTimestamp, tags: [String], thread: String, level: Int, userInfo: [Int:Data]? = nil, filename: String? = nil, function: String? = nil, line: Int? = nil, data: Data) {
		self.data = data
		super.init(sequence: sequence, timestamp: timestamp, tags: tags, thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}

	public init(sequence: Int, timestamp: LogTimestamp, tag: String? = nil, thread: String, level: Int, userInfo: [Int:Data]? = nil, filename: String? = nil, function: String? = nil, line: Int? = nil, data: Data) {
		self.data = data
		super.init(sequence: sequence, timestamp: timestamp, tags: tag.flatMap { [$0] } ?? [], thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}
}

public final class LogImageMessage: LogMessage {
	public let imageData: Data
	public private(set) var imageWidth: Int?
	public private(set) var imageHeight: Int?

	public init(sequence: Int, timestamp: LogTimestamp, tags: [String], thread: String, level: Int, userInfo: [Int:Data]? = nil, filename: String? = nil, function: String? = nil, line: Int? = nil, imageData: Data, imageWidth: Int? = nil, imageHeight: Int? = nil) {
		self.imageData = imageData
		self.imageWidth = imageWidth
		self.imageHeight = imageHeight
		super.init(sequence: sequence, timestamp: timestamp, tags: tags, thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}

	public init(sequence: Int, timestamp: LogTimestamp, tag: String? = nil, thread: String, level: Int, userInfo: [Int:Data]? = nil, filename: String? = nil, function: String? = nil, line: Int? = nil, imageData: Data, imageWidth: Int? = nil, imageHeight: Int? = nil) {
		self.imageData = imageData
		self.imageWidth = imageWidth
		self.imageHeight = imageHeight
		super.init(sequence: sequence, timestamp: timestamp, tags: tag.flatMap { [$0] } ?? [], thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}
}
