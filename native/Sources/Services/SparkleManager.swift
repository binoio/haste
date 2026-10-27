import Foundation
import Combine
#if canImport(Sparkle)
import Sparkle

public final class SparkleManager: NSObject, ObservableObject {
    public static let shared = SparkleManager()

    public lazy var updaterController: SPUStandardUpdaterController = {
        SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    }()

    @Published public var canCheckForUpdates: Bool = false

    public override init() {
        super.init()
        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil {
            updaterController.startUpdater()
            updaterController.updater.publisher(for: \.canCheckForUpdates)
                .assign(to: &$canCheckForUpdates)
        }
    }

    public func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
#else
public final class SparkleManager: NSObject, ObservableObject {
    public static let shared = SparkleManager()
    @Published public var canCheckForUpdates: Bool = false
    public func checkForUpdates() {}
}
#endif
