import Foundation

public protocol AudioInputSource: AnyObject {
    var latestFeatures: AudioFeatures { get }
    var statusText: String { get }
    var isUsingFallback: Bool { get }
    func start()
    func stop()
}
