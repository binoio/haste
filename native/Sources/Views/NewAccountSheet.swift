import SwiftUI

public struct NewAccountSheet: View {
    @ObservedObject var store: DataStore
    @Binding var isPresented: Bool

    @State private var accountName: String = ""
    @State private var accountType: AccountType = .bank
    @State private var openingBalanceString: String = "0.00"
    @State private var openingDate: Date = Date()
    @State private var errorMessage: String = ""

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color(red: 0.0, green: 0.35, blue: 0.20))
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Haste - New Account Setup")
                        .font(.headline)
                    Text("Enter the account information and opening balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            Divider()

            // Form
            Form {
                Section {
                    TextField("Account Name:", text: $accountName)
                        .textFieldStyle(.roundedBorder)

                    Picker("Account Type:", selection: $accountType) {
                        ForEach(AccountType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Opening Balance ($):", text: $openingBalanceString)
                        .textFieldStyle(.roundedBorder)

                    DatePicker("As of Date:", selection: $openingDate, displayedComponents: [.date])
                }
            }
            .padding(20)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
            }

            Spacer()
            Divider()

            // Buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Account") {
                    createAccount()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 440, height: 320)
    }

    private func createAccount() {
        let trimmed = accountName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            errorMessage = "Please enter an account name."
            return
        }

        if store.accounts.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            errorMessage = "An account with this name already exists."
            return
        }

        let cleanAmt = openingBalanceString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        let bal = Double(cleanAmt) ?? 0.0

        store.createAccount(
            name: trimmed,
            type: accountType,
            openingBalance: bal,
            openingDate: openingDate
        )
        isPresented = false
    }
}
