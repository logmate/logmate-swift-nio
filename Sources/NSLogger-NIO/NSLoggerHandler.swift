//
// Created by Florent Pillet on 2019-01-30.
//

import Foundation
import NIO

public enum LoggerEvent {
	case connected(LogClientInfo)
	case disconnected
}

public class NSLoggerHandler: ByteToMessageDecoder {
	public typealias InboundIn = ByteBuffer
	public typealias InboundOut = LogEntry

	public init() { }

	// ByteToMessageDecoder
	public var cumulationBuffer: ByteBuffer?

	public func decode(ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
		guard let entry = try buffer.getNextLogEntry() else {
			return .needMoreData
		}

		switch entry.type {
			case .log, .blockstart, .blockend, .clientInfo, .mark:
				if let log = buffer.readLogEntry(entrySize: entry.entrySize, type: entry.type, sequence: entry.sequence) {
					ctx.fireChannelRead(self.wrapInboundOut(log))
					if let connected = log as? LogClientInfo {
						ctx.fireUserInboundEventTriggered(LoggerEvent.connected(connected))
					}
				}

			case .disconnect:
				ctx.fireUserInboundEventTriggered(LoggerEvent.disconnected)
		}

		return .continue
	}
}
