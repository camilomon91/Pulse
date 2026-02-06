import Foundation
import Supabase

struct EventsService: EventsServing {}

// MARK: - Helper to build AnyJSON from Foundation types.
// This Supabase AnyJSON enum in this SDK version does not expose numeric cases.
extension AnyJSON {
    static func fromAny(_ value: Any) -> AnyJSON {
        switch value {
        case let s as String:
            return .string(s)

        case let n as Int:
            return .string(String(n))
        case let n as Int64:
            return .string(String(n))
        case let n as Double:
            return .string(String(n))
        case let n as Float:
            return .string(String(n))

        case let b as Bool:
            return .bool(b)

        case let dict as [String: Any]:
            return .object(dict.mapValues { AnyJSON.fromAny($0) })

        case let arr as [Any]:
            return .array(arr.map { AnyJSON.fromAny($0) })

        case _ as NSNull:
            return .null

        default:
            return .string(String(describing: value))
        }
    }
}
