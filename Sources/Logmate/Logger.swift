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

public protocol LoggerBackend {
	/// If this backend is unable to save logs at the moment, it may revert to a fallback backend
	/// for exemple, the network backend can use a file backend for temporary storage

	/// All backends MUST be able to enqueue logs
	func enqueue(log: LogEntry)

	/// If the backend can dequeue logs, this gives the number of entries that have been stored
	var dequeueCapacity: Int { get }

	/// Some backends (like the file storage backend) can dequeue logs from the file for consumption
	func dequeue(max: Int) -> [LogEntry]?
}

public class LoggerFileBackend: LoggerBackend {
	private let url: URL

	init(file: URL, appending: Bool) {
		url = file
	}

	private func setup() {

	}
}

public class LoggerNetworkBackend: LoggerBackend {

}


public class Logger {
	/// An extensible Options struct which provides basic options supported by the default backends
	public struct Options: OptionSet {
		public typealias RawValue = Int

		public let rawValue: RawValue

		public init(rawValue: RawValue) {
	        self.rawValue = rawValue
	    }

		//public static let logToConsole = Options(rawValue: 0x01) // superseded by backends

		//public static let bufferLogsUntilConnection = Options(rawValue: 0x02) // superseded by backends and fallback backends

//		public static let browseBonjour = Options(rawValue: 0x04)			// options of network backend
//		public static let browseOnlyLocalDomain = Options(rawValue: 0x08)
//		public static let browsePeerToPeer = Options(rawValue: 0x40)
//		public static let useSsl = Options(rawValue: 0x10)

		public static let captureSystemConsole = Options(rawValue: 0x20)
	}

	/// a queue we use to serialize writing the logs
	let queue: DispatchQueue

	/// the encoder we use
	let encoder: LogWriter

	/// the options we use to log
	var options: Options {
		didSet {
			queue.async {
				self.optionsChanged(from: oldValue, to: options)
			}
		}
	}

	init() {
		queue = DispatchQueue(label: "logmate-queue")
	}

	private func optionsChanged(from: Options, to: Options) {

}
	public func log(_ entry: LogEntry) {
		queue.async {
			var encoded = LogEncodingData(data: Data(capacity: 256))
			try? encoded.write(entry)
		}
	}
}
