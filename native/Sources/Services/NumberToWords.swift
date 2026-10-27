import Foundation

public struct NumberToWords {
    private static let units = [
        "", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
        "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen",
        "Seventeen", "Eighteen", "Nineteen"
    ]

    private static let tens = [
        "", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"
    ]

    private static func convertLessThanOneThousand(_ number: Int) -> String {
        var current = ""
        var num = number

        if num >= 100 {
            current += units[num / 100] + " Hundred "
            num %= 100
        }

        if num >= 20 {
            let tenPart = tens[num / 10]
            let unitPart = units[num % 10]
            if !unitPart.isEmpty {
                current += tenPart + "-" + unitPart + " "
            } else {
                current += tenPart + " "
            }
        } else if num > 0 {
            current += units[num] + " "
        }

        return current.trimmingCharacters(in: .whitespaces)
    }

    public static func toCheckWords(amount: Double) -> String {
        let absAmount = abs(amount)
        let dollars = Int(absAmount)
        let cents = Int(round((absAmount - Double(dollars)) * 100.0))

        if dollars == 0 {
            return "Zero and \(String(format: "%02d", cents))/100 Dollars"
        }

        var result = ""
        var num = dollars

        if num >= 1_000_000 {
            let millions = num / 1_000_000
            result += convertLessThanOneThousand(millions) + " Million "
            num %= 1_000_000
        }

        if num >= 1_000 {
            let thousands = num / 1_000
            result += convertLessThanOneThousand(thousands) + " Thousand "
            num %= 1_000
        }

        if num > 0 {
            result += convertLessThanOneThousand(num) + " "
        }

        result = result.trimmingCharacters(in: .whitespaces)
        return "\(result) and \(String(format: "%02d", cents))/100 Dollars"
    }
}
