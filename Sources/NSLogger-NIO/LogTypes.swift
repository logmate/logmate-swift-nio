import Foundation
import NIO

public typealias LogTimestamp = timeval

public class LogEntry {
	public let sequence: Int

	public init(sequence: Int) {
		self.sequence = sequence
	}
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
	public let userInfo: [Int:Any]?
	public let filename: String?
	public let function: String?
	public let line: Int?

	public init(sequence: Int, timestamp: LogTimestamp, tags: [String], thread: String, level: Int, userInfo: [Int:Any]?, filename: String?, function: String?, line: Int?) {
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

	public init(sequence: Int, timestamp: LogTimestamp, tags: [String], thread: String, level: Int, userInfo: [Int:Any]?, filename: String?, function: String?, line: Int?, message: String) {
		self.message = message
		super.init(sequence: sequence, timestamp: timestamp, tags: tags, thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}

	public init(sequence: Int, timestamp: LogTimestamp, tag: String?, thread: String, level: Int, userInfo: [Int:Any]?, filename: String?, function: String?, line: Int?, message: String) {
		self.message = message
		super.init(sequence: sequence, timestamp: timestamp, tags: tag.flatMap { [$0] } ?? [], thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}
}

public final class LogBinaryDataMessage: LogMessage {
	public let data: Data

	public init(sequence: Int, timestamp: LogTimestamp, tags: [String], thread: String, level: Int, userInfo: [Int:Any]?, filename: String?, function: String?, line: Int?, data: Data) {
		self.data = data
		super.init(sequence: sequence, timestamp: timestamp, tags: tags, thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}

	public init(sequence: Int, timestamp: LogTimestamp, tag: String?, thread: String, level: Int, userInfo: [Int:Any]?, filename: String?, function: String?, line: Int?, data: Data) {
		self.data = data
		super.init(sequence: sequence, timestamp: timestamp, tags: tag.flatMap { [$0] } ?? [], thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}
}

public final class LogImageMessage: LogMessage {
	public let imageData: Data
	public private(set) var imageWidth: Int?
	public private(set) var imageHeight: Int?

	public init(sequence: Int, timestamp: LogTimestamp, tags: [String], thread: String, level: Int, userInfo: [Int:Any]?, filename: String?, function: String?, line: Int?, imageData: Data, imageWidth: Int?, imageHeight: Int?) {
		self.imageData = imageData
		self.imageWidth = imageWidth
		self.imageHeight = imageHeight
		super.init(sequence: sequence, timestamp: timestamp, tags: tags, thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}

	public init(sequence: Int, timestamp: LogTimestamp, tag: String?, thread: String, level: Int, userInfo: [Int:Any]?, filename: String?, function: String?, line: Int?, imageData: Data, imageWidth: Int?, imageHeight: Int?) {
		self.imageData = imageData
		self.imageWidth = imageWidth
		self.imageHeight = imageHeight
		super.init(sequence: sequence, timestamp: timestamp, tags: tag.flatMap { [$0] } ?? [], thread: thread, level: level, userInfo: userInfo, filename: filename, function: function, line: line)
	}
}
