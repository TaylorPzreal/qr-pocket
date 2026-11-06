import Foundation

public enum URIComponent {
    public static func encode(_ input: String) -> String {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()".utf8)
        let hex = Array("0123456789ABCDEF".utf8)
        var result = [UInt8]()
        result.reserveCapacity(input.utf8.count)
        for byte in input.utf8 {
            if allowed.contains(byte) {
                result.append(byte)
            } else {
                result.append(37)
                result.append(hex[Int(byte >> 4)])
                result.append(hex[Int(byte & 15)])
            }
        }
        return String(decoding: result, as: UTF8.self)
    }
}
