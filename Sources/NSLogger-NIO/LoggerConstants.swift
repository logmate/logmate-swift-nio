//
// Created by Florent Pillet on 2018-10-22.
//

/* NSLogger native binary message format:
 * Each message is a dictionary encoded in a compact format. All values are stored
 * in network order (big endian). A message is made of several "parts", which are
 * typed chunks of data, each with a specific purpose (partKey), data type (partType)
 * and data size (partSize).
 *
 *	uint32_t	totalSize		(total size for the whole message excluding this 4-byte count)
 *	uint16_t	partCount		(number of parts below)
 *  [repeat partCount times]:
 *		uint8_t		partKey		the part key
 *		uint8_t		partType	(string, binary, image, int16, int32, int64)
 *		uint32_t	partSize	(only for string, binary and image types, others are implicit)
 *		.. `partSize' data bytes
 *
 * Complete message is usually made of:
 *	- a PART_KEY_MESSAGE_TYPE (mandatory) which contains one of the `MessageType` values
 *  - a PART_KEY_TIMESTAMP_S (mandatory) which is the timestamp returned by gettimeofday() (seconds from 01.01.1970 00:00)
 *	- a PART_KEY_TIMESTAMP_MS (optional) complement of the timestamp seconds, in milliseconds
 *	- a PART_KEY_TIMESTAMP_US (optional) complement of the timestamp seconds and milliseconds, in microseconds
 *	- a PART_KEY_THREAD_ID (mandatory) the ID of the user thread that produced the log entry
 *	- a PART_KEY_TAG (optional) a tag that helps categorizing and filtering logs from your application, and shows up in viewer logs
 *	- a PART_KEY_LEVEL (optional) a log level that helps filtering logs from your application (see as few or as much detail as you need)
 *	- a PART_KEY_MESSAGE which is the message text, binary data or image
 *  - a PART_KEY_MESSAGE_SEQ which is the message sequence number (message# sent by client)
 *	- a PART_KEY_FILENAME (optional) with the filename from which the log was generated
 *	- a PART_KEY_LINENUMBER (optional) the linenumber in the filename at which the log was generated
 *	- a PART_KEY_FUNCTIONNAME (optional) the function / method / selector from which the log was generated
 *  - if logging an image, PART_KEY_IMAGE_WIDTH and PART_KEY_IMAGE_HEIGHT let the desktop know the image size without having to actually decode it
 */

import Foundation

enum MessageType: Int {
	case log = 0
	case blockstart = 1
	case blockend = 2
	case clientInfo = 3
	case disconnect = 4
	case mark = 5
}

enum PartKey: Int {
	case messageType = 0
	case timestampSeconds = 1
	case timestampMilliseconds = 2
	case timestampMicroseconds = 3
	case threadID = 4
	case tag = 5
	case level = 6
	case logMessage = 7
	case imageWidth = 8
	case imageHeight = 9
	case sequenceNumber = 10
	case file = 11
	case line = 12
	case function = 13

	case clientName = 20
	case clientVersion = 21
	case osName = 22
	case osVersion = 23
	case clientModel = 24
	case clientUniqueID = 25

	static func from(_ value: UInt8) -> PartKey? {
		return self.init(rawValue: Int(value))
	}
}

enum PartType: Int {
	case utf8String = 0
	case binaryData = 1
	case int16 = 2
	case int32 = 3
	case int64 = 4
	case image = 5

	static func from(_ value: UInt8) -> PartType? {
		return self.init(rawValue: Int(value))
	}
}
