import SwiftUI

public struct BillsRemindersView: View {
    @ObservedObject var store: DataStore
    @State private var showingAddSheet: Bool = false

    // New bill state
    @State private var payee: String = ""
    @State private var amountString: String = ""
    @State private var frequency: BillFrequency = .monthly
    @State private var dueDate: Date = Date()
    @State private var accountName: String = "Checking"
    @State private var category: String = "Utilities"
    @State private var memo: String = ""

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scheduled Bills & Financial Reminders")
                        .font(.title3.weight(.bold))
                    Text("Track upcoming bills, scheduled payments, and recurring deposits.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button(action: { showingAddSheet = true }) {
                    Label("Add Scheduled Bill", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.0, green: 0.35, blue: 0.20))
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
            Divider()

            if store.scheduledBills.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No scheduled bills or reminders.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button("Create First Reminder") {
                        showingAddSheet = true
                    }
                    Spacer()
                }
            } else {
                List {
                    ForEach(store.scheduledBills) { bill in
                        HStack(spacing: 12) {
                            Image(systemName: bill.isPaid ? "checkmark.circle.fill" : (bill.isOverdue ? "exclamationmark.triangle.fill" : "calendar"))
                                .font(.title3)
                                .foregroundColor(bill.isPaid ? .green : (bill.isOverdue ? .red : .orange))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(bill.payee)
                                    .font(.subheadline.bold())
                                HStack(spacing: 6) {
                                    Text("Due: \(bill.formattedDueDate)")
                                    Text("• \(bill.frequency.rawValue)")
                                    Text("• \(bill.accountName)")
                                    if !bill.category.isEmpty {
                                        Text("• \(bill.category)")
                                    }
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(String(format: "$%.2f", bill.amount))
                                .font(.system(.subheadline, design: .monospaced, weight: .bold))

                            Button(action: {
                                store.recordBillInRegister(bill: bill)
                            }) {
                                Text(bill.isPaid ? "Paid (Record Again)" : "Record in Register")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)

                            Button(action: {
                                store.scheduledBills.removeAll { $0.id == bill.id }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            VStack(spacing: 0) {
                HStack {
                    Text("New Scheduled Transaction")
                        .font(.headline)
                    Spacer()
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                Divider()

                Form {
                    TextField("Payee / Description:", text: $payee)
                    TextField("Amount ($):", text: $amountString)
                    Picker("Frequency:", selection: $frequency) {
                        ForEach(BillFrequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    DatePicker("Next Due Date:", selection: $dueDate, displayedComponents: [.date])
                    TextField("Account:", text: $accountName)
                    TextField("Category:", text: $category)
                    TextField("Memo:", text: $memo)
                }
                .padding(20)

                Divider()

                HStack {
                    Button("Cancel") { showingAddSheet = false }
                    Spacer()
                    Button("Save Bill") {
                        saveNewBill()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(width: 420, height: 350)
        }
    }

    private func saveNewBill() {
        let clean = amountString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        let amt = Double(clean) ?? 0.0
        let newBill = ScheduledBill(
            payee: payee.isEmpty ? "Scheduled Payment" : payee,
            amount: amt,
            frequency: frequency,
            nextDueDate: dueDate,
            accountName: accountName,
            category: category,
            memo: memo
        )
        store.scheduledBills.append(newBill)
        store.saveStandardData()
        showingAddSheet = false
        payee = ""
        amountString = ""
        memo = ""
    }
}
