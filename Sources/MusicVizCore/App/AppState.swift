import Combine
import Foundation

@MainActor
public final class AppState: ObservableObject {
    @Published public var isLabVisible: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var statusText: String = "Cosmic simmer"

    public init() {}
}
