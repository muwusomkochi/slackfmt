import Foundation

/// Chromium pickle as the PRD's V3 lays it out: a u32 LE payload size counting every byte after
/// itself; a u32 LE entry count; then each entry's type and value strings, each a u32 LE count of
/// UTF-16 code units, the UTF-16LE bytes, and zero bytes to the next 4-byte boundary.
public enum Pickle {
    public static func encode(_ entries: [(String, String)]) -> Data {
        var payload = Data()
        payload.appendU32(UInt32(entries.count))
        for (type, value) in entries {
            payload.appendString16(type)
            payload.appendString16(value)
        }
        var data = Data()
        data.appendU32(UInt32(payload.count))
        data.append(payload)
        return data
    }

    public enum DecodeError: Error, CustomStringConvertible {
        case tooShort(Int)
        case sizeMismatch(declared: UInt32, actual: Int)
        case truncated(at: Int)
        case trailingBytes(Int)

        public var description: String {
            switch self {
            case .tooShort(let n): return "too short (\(n) bytes)"
            case .sizeMismatch(let d, let a): return "payload size \(d) declared, \(a) bytes follow it"
            case .truncated(let at): return "truncated at byte \(at)"
            case .trailingBytes(let n): return "\(n) bytes left after the last entry"
            }
        }
    }

    public static func decode(_ data: Data) throws -> [(String, String)] {
        let bytes = [UInt8](data)
        guard bytes.count >= 8 else { throw DecodeError.tooShort(bytes.count) }
        var at = 0
        func u32() throws -> UInt32 {
            guard at + 4 <= bytes.count else { throw DecodeError.truncated(at: at) }
            defer { at += 4 }
            return UInt32(bytes[at]) | UInt32(bytes[at + 1]) << 8 | UInt32(bytes[at + 2]) << 16 | UInt32(bytes[at + 3]) << 24
        }
        func string16() throws -> String {
            let units = Int(try u32())
            let length = units * 2
            guard at + length <= bytes.count else { throw DecodeError.truncated(at: at) }
            var codeUnits = [UInt16]()
            codeUnits.reserveCapacity(units)
            for i in 0..<units {
                codeUnits.append(UInt16(bytes[at + 2 * i]) | UInt16(bytes[at + 2 * i + 1]) << 8)
            }
            at += length + (4 - length % 4) % 4
            guard at <= bytes.count else { throw DecodeError.truncated(at: at) }
            return String(decoding: codeUnits, as: UTF16.self)
        }
        let declared = try u32()
        guard Int(declared) == bytes.count - 4 else {
            throw DecodeError.sizeMismatch(declared: declared, actual: bytes.count - 4)
        }
        let count = try u32()
        var entries: [(String, String)] = []
        for _ in 0..<count {
            entries.append((try string16(), try string16()))
        }
        guard at == bytes.count else { throw DecodeError.trailingBytes(bytes.count - at) }
        return entries
    }
}

extension Data {
    mutating func appendU32(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendString16(_ string: String) {
        let units = Array(string.utf16)
        appendU32(UInt32(units.count))
        for unit in units {
            Swift.withUnsafeBytes(of: unit.littleEndian) { append(contentsOf: $0) }
        }
        append(contentsOf: [UInt8](repeating: 0, count: (4 - (units.count * 2) % 4) % 4))
    }
}
