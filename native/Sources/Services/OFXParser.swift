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

    public static func parse(content: String, defaultName: String = "Online Account") -> [Account] {
        var activeAcct = "Account"
        var activeOrg = ""
        var activeType: AccountType = .bank

        func extractTag(_ tag: String, in str: String) -> String {
            if let r = str.range(of: "<\(tag)>([^<\\r\\n]+)", options: .regularExpression) {
                let matched = String(str[r])
                return matched.replacingOccurrences(of: "<\(tag)>", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }

        struct AcctBucket {
            var name: String
            var type: AccountType
            var txs: [Transaction]
            var seenFitids: Set<String>
        }

        var buckets: [String: AcctBucket] = [:]

        let chunks = content.components(separatedBy: "<STMTTRN>")
        for (idx, c) in chunks.enumerated() {
            let org = extractTag("ORG", in: c)
            if !org.isEmpty { activeOrg = org }

            let acct = extractTag("ACCTID", in: c)
            if !acct.isEmpty { activeAcct = acct }

            if c.contains("<CCACCTFROM>") || c.contains("<CCSTMTRS>") {
                activeType = .creditCard
            } else if c.contains("<BANKACCTFROM>") || c.contains("<STMTRS>") {
                activeType = .bank
            }

            if idx == 0 {
                continue
            }

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

            let suffix = activeAcct.count >= 4 ? String(activeAcct.suffix(4)) : activeAcct
            let baseOrg = activeOrg.isEmpty ? defaultName : activeOrg
            let bucketKey: String = "\(baseOrg)_\(suffix)"

            let displayName: String = {
                if activeType == .creditCard {
                    return "\(baseOrg) (\(suffix))"
                } else {
                    return "\(baseOrg) Checking (\(suffix))"
                }
            }()

            if buckets[bucketKey] == nil {
                buckets[bucketKey] = AcctBucket(name: displayName, type: activeType, txs: [], seenFitids: [])
            }

            let dedupeKey = fitid.isEmpty ? "\(dt)_\(amt)_\(rawName)" : fitid
            if buckets[bucketKey]!.seenFitids.contains(dedupeKey) {
                continue
            }
            buckets[bucketKey]!.seenFitids.insert(dedupeKey)

            let (parsedDate, dateStr) = parseDate(dt)
            let tx = Transaction(
                accountName: displayName,
                date: parsedDate,
                dateString: dateStr,
                checkNumber: checkNum,
                payee: rawName.isEmpty ? "Electronic Transaction" : rawName,
                memo: rawMemo,
                category: activeType == .creditCard ? "Credit Card" : "",
                amount: amt,
                clearedStatus: "R"
            )
            buckets[bucketKey]!.txs.append(tx)
        }

        return buckets.values.map { b in
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
