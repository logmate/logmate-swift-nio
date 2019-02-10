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

public enum LoggerEvent {
	case connected(LogClientInfo)
	case disconnected
}

// Handles native (binary protocol) encoding and decoding of log messages

public class LogmateNativeHandler: ByteToMessageDecoder, MessageToByteEncoder {
	
	public typealias OutboundIn = LogEntry
	
	public typealias InboundIn = ByteBuffer
	public typealias InboundOut = LogEntry

	public init() { }

	// ByteToMessageDecoder
	public var cumulationBuffer: ByteBuffer?

	public func decode(ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
		guard let log = try buffer.consumeLogEntry() else {
			return .needMoreData
		}
		
		ctx.fireChannelRead(self.wrapInboundOut(log))
		
		switch log {
		case let connected as LogClientInfo:
			ctx.fireUserInboundEventTriggered(LoggerEvent.connected(connected))
		case is LogDisconnectMessage:
			ctx.fireUserInboundEventTriggered(LoggerEvent.disconnected)
		default:
			break
		}
		
		return .continue
	}
	
	// MessageToByteEncoder
	public func encode(ctx: ChannelHandlerContext, data: LogEntry, out: inout ByteBuffer) throws {
		try out.write(data)
	}
}
