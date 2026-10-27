import SwiftUI
import AppKit

extension Notification.Name {
    public static let toggleHasteSidebar = Notification.Name("haste.toggleSidebar")
    public static let openNewAccountSheet = Notification.Name("haste.openNewAccountSheet")
    public static let openImportSheet = Notification.Name("haste.openImportSheet")
    public static let openExportSheet = Notification.Name("haste.openExportSheet")
    public static let reopenMainWindow = Notification.Name("haste.reopenMainWindow")
}

final class HasteAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = SparkleManager.shared
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                return false
            }
        }
        return true
    }
}

struct HasteCommands: Commands {
    @ObservedObject var store: DataStore
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                SparkleManager.shared.checkForUpdates()
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                var found = false
                for window in NSApp.windows where window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    found = true
                    break
                }
                if !found {
                    openWindow(id: "main-window")
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Account...") {
                NotificationCenter.default.post(name: .openNewAccountSheet, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandGroup(after: .importExport) {
            Button("Import...") {
                NotificationCenter.default.post(name: .openImportSheet, object: nil)
            }
            .keyboardShortcut("i", modifiers: .command)

            Button("Export...") {
                NotificationCenter.default.post(name: .openExportSheet, object: nil)
            }
            .keyboardShortcut("e", modifiers: .command)
        }

        CommandMenu("View") {
            Button("Banking") {
                store.selectCenter(.banking)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Planning") {
                store.selectCenter(.planning)
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Investing") {
                store.selectCenter(.investing)
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Reports & Graphs") {
                store.selectCenter(.reports)
            }
            .keyboardShortcut("4", modifiers: .command)

            Divider()

            Button("Write Checks") {
                store.activeQuickTab = "writeChecks"
            }
            .keyboardShortcut("w", modifiers: [.command, .option])

            Button("Reconcile Account...") {
                store.activeQuickTab = "reconcile"
            }
            .keyboardShortcut("r", modifiers: [.command, .option])

            Button("Bills & Reminders") {
                store.activeQuickTab = "reminders"
            }
            .keyboardShortcut("b", modifiers: [.command, .option])

            Divider()

            Button("Toggle Sidebar") {
                NotificationCenter.default.post(name: .toggleHasteSidebar, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
        }

        CommandGroup(after: .windowArrangement) {
            Divider()
            Button("Data Format Inspector") {
                openWindow(id: "data-inspector")
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
        }
    }
}

@main
public struct HasteApp: App {
    @NSApplicationDelegateAdaptor(HasteAppDelegate.self) var appDelegate
    @StateObject private var store = DataStore.shared

    public init() {}

    public var body: some Scene {
        WindowGroup(id: "main-window") {
            ContentView(store: store)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            HasteCommands(store: store)
        }

        Window("Data Format Inspector", id: "data-inspector") {
            FileInspectorView(store: store)
                .frame(minWidth: 720, minHeight: 520)
        }

        Settings {
            SettingsView(store: store)
        }
    }
}
