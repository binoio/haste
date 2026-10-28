import Foundation

public struct DiscoveredAccountSource: Identifiable {
    public var id: String { "\(era)_\(name)" }
    public let sourceType: String // "QIF Export" or "OFX Statement"
    public let name: String
    public let era: String // "1998–2000 (Win32 Era)", "2001–2002 (PC Era)", "2003–2007 (Mac Era)"
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

        var rawDiscovered: [DiscoveredAccountSource] = []

        // 1. Recursively look for QIF files
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
                        rawDiscovered.append(DiscoveredAccountSource(
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
                            rawDiscovered.append(DiscoveredAccountSource(
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

        // 3. Deduplicate discovered accounts on scan
        struct MergedAccountAccumulator {
            var name: String
            var era: String
            var baseSourceType: String
            var fileURLs: [URL]
            var accountType: AccountType
            var seenTxKeys: Set<String>
            var transactions: [Transaction]
        }

        var dedupMap: [String: MergedAccountAccumulator] = [:]

        for item in rawDiscovered {
            let key = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if dedupMap[key] == nil {
                dedupMap[key] = MergedAccountAccumulator(
                    name: item.name,
                    era: item.era,
                    baseSourceType: item.sourceType,
                    fileURLs: [item.fileURL],
                    accountType: item.account.type,
                    seenTxKeys: [],
                    transactions: []
                )
            } else {
                if !dedupMap[key]!.fileURLs.contains(item.fileURL) {
                    dedupMap[key]!.fileURLs.append(item.fileURL)
                }
            }

            for tx in item.account.transactions {
                let txKey = "\(tx.dateString)_\(String(format: "%.2f", tx.amount))_\(tx.payee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())_\(tx.checkNumber)"
                if !dedupMap[key]!.seenTxKeys.contains(txKey) {
                    dedupMap[key]!.seenTxKeys.insert(txKey)
                    dedupMap[key]!.transactions.append(tx)
                }
            }
        }

        // Convert merged entries back to DiscoveredAccountSource
        var deduplicated: [DiscoveredAccountSource] = []
        for (_, entry) in dedupMap {
            let sortedTxs = entry.transactions.sorted { $0.date < $1.date }
            var running = 0.0
            var finalTxs: [Transaction] = []
            for var t in sortedTxs {
                running += t.amount
                t.runningBalance = running
                finalTxs.append(t)
            }

            let unifiedAccount = Account(
                name: entry.name,
                type: entry.accountType,
                balance: running,
                transactions: finalTxs
            )

            let finalSourceType: String = {
                if entry.fileURLs.count > 1 {
                    return "\(entry.baseSourceType) (Merged \(entry.fileURLs.count) files)"
                }
                return entry.baseSourceType
            }()

            deduplicated.append(DiscoveredAccountSource(
                sourceType: finalSourceType,
                name: entry.name,
                era: entry.era,
                fileURL: entry.fileURLs.first ?? folderURL,
                account: unifiedAccount
            ))
        }

        // Extracted strings
        var accountNames = foundQSD?.recognizedAccounts ?? []
        let categories = foundQSD?.categories ?? []

        // If no QSD accounts found, populate from discovered accounts
        if accountNames.isEmpty {
            accountNames = deduplicated.map { $0.name }
        }

        return DatasetScanResult(
            datasetName: datasetBaseName,
            folderPath: folderURL.path,
            qdfMetadata: foundQDF,
            qsdMetadata: foundQSD,
            discoveredAccounts: deduplicated.sorted {
                if $0.era != $1.era { return $0.era < $1.era }
                return $0.name < $1.name
            },
            extractedAccountNames: accountNames,
            extractedCategories: categories
        )
    }
}
