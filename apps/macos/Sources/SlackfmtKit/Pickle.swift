import Foundation

/// Chromium pickle as the PRD's V3 lays it out: a u32 LE payload size counting every byte after
/// itself; a u32 LE entry count; then each entry's type and value strings, each a u32 LE count of
/// UTF-16 code units, the UTF-16LE bytes, and zero bytes to the next 4-byte boundary.
public enum Pickle {
    public typealias Entry = (type: String, value: String)

    public enum DecodeError: Error {
        case notAPickle
    }

    public static func encode(_ entries: [Entry]) -> Data {
        var payload = Data()
        payload.appendUInt32(UInt32(entries.count))
        for entry in entries {
            payload.appendString16(entry.type)
            payload.appendString16(entry.value)
        }
        var data = Data()
        data.appendUInt32(UInt32(payload.count))
        data.append(payload)
        return data
    }

    public static func decode(_ data: Data) throws -> [Entry] {
        let bytes = [UInt8](data)
        var position = 0

        func readUInt32() throws -> Int {
            guard position + 4 <= bytes.count else { throw DecodeError.notAPickle }
            defer { position += 4 }
            return (0..<4).reduce(0) { $0 | Int(bytes[position + $1]) << (8 * $1) }
        }

        func readString16() throws -> String {
            let length = try readUInt32() * 2
            let end = position + length
            let paddedEnd = end + (4 - length % 4) % 4
            guard paddedEnd <= bytes.count else { throw DecodeError.notAPickle }
            let units = stride(from: position, to: end, by: 2).map { UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8 }
            position = paddedEnd
            return String(decoding: units, as: UTF16.self)
        }

        guard try readUInt32() == bytes.count - 4 else { throw DecodeError.notAPickle }
        let count = try readUInt32()
        var entries: [Entry] = []
        for _ in 0..<count {
            entries.append((try readString16(), try readString16()))
        }
        guard position == bytes.count else { throw DecodeError.notAPickle }
        return entries
    }
}

private extension Data {
    mutating func appendUInt32(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendString16(_ string: String) {
        let units = Array(string.utf16)
        appendUInt32(UInt32(units.count))
        for unit in units {
            Swift.withUnsafeBytes(of: unit.littleEndian) { append(contentsOf: $0) }
        }
        append(contentsOf: [UInt8](repeating: 0, count: (4 - units.count * 2 % 4) % 4))
    }
}
