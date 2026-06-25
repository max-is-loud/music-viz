import Foundation
import Metal

public enum ShaderLibrary {
    public static func makeLibrary(device: MTLDevice) throws -> MTLLibrary {
        let url = try shaderSourceURL()
        let source = try String(contentsOf: url, encoding: .utf8)
        return try device.makeLibrary(source: source, options: nil)
    }

    static func shaderSourceURL(
        mainBundle: Bundle = .main,
        moduleBundleProvider: () -> Bundle = { Bundle.module },
        fileManager: FileManager = .default
    ) throws -> URL {
        for bundleURL in resourceBundleCandidates(mainBundle: mainBundle) {
            let shaderURL = bundleURL.appendingPathComponent("CosmicShaders.metal")
            if fileManager.fileExists(atPath: shaderURL.path) {
                return shaderURL
            }
        }

        if mainBundle.bundleURL.pathExtension != "app",
           let url = moduleBundleProvider().url(forResource: "CosmicShaders", withExtension: "metal") {
            return url
        }

        throw ShaderLibraryError.missingShaderSource
    }

    private static func resourceBundleCandidates(mainBundle: Bundle) -> [URL] {
        var candidates: [URL] = []
        if let resourceURL = mainBundle.resourceURL {
            candidates.append(resourceURL.appendingPathComponent(resourceBundleName, isDirectory: true))
        }
        candidates.append(mainBundle.bundleURL.appendingPathComponent(resourceBundleName, isDirectory: true))
        if let executableURL = mainBundle.executableURL {
            candidates.append(
                executableURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(resourceBundleName, isDirectory: true)
            )
        }
        return candidates.reduce(into: []) { uniqueCandidates, candidate in
            if !uniqueCandidates.contains(candidate) {
                uniqueCandidates.append(candidate)
            }
        }
    }

    private static var resourceBundleName: String {
        "MusicViz_MusicVizCore.bundle"
    }
}

public enum ShaderLibraryError: LocalizedError {
    case missingShaderSource

    public var errorDescription: String? {
        "CosmicShaders.metal was not found in the app resources."
    }
}
