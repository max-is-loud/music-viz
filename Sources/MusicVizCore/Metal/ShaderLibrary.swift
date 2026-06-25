import Foundation
import Metal

public enum ShaderLibrary {
    public static func makeLibrary(device: MTLDevice) throws -> MTLLibrary {
        let url = Bundle.module.url(forResource: "CosmicShaders", withExtension: "metal")
        guard let url else {
            throw ShaderLibraryError.missingShaderSource
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        return try device.makeLibrary(source: source, options: nil)
    }
}

public enum ShaderLibraryError: LocalizedError {
    case missingShaderSource

    public var errorDescription: String? {
        "CosmicShaders.metal was not found in the app resources."
    }
}
