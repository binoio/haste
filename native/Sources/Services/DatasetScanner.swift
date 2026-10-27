import Foundation

public struct DiscoveredAccountQIF: Identifiable {
    public var id: String { fileURL.path }
    public let name: String
    public let fileURL: URL
    public let account: Account
}

public struct DatasetScanResult {
    public let datasetName: String
    public let folderPath: String
    public let qdfMetadata: QDFMetadata?
    public let qsdMetadata: QSDMetadata?
    public let discoveredQifs: [DiscoveredAccountQIF]
    public let extractedAccountNames: [String]
    public let extractedCategories: [String]

    public var hasQIFs: Bool {
        !discoveredQifs.isEmpty
    }

    public var totalTransactions: Int {
        discoveredQifs.reduce(0) { $0 + $1.account.transactions.count }
    }
}

public final class DatasetScanner {
    public static func scan(path: String) -> DatasetScanResult {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            return DatasetScanResult(
                datasetName: "Unknown",
                folderPath: path,
                qdfMetadata: nil,
                qsdMetadata: nil,
                discoveredQifs: [],
                extractedAccountNames: [],
                extractedCategories: []
            )
        }

        let folderURL: URL
        let datasetBaseName: String

        if isDir.boolValue {
            folderURL = URL(fileURLWithPath: path)
            datasetBaseName = folderURL.lastPathComponent
        } else {
            let fileURL = URL(fileURLWithPath: path)
            folderURL = fileURL.deletingLastPathComponent()
            datasetBaseName = fileURL.deletingPathExtension().lastPathComponent
        }

        var foundQDF: QDFMetadata? = nil
        var foundQSD: QSDMetadata? = nil

        // Scan folder for companion QDF & QSD
        if let contents = try? fm.contentsOfDirectory(atPath: folderURL.path) {
            for item in contents {
                let fullPath = folderURL.appendingPathComponent(item).path
                let ext = (item as NSString).pathExtension.lowercased()
                if ext == "qdf" && foundQDF == nil {
                    foundQDF = try? QDFInspector.inspectFile(at: fullPath)
                } else if ext == "qsd" && foundQSD == nil {
                    foundQSD = try? QSDParser.parseFile(at: fullPath)
                }
            }
        }

        // Recursively look for QIF files up to 3 levels deep
        var qifAccounts: [DiscoveredAccountQIF] = []
        if let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "qif" {
                    if let acct = try? QIFParser.parseFile(at: fileURL.path) {
                        let name = acct.name.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : acct.name
                        qifAccounts.append(DiscoveredAccountQIF(name: name, fileURL: fileURL, account: acct))
                    }
                }
            }
        }

        // Extracted strings
        var accountNames = foundQSD?.recognizedAccounts ?? []
        let categories = foundQSD?.categories ?? []

        // If no QSD accounts found, populate from discovered QIFs
        if accountNames.isEmpty {
            accountNames = qifAccounts.map { $0.name }
        }

        return DatasetScanResult(
            datasetName: datasetBaseName,
            folderPath: folderURL.path,
            qdfMetadata: foundQDF,
            qsdMetadata: foundQSD,
            discoveredQifs: qifAccounts.sorted { $0.name < $1.name },
            extractedAccountNames: accountNames,
            extractedCategories: categories
        )
    }
}
