import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var store: DataStore = DataStore.shared
    @ObservedObject var sparkle = SparkleManager.shared
    @Environment(\.dismiss) private var dismiss

    public init(store: DataStore = DataStore.shared) {
        self.store = store
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "slider.horizontal.3")
                }

            registerTab
                .tabItem {
                    Label("Register", systemImage: "list.bullet.rectangle")
                }

            checksTab
                .tabItem {
                    Label("Write Checks", systemImage: "pencil.and.outline")
                }

            remindersTab
                .tabItem {
                    Label("Reminders", systemImage: "bell.badge")
                }

            updatesTab
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }

            disclaimersTab
                .tabItem {
                    Label("Disclaimers", systemImage: "shield.lefthalf.filled")
                }
        }
        .padding(16)
        .frame(width: 540, height: 380)
    }

    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            Section {
                Picker("Date Format:", selection: $settings.dateFormatRaw) {
                    ForEach(QuickenDateFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Picker("Currency Symbol:", selection: $settings.currencySymbol) {
                    Text("$ (US Dollar)").tag("$")
                    Text("€ (Euro)").tag("€")
                    Text("£ (British Pound)").tag("£")
                    Text("¥ (Yen)").tag("¥")
                    Text("C$ (Canadian Dollar)").tag("C$")
                }
                .pickerStyle(.menu)

                Toggle("Enable Sound Effects (Register chime & check writing)", isOn: $settings.soundEffectsEnabled)
            } header: {
                Text("Haste System Preferences")
                    .font(.headline)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Data Directory")
                            .font(.subheadline.weight(.semibold))
                        Text(store.loadedDirectoryPath.isEmpty ? "Default Haste Container" : store.loadedDirectoryPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button(action: revealDataLocationInFinder) {
                        Label("Reveal in Finder", systemImage: "folder.badge.gearshape")
                    }
                }
            } header: {
                Text("Data Storage Location")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    // MARK: - Register Tab
    private var registerTab: some View {
        Form {
            Section {
                Toggle("QuickFill: Auto-complete Payees & Categories", isOn: $settings.quickFillEnabled)
                Toggle("Confirm before deleting transactions from register", isOn: $settings.confirmBeforeDelete)
            } header: {
                Text("Checkbook Register Options")
                    .font(.headline)
            }

            Section {
                Text("Haste displays transactions using the classic dual-line green-bar register view with instant running balance calculation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    // MARK: - Write Checks Tab
    private var checksTab: some View {
        Form {
            Section {
                Picker("Check Style:", selection: $settings.checkStyleRaw) {
                    ForEach(CheckStyle.allCases) { style in
                        Text(style.rawValue).tag(style.rawValue)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Starting Check Number:")
                    Spacer()
                    TextField("Check #", value: $settings.startingCheckNumber, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 84)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $settings.startingCheckNumber, in: 1...999999)
                        .labelsHidden()
                }
            } header: {
                Text("Check Printing & Layout")
                    .font(.headline)
            }

            Section {
                Text("Checks written in Haste automatically generate English spelled-out dollar amounts and post directly into the selected bank account.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    // MARK: - Reminders Tab
    private var remindersTab: some View {
        Form {
            Section {
                Picker("Show Reminders in Advance:", selection: $settings.advanceReminderDays) {
                    Text("7 Days").tag(7)
                    Text("14 Days (Two Weeks)").tag(14)
                    Text("30 Days (One Month)").tag(30)
                }
                .pickerStyle(.menu)
            } header: {
                Text("Financial Calendar & Scheduled Transactions")
                    .font(.headline)
            }

            Section {
                Text("Upcoming bills and recurring deposits appear on the Financial Center home screen and Bills & Reminders center.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    // MARK: - Updates Tab (Sparkle)
    private var updatesTab: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Software Updates")
                            .font(.headline)
                        Text("Haste checks for new releases and security patches via Sparkle.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { sparkle.checkForUpdates() }) {
                        Label("Check for Updates…", systemImage: "arrow.clockwise")
                    }
                }
            } header: {
                Text("Sparkle Auto-Update Engine")
            }

            Section {
                Text("Updates are cryptographically verified and distributed through GitHub Releases.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    // MARK: - Disclaimers Tab
    private var disclaimersTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Legal Notice & Disclaimers")
                    .font(.headline)

                Group {
                    Text("Independent Research Project")
                        .font(.subheadline.bold())
                    Text("Haste is an independent, open-source software project created solely for historical digital preservation, software archaeology, and reverse-engineering research.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Trademark & Corporate Affiliation Disclaimer")
                        .font(.subheadline.bold())
                    Text("Haste is NOT affiliated with, sponsored by, authorized by, endorsed by, or in any way connected to Intuit Inc., Quicken Inc., Aquiline Capital Partners, or any of their subsidiaries or affiliates. 'Quicken', 'Quicken Deluxe', and all related product names, logos, and marks are registered trademarks of their respective owners.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Disclaimer of Warranties ('AS IS')")
                        .font(.subheadline.bold())
                    Text("This software is provided 'AS IS' WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY ARISING FROM THE USE OF THIS SOFTWARE.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .padding(8)
    }

    private func revealDataLocationInFinder() {
        let dirURL = DataStore.standardDataDirectoryURL
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dirURL.path)
    }
}
