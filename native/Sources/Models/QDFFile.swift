import Foundation

public struct QDFPageInfo: Identifiable {
    public let id: Int
    public let pageIndex: Int
    public let offset: UInt64
    public let size: Int
    public let magic: String
    public let isEncrypted: Bool
    public let md5Digest: String
}

public struct QDFMetadata {
    public var filePath: String
    public var fileSize: Int
    public var magic: UInt32
    public var version: UInt32
    public var pageCount: Int
    public var pageSize: Int
    public var pages: [QDFPageInfo]
    public var isValid: Bool
}

public struct QSDMetadata {
    public var filePath: String
    public var fileSize: Int
    public var versionString: String
    public var extractedStrings: [String]
    public var recognizedAccounts: [String]
    public var categories: [String]
}
