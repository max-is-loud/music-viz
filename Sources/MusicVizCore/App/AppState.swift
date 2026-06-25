import Combine
import Foundation

@MainActor
public final class AppState: ObservableObject {
    @Published public var isLabVisible: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var statusText: String = "Cosmic simmer"
    @Published public var parameters: SimulationParameters = SimulationParameters()
    @Published public var debugOverlay: String = "None"

    public init() {}

    public func resetToDefaults() {
        parameters = SimulationParameters()
        debugOverlay = "None"
        statusText = "Cosmic simmer"
    }
}
