import Foundation

public final class OFXParser {
    public static func parseDate(_ str: String) -> (Date, String) {
        let digits = str.filter { $0.isNumber }
        if digits.count >= 8 {
            let y = Int(digits.prefix(4)) ?? 2000
            let m = Int(digits.dropFirst(4).prefix(2)) ?? 1
            let d = Int(digits.dropFirst(6).prefix(2)) ?? 1
            var comps = DateComponents()
            comps.year = y
            comps.month = m
            comps.day = d
            comps.hour = 12
            if let date = Calendar.current.date(from: comps) {
                let disp = String(format: "%04d-%02d-%02d", y, m, d)
                return (date, disp)
            }
        }
        return (Date(timeIntervalSince1970: 0), str)
    }

    private static func extractTag(_ tag: String, in str: String) -> String {
        if let r = str.range(of: "(?i)<\(tag)>([^<\\r\\n]+)", options: .regularExpression) {
            let matched = String(str[r])
            return matched.replacingOccurrences(of: "<\(tag)>", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private struct AcctBucket {
        var name: String
        var type: AccountType
        var txs: [Transaction]
        var seenFitids: Set<String>
    }

    private static func parseTransactions(
        in block: String,
        into bucket: inout AcctBucket,
        displayName: String,
        isCreditCard: Bool
    ) {
        let chunks = block.components(separatedBy: "<STMTTRN>")
        for (idx, c) in chunks.enumerated() {
            if idx == 0 { continue }
            let dt = extractTag("DTPOSTED", in: c)
            let amtStr = extractTag("TRNAMT", in: c)
            let rawName = extractTag("NAME", in: c)
                .replacingOccurrences(of: "&amp;", with: "&")
            let rawMemo = extractTag("MEMO", in: c)
                .replacingOccurrences(of: "&amp;", with: "&")
            let checkNum = extractTag("CHECKNUM", in: c)
            let fitid = extractTag("FITID", in: c)
            let cleanAmt = amtStr.replacingOccurrences(of: ",", with: "")
            let amt = Double(cleanAmt) ?? 0.0

            let dedupeKey = fitid.isEmpty ? "\(dt)_\(amt)_\(rawName)_\(checkNum)" : fitid
            if bucket.seenFitids.contains(dedupeKey) {
                continue
            }
            bucket.seenFitids.insert(dedupeKey)

            let (parsedDate, dateStr) = parseDate(dt)
            let tx = Transaction(
                accountName: displayName,
                date: parsedDate,
                dateString: dateStr,
                checkNumber: checkNum,
                payee: rawName.isEmpty ? "Electronic Transaction" : rawName,
                memo: rawMemo,
                category: isCreditCard ? "Credit Card" : "",
                amount: amt,
                clearedStatus: "R"
            )
            bucket.txs.append(tx)
        }
    }

    public static func parse(content: String, defaultName: String = "Online Account") -> [Account] {
        var buckets: [String: AcctBucket] = [:]

        // If the file contains <OFX> tags, split session by session; otherwise treat as one session
        let rawSessions = content.components(separatedBy: "<OFX>")
        let sessions: [String] = rawSessions.count > 1 ? Array(rawSessions.dropFirst()) : [content]

        for session in sessions {
            let sessionOrg = extractTag("ORG", in: session)
            let baseOrg = sessionOrg.isEmpty ? defaultName : sessionOrg

            // 1. Process Bank Statements: <STMTRS>
            let bankBlocks = session.components(separatedBy: "<STMTRS>")
            if bankBlocks.count > 1 {
                for block in bankBlocks.dropFirst() {
                    let headerPart = block.components(separatedBy: "<STMTTRN>").first ?? block
                    let acctId = extractTag("ACCTID", in: headerPart)
                    let acctTypeRaw = extractTag("ACCTTYPE", in: headerPart).uppercased()
                    let isSavings = (acctTypeRaw == "SAVINGS")
                    let suffix = acctId.count >= 4 ? String(acctId.suffix(4)) : (acctId.isEmpty ? "Account" : acctId)
                    let typeLabel = isSavings ? "Savings" : "Checking"
                    let displayName = "\(baseOrg) \(typeLabel) (\(suffix))"
                    let bucketKey = "\(baseOrg)_BANK_\(suffix)_\(typeLabel)"

                    if buckets[bucketKey] == nil {
                        buckets[bucketKey] = AcctBucket(name: displayName, type: .bank, txs: [], seenFitids: [])
                    }
                    parseTransactions(in: block, into: &buckets[bucketKey]!, displayName: displayName, isCreditCard: false)
                }
            }

            // 2. Process Credit Card Statements: <CCSTMTRS>
            let ccBlocks = session.components(separatedBy: "<CCSTMTRS>")
            if ccBlocks.count > 1 {
                for block in ccBlocks.dropFirst() {
                    let headerPart = block.components(separatedBy: "<STMTTRN>").first ?? block
                    let acctId = extractTag("ACCTID", in: headerPart)
                    let suffix = acctId.count >= 4 ? String(acctId.suffix(4)) : (acctId.isEmpty ? "Card" : acctId)
                    let displayName = "\(baseOrg) (\(suffix))"
                    let bucketKey = "\(baseOrg)_CC_\(suffix)"

                    if buckets[bucketKey] == nil {
                        buckets[bucketKey] = AcctBucket(name: displayName, type: .creditCard, txs: [], seenFitids: [])
                    }
                    parseTransactions(in: block, into: &buckets[bucketKey]!, displayName: displayName, isCreditCard: true)
                }
            }

            // 3. Fallback for flat or unnested OFX responses
            if bankBlocks.count <= 1 && ccBlocks.count <= 1 && session.contains("<STMTTRN>") {
                let isCC = session.contains("<CCACCTFROM>") || session.contains("<CCSTMTRQ>")
                let acctId = extractTag("ACCTID", in: session)
                let suffix = acctId.count >= 4 ? String(acctId.suffix(4)) : (acctId.isEmpty ? "Account" : acctId)
                let typeLabel = isCC ? "" : " Checking"
                let displayName = "\(baseOrg)\(typeLabel) (\(suffix))"
                let bucketKey = "\(baseOrg)_\(isCC ? "CC" : "BANK")_\(suffix)"

                if buckets[bucketKey] == nil {
                    buckets[bucketKey] = AcctBucket(name: displayName, type: isCC ? .creditCard : .bank, txs: [], seenFitids: [])
                }
                parseTransactions(in: session, into: &buckets[bucketKey]!, displayName: displayName, isCreditCard: isCC)
            }
        }

        return buckets.values.compactMap { b in
            guard !b.txs.isEmpty else { return nil }
            let sortedTxs = b.txs.sorted { $0.date < $1.date }
            var running = 0.0
            var finalTxs: [Transaction] = []
            for var t in sortedTxs {
                running += t.amount
                t.runningBalance = running
                finalTxs.append(t)
            }
            return Account(
                name: b.name,
                type: b.type,
                balance: running,
                transactions: finalTxs
            )
        }.sorted { $0.name < $1.name }
    }

    public static func parseFile(at path: String) throws -> [Account] {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .isoLatin1) ?? String(decoding: data, as: UTF8.self)
        let baseName = url.deletingPathExtension().lastPathComponent
        return parse(content: content, defaultName: baseName)
    }
}
