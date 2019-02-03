
import Foundation
import NIO
import NSLogger_NIO

fileprivate let nibbles = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"]

public final class PrintLogHandler: ChannelInboundHandler {
	public typealias InboundIn = LogEntry

	let dateFormatter: DateFormatter

	init() {
		dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .none
		dateFormatter.timeStyle = .short
	}

	private func formattedTimestamp(_ message: LogMessage) -> String {
		let ms = message.timestamp.tv_usec / 1000
		return dateFormatter.string(from: message.date) + ".\(ms)"
	}

	private func formatBinaryData(_ data: Data) -> [String] {
		return data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> [String] in
			stride(from: 0, through: data.count, by: 16).map { offset -> String in
				var hex = "", ascii = ""
				for i in 0 ..< min(16, data.count - offset) {
					let c = pointer.advanced(by: offset + i).pointee
					hex += "\(nibbles[Int(c >> 4)])\(nibbles[Int(c & 15)]) "
					ascii += c >= 32 ? Unicode.Scalar(c).escaped(asASCII: true) : "."
				}
				if hex.count < 48 {
					hex += String(repeating: " ", count: 48 - hex.count)
				}
				return "\(hex)\(ascii)"
			}
		}
	}

	public func userInboundEventTriggered(ctx: ChannelHandlerContext, event: Any) {
		guard let evt = event as? LoggerEvent else {
			return
		}
		switch evt {
			case .connected:
				print()
				print()
				print("************ CLIENT CONNECTED ************")
			case .disconnected:
				print("************ CLIENT DISCONNECTED ************")
		}
	}

	public func channelActive(ctx: ChannelHandlerContext) {
		print("channel active")
	}

	public func channelInactive(ctx: ChannelHandlerContext) {
		print("channel inactive")
	}

	public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
		let log = self.unwrapInboundIn(data)
		let header: String

		if let timestampedMessage = log as? LogMessage {
			let timestamp = formattedTimestamp(timestampedMessage)
			header = "[\(log.sequence)] \(timestamp)"
		} else {
			header = "[\(log.sequence)] "
		}

		if let message = log as? LogTextMessage {
			print("\(header) | \(message.thread) | \(message.message)")
		}

		else if let message = log as? LogBinaryDataMessage {
			let numBytes = message.data.count
			let left = "\(header) | \(message.thread) |"
			print("\(left) Binary data, \(numBytes) bytes:")
			let prefix = String(repeating: " ", count: left.count + 1)
			formatBinaryData(message.data).forEach { print(prefix + $0) }
		}

		else if let message = log as? LogImageMessage {
			if let width = message.imageWidth, let height = message.imageHeight {
				print("\(header) | \(message.thread) | Image (\(width) x \(height)), \(message.imageData.count) bytes")
			} else {
				print("\(header) | \(message.thread) | Image, \(message.imageData.count) bytes.")
			}
		}

		else if let message = log as? LogMarker {
			print("\(header) **** MARK **** \(message.mark)")
		}

		else if let message = log as? LogClientInfo {
			let prefix = String(repeating: " ", count: header.count)
			print("\(header) **** CLIENT INFO ***")
			print("\(prefix) \(message.clientName) \(message.clientModel) \(message.clientVersion) ")
			print("\(prefix) \(message.osName) \(message.osVersion)")
			print("\(prefix) ********************")
		}
	}

}

let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
let bootstrap = ServerBootstrap(group: group)
	.serverChannelOption(ChannelOptions.backlog, value: 256)
	.serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
	.childChannelInitializer { channel in
		channel.pipeline.addHandlers([
			NSLoggerHandler(),
			PrintLogHandler()], first: true)
	}
	.childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
	.childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
//	.childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
	.childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

do {
	let logServer = try bootstrap.bind(host: "::1", port: 50007).wait()
	print("Log server running - listening on port \(logServer.localAddress!)")
	try logServer.closeFuture.wait()	// run forever
}
catch let err {
	print("Failed bootstrapping server: err=\(err)")
}
