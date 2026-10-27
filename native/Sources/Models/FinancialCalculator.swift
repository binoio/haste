import Foundation

public struct LoanCalculationResult {
    public let monthlyPayment: Double
    public let totalPayment: Double
    public let totalInterest: Double
}

public struct SavingsCalculationResult {
    public let futureValue: Double
    public let totalContributions: Double
    public let totalInterestEarned: Double
}

public struct FinancialCalculator {
    public static func calculateLoan(principal: Double, annualRatePercent: Double, termYears: Int) -> LoanCalculationResult {
        guard principal > 0, termYears > 0 else {
            return LoanCalculationResult(monthlyPayment: 0, totalPayment: 0, totalInterest: 0)
        }

        let monthlyRate = (annualRatePercent / 100.0) / 12.0
        let totalMonths = termYears * 12

        if monthlyRate <= 0 {
            let pmt = principal / Double(totalMonths)
            return LoanCalculationResult(monthlyPayment: pmt, totalPayment: principal, totalInterest: 0)
        }

        let factor = pow(1.0 + monthlyRate, Double(totalMonths))
        let monthlyPayment = principal * (monthlyRate * factor) / (factor - 1.0)
        let totalPayment = monthlyPayment * Double(totalMonths)
        let totalInterest = totalPayment - principal

        return LoanCalculationResult(
            monthlyPayment: monthlyPayment,
            totalPayment: totalPayment,
            totalInterest: totalInterest
        )
    }

    public static func calculateSavings(initialDeposit: Double, monthlyContribution: Double, annualRatePercent: Double, years: Int) -> SavingsCalculationResult {
        let monthlyRate = (annualRatePercent / 100.0) / 12.0
        let totalMonths = years * 12

        var current = initialDeposit
        var totalContributions = initialDeposit

        for _ in 0..<totalMonths {
            if monthlyRate > 0 {
                current += current * monthlyRate
            }
            current += monthlyContribution
            totalContributions += monthlyContribution
        }

        let interestEarned = max(0, current - totalContributions)
        return SavingsCalculationResult(
            futureValue: current,
            totalContributions: totalContributions,
            totalInterestEarned: interestEarned
        )
    }
}
