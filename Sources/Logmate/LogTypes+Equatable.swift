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

extension LogTimestamp: Equatable {
	public static func == (lhs: LogTimestamp, rhs: LogTimestamp) -> Bool {
		return lhs.tv_sec == rhs.tv_sec && lhs.tv_usec == rhs.tv_usec
	}
}

extension LogEntry: Equatable {
	public static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
		return lhs.sequence == rhs.sequence
	}
}

extension LogMessage {
	public static func == (lhs: LogMessage, rhs: LogMessage) -> Bool {
		return (lhs as LogEntry) == (rhs as LogEntry) &&
			lhs.timestamp == rhs.timestamp &&
			lhs.thread == rhs.thread &&
			lhs.level == rhs.level &&
			lhs.filename == rhs.filename &&
			lhs.function == rhs.function &&
			lhs.line == rhs.line &&
			lhs.userInfo == rhs.userInfo
	}
}

extension LogTextMessage {
	public static func == (lhs: LogTextMessage, rhs: LogTextMessage) -> Bool {
		return (lhs as LogMessage) == (rhs as LogMessage) &&
			lhs.message == rhs.message
	}
}

extension LogBinaryDataMessage {
	public static func == (lhs: LogBinaryDataMessage, rhs: LogBinaryDataMessage) -> Bool {
		return (lhs as LogMessage) == (rhs as LogMessage) &&
			lhs.data == rhs.data
	}
}

extension LogImageMessage {
	public static func == (lhs: LogImageMessage, rhs: LogImageMessage) -> Bool {
		return (lhs as LogMessage) == (rhs as LogMessage) &&
			lhs.imageData == rhs.imageData &&
			lhs.imageWidth == rhs.imageWidth &&
			lhs.imageHeight == rhs.imageHeight
	}
}

extension LogMarker {
	public static func == (lhs: LogMarker, rhs: LogMarker) -> Bool {
		return (lhs as LogEntry) == (rhs as LogEntry) &&
			lhs.mark == rhs.mark
	}
}

extension LogBlockDelimiter {
	public static func == (lhs: LogBlockDelimiter, rhs: LogBlockDelimiter) -> Bool {
		return (lhs as LogEntry) == (rhs as LogEntry) &&
			lhs.start == rhs.start
	}
}

extension LogClientInfo {
	public static func == (lhs: LogClientInfo, rhs: LogClientInfo) -> Bool {
		return (lhs as LogEntry) == (rhs as LogEntry) &&
			lhs.clientModel == rhs.clientModel &&
			lhs.clientUID == rhs.clientUID &&
			lhs.clientName == rhs.clientName &&
			lhs.clientVersion == rhs.clientVersion
	}
}
