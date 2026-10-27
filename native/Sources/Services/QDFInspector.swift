import Foundation

public final class QSDParser {
    public static func parseFile(at path: String) throws -> QSDMetadata {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)

        var versionString = ""
        if data.count >= 32 {
            let headerBytes = data.prefix(32)
            versionString = String(decoding: headerBytes, as: UTF8.self)
                .components(separatedBy: "\0").first ?? ""
        }

        var extracted: [String] = []
        var curBytes = [UInt8]()
        for byte in data {
            if byte >= 32 && byte <= 126 {
                curBytes.append(byte)
            } else {
                if curBytes.count >= 4 {
                    if let str = String(bytes: curBytes, encoding: .isoLatin1) {
                        extracted.append(str)
                    }
                }
                curBytes.removeAll(keepingCapacity: true)
            }
        }

        var recognizedAccounts: [String] = []
        var categories: [String] = []

        let knownAccountKeywords = ["Checking", "Savings", "Money", "Finances", "Visa", "MasterCard", "Discover", "Loan"]
        for s in extracted {
            if knownAccountKeywords.contains(where: { s.localizedCaseInsensitiveContains($0) }) {
                if !recognizedAccounts.contains(s) && s.count < 40 {
                    recognizedAccounts.append(s)
                }
            }
            if ["Income", "Discretionary", "Mandatory Expenses", "Bills", "Banking", "Investing"].contains(s) {
                if !categories.contains(s) {
                    categories.append(s)
                }
            }
        }

        return QSDMetadata(
            filePath: path,
            fileSize: data.count,
            versionString: versionString,
            extractedStrings: Array(extracted.prefix(150)),
            recognizedAccounts: recognizedAccounts,
            categories: categories
        )
    }
}

public final class QDFInspector {
    public static let pageSize: Int = 4088
    public static let qdfMagic: UInt32 = 0x8FBD9EAC // AC 9E BD 8F

    public static func inspectFile(at path: String) throws -> QDFMetadata {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)

        guard data.count >= 8 else {
            return QDFMetadata(
                filePath: path,
                fileSize: data.count,
                magic: 0,
                version: 0,
                pageCount: 0,
                pageSize: pageSize,
                pages: [],
                isValid: false
            )
        }

        let magic = data.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self) }
        let version = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
        let isValid = (magic == qdfMagic)

        let pageCount = data.count / pageSize
        var pages: [QDFPageInfo] = []

        for p in 0..<min(pageCount, 100) {
            let offset = UInt64(p * pageSize)
            let pageData = data.subdata(in: (p * pageSize)..<((p + 1) * pageSize))

            var md5Hex = ""
            var magicStr = "RC5"
            let isEncrypted = (p > 0) // Page 0 has clear 8-byte header

            if p == 0 {
                magicStr = String(format: "0x%08X", magic)
                let md5Part = pageData.subdata(in: 8..<24)
                md5Hex = md5Part.map { String(format: "%02x", $0) }.joined()
            } else {
                let md5Part = pageData.prefix(16)
                md5Hex = md5Part.map { String(format: "%02x", $0) }.joined()
            }

            pages.append(QDFPageInfo(
                id: p,
                pageIndex: p,
                offset: offset,
                size: pageSize,
                magic: magicStr,
                isEncrypted: isEncrypted,
                md5Digest: md5Hex
            ))
        }

        return QDFMetadata(
            filePath: path,
            fileSize: data.count,
            magic: magic,
            version: version,
            pageCount: pageCount,
            pageSize: pageSize,
            pages: pages,
            isValid: isValid
        )
    }
}
