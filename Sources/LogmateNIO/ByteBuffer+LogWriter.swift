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
import NIO
import Logmate

extension ByteBuffer: _LogWriter {
	public mutating func write(string: String) -> Int? {
		writeString(string)
	}
	
	public mutating func write(data: Data) {
		writeBytes(data)
	}
	
	public var nextWritePosition: Int {
		writerIndex
	}
	
	public mutating func write<T>(integer: T) where T : FixedWidthInteger {
		writeInteger(integer)
	}
	
	public mutating func update<T>(integer: T, at: Int) where T : FixedWidthInteger {
		setInteger(integer, at: at)
	}
}

extension ByteBuffer: LogWriter { }
