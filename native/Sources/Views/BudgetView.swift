import SwiftUI

public struct BudgetView: View {
    @ObservedObject var store: DataStore
    @State private var selectedTab: Int = 0

    // Calculator States
    @State private var loanPrincipal: String = "250000"
    @State private var loanRate: String = "6.5"
    @State private var loanYears: String = "30"

    @State private var savingsInitial: String = "10000"
    @State private var savingsMonthly: String = "500"
    @State private var savingsRate: String = "7.0"
    @State private var savingsYears: String = "20"

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Planning & Budgets Center")
                        .font(.title3.weight(.bold))
                    Text("Monthly category budget targets, cash flow forecasting, and financial calculators.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Picker("", selection: $selectedTab) {
                    Text("Monthly Budgets").tag(0)
                    Text("Financial Calculators").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
            Divider()

            if selectedTab == 0 {
                budgetTable
            } else {
                calculatorsView
            }
        }
    }

    // MARK: - Monthly Budget Table
    private var budgetTable: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary Cards
                let totalBudgetedExpenses = store.budgetCategories.filter { !$0.isIncome }.reduce(0.0) { $0 + $1.monthlyBudget }
                let totalActualExpenses = store.budgetCategories.filter { !$0.isIncome }.reduce(0.0) { $0 + store.actualSpending(for: $1.categoryName) }
                let totalBudgetedIncome = store.budgetCategories.filter { $0.isIncome }.reduce(0.0) { $0 + $1.monthlyBudget }
                let totalActualIncome = store.budgetCategories.filter { $0.isIncome }.reduce(0.0) { $0 + store.actualIncome(for: $1.categoryName) }

                HStack(spacing: 14) {
                    summaryKpi(title: "Budgeted Income", amount: totalBudgetedIncome, color: .green)
                    summaryKpi(title: "Actual Income", amount: totalActualIncome, color: .green)
                    summaryKpi(title: "Budgeted Expenses", amount: totalBudgetedExpenses, color: .red)
                    summaryKpi(title: "Actual Expenses", amount: totalActualExpenses, color: .red)
                }

                // Table
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Category").frame(width: 160, alignment: .leading)
                        Text("Type").frame(width: 80, alignment: .leading)
                        Text("Monthly Budget").frame(width: 120, alignment: .trailing)
                        Text("Actual").frame(width: 110, alignment: .trailing)
                        Text("Remaining / Diff").frame(width: 120, alignment: .trailing)
                        Text("Progress").frame(minWidth: 120, alignment: .leading)
                    }
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))

                    ForEach(store.budgetCategories) { item in
                        let actual = item.isIncome ? store.actualIncome(for: item.categoryName) : store.actualSpending(for: item.categoryName)
                        let diff = item.isIncome ? (actual - item.monthlyBudget) : (item.monthlyBudget - actual)
                        let ratio = item.monthlyBudget > 0 ? CGFloat(actual / item.monthlyBudget) : 0

                        VStack(spacing: 4) {
                            HStack {
                                Text(item.categoryName)
                                    .font(.subheadline.weight(.medium))
                                    .frame(width: 160, alignment: .leading)

                                Text(item.isIncome ? "Income" : "Expense")
                                    .font(.caption2)
                                    .foregroundColor(item.isIncome ? .green : .orange)
                                    .frame(width: 80, alignment: .leading)

                                Text(String(format: "$%.2f", item.monthlyBudget))
                                    .font(.caption.monospaced())
                                    .frame(width: 120, alignment: .trailing)

                                Text(String(format: "$%.2f", actual))
                                    .font(.caption.monospaced().bold())
                                    .frame(width: 110, alignment: .trailing)

                                Text(String(format: "%@$%.2f", diff >= 0 ? "+" : "-", abs(diff)))
                                    .font(.caption.monospaced().bold())
                                    .foregroundColor(diff >= 0 ? .green : .red)
                                    .frame(width: 120, alignment: .trailing)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.gray.opacity(0.2))
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(diff >= 0 ? Color.green : Color.red)
                                            .frame(width: min(geo.size.width, max(2, geo.size.width * min(1.0, ratio))))
                                    }
                                }
                                .frame(height: 6)
                                .frame(minWidth: 120)
                            }
                            Divider()
                        }
                    }
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding(16)
        }
    }

    // MARK: - Financial Calculators
    private var calculatorsView: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                // Loan Planner
                VStack(alignment: .leading, spacing: 12) {
                    Label("Haste Loan Planner", systemImage: "house.fill")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Loan Principal Amount ($):").font(.caption.bold())
                        TextField("250000", text: $loanPrincipal).textFieldStyle(.roundedBorder)

                        Text("Annual Interest Rate (%):").font(.caption.bold())
                        TextField("6.5", text: $loanRate).textFieldStyle(.roundedBorder)

                        Text("Loan Term (Years):").font(.caption.bold())
                        TextField("30", text: $loanYears).textFieldStyle(.roundedBorder)
                    }

                    let p = Double(loanPrincipal) ?? 0
                    let r = Double(loanRate) ?? 0
                    let y = Int(loanYears) ?? 0
                    let loanRes = FinancialCalculator.calculateLoan(principal: p, annualRatePercent: r, termYears: y)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Payment:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "$%.2f", loanRes.monthlyPayment))
                            .font(.title2.monospaced().bold())
                            .foregroundColor(.accentColor)

                        Divider().padding(.vertical, 4)

                        Text(String(format: "Total Interest: $%.2f", loanRes.totalInterest))
                            .font(.caption.monospaced())
                        Text(String(format: "Total Cost: $%.2f", loanRes.totalPayment))
                            .font(.caption.monospaced())
                    }
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(6)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Savings Planner
                VStack(alignment: .leading, spacing: 12) {
                    Label("Haste Investment / Savings Planner", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Initial Deposit ($):").font(.caption.bold())
                        TextField("10000", text: $savingsInitial).textFieldStyle(.roundedBorder)

                        Text("Monthly Contribution ($):").font(.caption.bold())
                        TextField("500", text: $savingsMonthly).textFieldStyle(.roundedBorder)

                        Text("Annual Return Rate (%):").font(.caption.bold())
                        TextField("7.0", text: $savingsRate).textFieldStyle(.roundedBorder)

                        Text("Time Horizon (Years):").font(.caption.bold())
                        TextField("20", text: $savingsYears).textFieldStyle(.roundedBorder)
                    }

                    let initDep = Double(savingsInitial) ?? 0
                    let monthly = Double(savingsMonthly) ?? 0
                    let rate = Double(savingsRate) ?? 0
                    let yrs = Int(savingsYears) ?? 0
                    let saveRes = FinancialCalculator.calculateSavings(initialDeposit: initDep, monthlyContribution: monthly, annualRatePercent: rate, years: yrs)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Projected Portfolio Value:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "$%.2f", saveRes.futureValue))
                            .font(.title2.monospaced().bold())
                            .foregroundColor(.green)

                        Divider().padding(.vertical, 4)

                        Text(String(format: "Total Contributions: $%.2f", saveRes.totalContributions))
                            .font(.caption.monospaced())
                        Text(String(format: "Compound Interest Earned: $%.2f", saveRes.totalInterestEarned))
                            .font(.caption.monospaced())
                    }
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(6)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding(16)
        }
    }

    private func summaryKpi(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            Text(String(format: "$%.2f", amount)).font(.subheadline.monospaced().bold()).foregroundColor(color)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
