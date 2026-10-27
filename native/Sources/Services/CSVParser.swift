import Foundation

public struct ParsedCSVRow {
    public var date: Date
    public var dateString: String
    public var checkNumber: String
    public var payee: String
    public var category: String
    public var memo: String
    public var amount: Double
}

public final class CSVParser {
    public static func parse(content: String, defaultAccountName: String = "Imported") -> [Transaction] {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return [] }

        // Find header index and column indices
        var dateCol = 0
        var payeeCol = 1
        var amountCol = -1
        var debitCol = -1
        var creditCol = -1
        var catCol = -1
        var memoCol = -1
        var numCol = -1

        let headerFields = parseCSVLine(lines[0]).map { $0.lowercased() }
        var startIndex = 0

        let hasHeader = headerFields.contains(where: {
            $0.contains("date") || $0.contains("payee") || $0.contains("amount") || $0.contains("description")
        })

        if hasHeader {
            startIndex = 1
            for (idx, field) in headerFields.enumerated() {
                if field.contains("date") { dateCol = idx }
                else if field.contains("payee") || field.contains("description") || field.contains("name") { payeeCol = idx }
                else if field.contains("debit") || field.contains("payment") || field.contains("outflow") { debitCol = idx }
                else if field.contains("credit") || field.contains("deposit") || field.contains("inflow") { creditCol = idx }
                else if field.contains("amount") || field.contains("total") { amountCol = idx }
                else if field.contains("category") { catCol = idx }
                else if field.contains("memo") || field.contains("notes") { memoCol = idx }
                else if field.contains("num") || field.contains("check") { numCol = idx }
            }
        }

        var results: [Transaction] = []

        for i in startIndex..<lines.count {
            let row = parseCSVLine(lines[i])
            guard !row.isEmpty else { continue }

            let rawDate = dateCol < row.count ? row[dateCol] : ""
            let (parsedDate, dateStr) = QIFParser.parseDate(rawDate)

            let payee = payeeCol < row.count ? row[payeeCol] : "Imported Item"
            let category = (catCol >= 0 && catCol < row.count) ? row[catCol] : ""
            let memo = (memoCol >= 0 && memoCol < row.count) ? row[memoCol] : ""
            let checkNum = (numCol >= 0 && numCol < row.count) ? row[numCol] : ""

            var amount: Double = 0.0
            if amountCol >= 0 && amountCol < row.count {
                let clean = row[amountCol].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                amount = Double(clean) ?? 0.0
            } else if debitCol >= 0 || creditCol >= 0 {
                var debit = 0.0
                var credit = 0.0
                if debitCol >= 0 && debitCol < row.count {
                    let clean = row[debitCol].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                    debit = Double(clean) ?? 0.0
                }
                if creditCol >= 0 && creditCol < row.count {
                    let clean = row[creditCol].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                    credit = Double(clean) ?? 0.0
                }
                amount = credit > 0 ? credit : -abs(debit)
            }

            if parsedDate.timeIntervalSince1970 > 0 || !payee.isEmpty {
                let tx = Transaction(
                    accountName: defaultAccountName,
                    date: parsedDate.timeIntervalSince1970 > 0 ? parsedDate : Date(),
                    dateString: dateStr.isEmpty ? Transaction.formatDate(Date()) : dateStr,
                    checkNumber: checkNum,
                    payee: payee,
                    memo: memo,
                    category: category,
                    amount: amount
                )
                results.append(tx)
            }
        }

        return results
    }

    public static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var insideQuotes = false
        let chars = Array(line)
        var i = 0

        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if insideQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    current.append("\"")
                    i += 1
                } else {
                    insideQuotes.toggle()
                }
            } else if c == "," && !insideQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(c)
            }
            i += 1
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }
}
