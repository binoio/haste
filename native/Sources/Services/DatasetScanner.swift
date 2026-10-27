import Foundation

public struct DiscoveredAccountSource: Identifiable {
    public var id: String { "\(sourceType)_\(fileURL.path)_\(name)" }
    public let sourceType: String // "QIF Export" or "OFX Statement"
    public let name: String
    public let era: String // "1998–2000 (Win32)", "2001–2002 (PC)", "2003–2007 (Mac OFX)"
    public let fileURL: URL
    public let account: Account
}

public struct DatasetScanResult {
    public let datasetName: String
    public let folderPath: String
    public let qdfMetadata: QDFMetadata?
    public let qsdMetadata: QSDMetadata?
    public let discoveredAccounts: [DiscoveredAccountSource]
    public let extractedAccountNames: [String]
    public let extractedCategories: [String]

    public var hasAccounts: Bool {
        !discoveredAccounts.isEmpty
    }

    public var totalTransactions: Int {
        discoveredAccounts.reduce(0) { $0 + $1.account.transactions.count }
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
                discoveredAccounts: [],
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

        var discovered: [DiscoveredAccountSource] = []

        // 1. Recursively look for QIF files up to 4 levels deep
        if let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "qif" {
                    if let acct = try? QIFParser.parseFile(at: fileURL.path) {
                        let name = acct.name.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : acct.name
                        let latestYear: Int = {
                            guard let latest = acct.transactions.last?.date else { return 1999 }
                            return Calendar.current.component(.year, from: latest)
                        }()
                        let era: String = (latestYear >= 2001) ? "2001–2002 (PC Era)" : "1998–2000 (Win32 Era)"
                        discovered.append(DiscoveredAccountSource(
                            sourceType: "QIF Export",
                            name: name,
                            era: era,
                            fileURL: fileURL,
                            account: acct
                        ))
                    }
                }
            }
        }

        // 2. Recursively look for OFX / QFX files and Quicken Mac OFX logs
        if let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                let fileName = fileURL.lastPathComponent.lowercased()
                let isOfxCandidate = (ext == "ofx" || ext == "qfx" || (ext == "txt" && (fileName.contains("ofxlog") || fileName.contains("ofxold"))))
                if isOfxCandidate {
                    if let ofxAccts = try? OFXParser.parseFile(at: fileURL.path), !ofxAccts.isEmpty {
                        for a in ofxAccts {
                            discovered.append(DiscoveredAccountSource(
                                sourceType: "OFX Statement",
                                name: a.name,
                                era: "2003–2007 (Mac Era)",
                                fileURL: fileURL,
                                account: a
                            ))
                        }
                    }
                }
            }
        }

        // Extracted strings
        var accountNames = foundQSD?.recognizedAccounts ?? []
        let categories = foundQSD?.categories ?? []

        // If no QSD accounts found, populate from discovered accounts
        if accountNames.isEmpty {
            accountNames = discovered.map { $0.name }
        }

        return DatasetScanResult(
            datasetName: datasetBaseName,
            folderPath: folderURL.path,
            qdfMetadata: foundQDF,
            qsdMetadata: foundQSD,
            discoveredAccounts: discovered.sorted {
                if $0.era != $1.era { return $0.era < $1.era }
                return $0.name < $1.name
            },
            extractedAccountNames: accountNames,
            extractedCategories: categories
        )
    }
}
