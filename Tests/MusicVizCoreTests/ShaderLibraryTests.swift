@testable import MusicVizCore
import Metal
import XCTest

final class ShaderLibraryTests: XCTestCase {
    func testShaderSourceURLFindsShaderInPackagedAppResourcesWithoutModuleFallback() throws {
        let appBundle = try makeTemporaryAppBundle(
            withShaderSource: "#include <metal_stdlib>\n"
        )

        let url = try ShaderLibrary.shaderSourceURL(
            mainBundle: appBundle,
            moduleBundleProvider: {
                XCTFail("Packaged app resources should be checked before Bundle.module.")
                return Bundle(for: ShaderLibraryTests.self)
            }
        )

        XCTAssertEqual(url.lastPathComponent, "CosmicShaders.metal")
        XCTAssertTrue(url.path.contains("Contents/Resources/MusicViz_MusicVizCore.bundle"))
    }

    func testShaderSourceURLThrowsWhenPackagedAppShaderIsMissing() throws {
        let appBundle = try makeTemporaryAppBundle(withShaderSource: nil)

        XCTAssertThrowsError(
            try ShaderLibrary.shaderSourceURL(
                mainBundle: appBundle,
                moduleBundleProvider: {
                    XCTFail("Missing packaged app resources should throw without Bundle.module.")
                    return Bundle(for: ShaderLibraryTests.self)
                }
            )
        ) { error in
            guard case ShaderLibraryError.missingShaderSource = error else {
                return XCTFail("Expected missingShaderSource, got \(error).")
            }
        }
    }

    func testShaderLibraryLoadsParticleFunctionsWhenMetalDeviceIsAvailable() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let library = try ShaderLibrary.makeLibrary(device: device)

        XCTAssertNotNil(library.makeFunction(name: "particle_vertex"))
        XCTAssertNotNil(library.makeFunction(name: "particle_fragment"))
    }

    func testShaderLibraryLoadsDecayFieldsFunctionWhenMetalDeviceIsAvailable() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let library = try ShaderLibrary.makeLibrary(device: device)

        XCTAssertNotNil(library.makeFunction(name: "decay_fields"))
    }

    func testShaderLibraryLoadsIntegrateParticlesFunctionWhenMetalDeviceIsAvailable() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let library = try ShaderLibrary.makeLibrary(device: device)

        XCTAssertNotNil(library.makeFunction(name: "integrate_particles"))
    }

    func testShaderLibraryLoadsFieldDepositFunctionsWhenMetalDeviceIsAvailable() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let library = try ShaderLibrary.makeLibrary(device: device)

        XCTAssertNotNil(library.makeFunction(name: "field_deposit_vertex"))
        XCTAssertNotNil(library.makeFunction(name: "field_deposit_fragment"))
    }

    private func makeTemporaryAppBundle(withShaderSource source: String?) throws -> Bundle {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appURL = rootURL.appendingPathComponent("MusicViz.app", isDirectory: true)
        let resourceBundleURL = appURL
            .appendingPathComponent("Contents/Resources/MusicViz_MusicVizCore.bundle", isDirectory: true)

        try FileManager.default.createDirectory(
            at: resourceBundleURL,
            withIntermediateDirectories: true
        )
        if let source {
            try source.write(
                to: resourceBundleURL.appendingPathComponent("CosmicShaders.metal"),
                atomically: true,
                encoding: .utf8
            )
        }
        addTeardownBlock {
            try? FileManager.default.removeItem(at: rootURL)
        }
        return try XCTUnwrap(Bundle(url: appURL))
    }
}
