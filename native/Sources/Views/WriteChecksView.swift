import SwiftUI

public struct WriteChecksView: View {
    @ObservedObject var store: DataStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var payee: String = ""
    @State private var amountString: String = ""
    @State private var date: Date = Date()
    @State private var checkNumber: String = "Print"
    @State private var memo: String = ""
    @State private var category: String = ""
    @State private var address: String = ""
    @State private var showSplits: Bool = false
    @State private var splits: [SplitItem] = []
    @State private var statusMessage: String = ""

    private var currentAmount: Double {
        let clean = amountString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        return Double(clean) ?? 0.0
    }

    private var spelledWords: String {
        NumberToWords.toCheckWords(amount: currentAmount)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Top control bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Write Checks: \(store.selectedAccount?.name ?? "No Account Selected")")
                            .font(.title3.weight(.bold))
                        Text("Click in any field to edit. The check will be recorded into the account register.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    Picker("Account", selection: $store.selectedAccountId) {
                        ForEach(store.accounts.filter { $0.type == .bank || $0.type == .cash }) { a in
                            Text(a.name).tag(a.id as String?)
                        }
                    }
                    .frame(width: 220)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Classic Haste Paper Check Face
                VStack(spacing: 12) {
                    // Check Header: Bank Name & Date / Check Number
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.selectedAccount?.name ?? "CHECKING ACCOUNT")
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .foregroundColor(.primary)
                            Text("Haste Electronic Checkbook")
                                .font(.system(size: 9, design: .serif))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            HStack {
                                Text("Check No:")
                                    .font(.caption.bold())
                                TextField("Print", text: $checkNumber)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }

                            HStack {
                                Text("Date:")
                                    .font(.caption.bold())
                                DatePicker("", selection: $date, displayedComponents: [.date])
                                    .labelsHidden()
                                    .frame(width: 130)
                            }
                        }
                    }

                    // Pay To Line & Amount
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("PAY TO THE\nORDER OF")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 75)

                        TextField("Payee Name", text: $payee)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                        Text("$")
                            .font(.system(size: 15, weight: .bold))

                        TextField("0.00", text: $amountString)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(width: 110)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }

                    // Written Out Words Line
                    HStack(spacing: 8) {
                        Spacer().frame(width: 83)
                        Text(spelledWords)
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .cornerRadius(4)
                    }

                    // Address & Memo / Category
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ADDRESS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            TextEditor(text: $address)
                                .font(.system(size: 11))
                                .scrollContentBackground(.hidden)
                                .background(Color(NSColor.textBackgroundColor))
                                .frame(width: 220, height: 75)
                                .border(Color.gray.opacity(colorScheme == .dark ? 0.5 : 0.3), width: 1)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("MEMO:")
                                    .font(.caption.bold())
                                    .frame(width: 65, alignment: .trailing)
                                TextField("Memo description...", text: $memo)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("CATEGORY:")
                                    .font(.caption.bold())
                                    .frame(width: 65, alignment: .trailing)
                                TextField("Category / Tag", text: $category)
                                    .textFieldStyle(.roundedBorder)

                                Button(action: { showSplits = true }) {
                                    Text("Split...")
                                        .font(.caption.bold())
                                }
                            }

                            if !splits.isEmpty {
                                Text("\(splits.count) split categories defined")
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(red: 0.14, green: 0.17, blue: 0.15) : Color(red: 0.96, green: 0.98, blue: 0.96))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 6, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorScheme == .dark ? Color(red: 0.25, green: 0.45, blue: 0.30) : Color(red: 0.70, green: 0.82, blue: 0.72), lineWidth: 2)
                )
                .padding(.horizontal, 20)

                // Check Action Bar
                HStack(spacing: 12) {
                    Button(action: recordCheck) {
                        Label("Record Check", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(colorScheme == .dark ? Color(red: 0.15, green: 0.52, blue: 0.28) : Color(red: 0.0, green: 0.35, blue: 0.20))

                    Button("Restore / Clear", action: clearFields)
                        .buttonStyle(.bordered)

                    Spacer()

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }

                    Text(String(format: "Ending Balance: $%.2f", store.selectedAccount?.balance ?? 0.0))
                        .font(.caption.monospaced().bold())
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showSplits) {
            SplitEditorSheet(
                splits: $splits,
                totalTargetAmount: currentAmount,
                onSave: { updated in
                    self.splits = updated
                    self.showSplits = false
                },
                onCancel: {
                    self.showSplits = false
                }
            )
        }
    }

    private func recordCheck() {
        let trimmedPayee = payee.trimmingCharacters(in: .whitespaces)
        guard !trimmedPayee.isEmpty else {
            statusMessage = "Please enter a Payee."
            return
        }

        guard currentAmount > 0 else {
            statusMessage = "Please enter an amount greater than $0.00."
            return
        }

        store.recordCheck(
            payee: trimmedPayee,
            amount: currentAmount,
            date: date,
            memo: memo,
            category: category,
            checkNumber: checkNumber
        )

        statusMessage = "Check recorded to \(store.selectedAccount?.name ?? "Register")!"
        clearFields()
    }

    private func clearFields() {
        payee = ""
        amountString = ""
        memo = ""
        category = ""
        address = ""
        splits = []
        checkNumber = "Print"
    }
}
