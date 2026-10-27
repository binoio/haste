import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

public enum QuickenDateFormat: String, CaseIterable, Identifiable {
    case standardIso = "YYYY-MM-DD"
    case usSlash = "MM/DD/YYYY"
    case eraApostrophe = "M/D'YY (Quicken Era)"

    public var id: String { rawValue }
}

public enum CheckStyle: String, CaseIterable, Identifiable {
    case standard = "Standard Personal Check"
    case voucher = "Voucher Check (Business)"
    case wallet = "Wallet Check (Pocket)"

    public var id: String { rawValue }
}

#if canImport(SwiftUI)
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    @AppStorage("quicken.dateFormat") public var dateFormatRaw: String = QuickenDateFormat.standardIso.rawValue
    @AppStorage("quicken.currencySymbol") public var currencySymbol: String = "$"
    @AppStorage("quicken.soundEffectsEnabled") public var soundEffectsEnabled: Bool = true
    @AppStorage("quicken.quickFillEnabled") public var quickFillEnabled: Bool = true
    @AppStorage("quicken.confirmBeforeDelete") public var confirmBeforeDelete: Bool = true
    @AppStorage("quicken.advanceReminderDays") public var advanceReminderDays: Int = 14
    @AppStorage("quicken.startingCheckNumber") public var startingCheckNumber: Int = 1001
    @AppStorage("quicken.checkStyle") public var checkStyleRaw: String = CheckStyle.standard.rawValue

    public var dateFormat: QuickenDateFormat {
        get { QuickenDateFormat(rawValue: dateFormatRaw) ?? .standardIso }
        set { dateFormatRaw = newValue.rawValue }
    }

    public var checkStyle: CheckStyle {
        get { CheckStyle(rawValue: checkStyleRaw) ?? .standard }
        set { checkStyleRaw = newValue.rawValue }
    }

    public func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch dateFormat {
        case .standardIso:
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        case .usSlash:
            formatter.dateFormat = "MM/dd/yyyy"
            return formatter.string(from: date)
        case .eraApostrophe:
            return QIFParser.formatQIFDate(date)
        }
    }
}
#else
public final class AppSettings {
    public static let shared = AppSettings()
    public var dateFormatRaw: String = QuickenDateFormat.standardIso.rawValue
    public var currencySymbol: String = "$"
    public var soundEffectsEnabled: Bool = true
    public var quickFillEnabled: Bool = true
    public var confirmBeforeDelete: Bool = true
    public var advanceReminderDays: Int = 14
    public var startingCheckNumber: Int = 1001
    public var checkStyleRaw: String = CheckStyle.standard.rawValue

    public var dateFormat: QuickenDateFormat {
        get { QuickenDateFormat(rawValue: dateFormatRaw) ?? .standardIso }
        set { dateFormatRaw = newValue.rawValue }
    }

    public var checkStyle: CheckStyle {
        get { CheckStyle(rawValue: checkStyleRaw) ?? .standard }
        set { checkStyleRaw = newValue.rawValue }
    }

    public func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch dateFormat {
        case .standardIso:
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        case .usSlash:
            formatter.dateFormat = "MM/dd/yyyy"
            return formatter.string(from: date)
        case .eraApostrophe:
            return QIFParser.formatQIFDate(date)
        }
    }
}
#endif
