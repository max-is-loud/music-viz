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

    func testIntegrateParticlesLifecycleUsesOriginalKindWithoutCollapseSideEffects() throws {
        let source = try String(contentsOf: ShaderLibrary.shaderSourceURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("uint originalKind = p.kind;"))
        XCTAssertTrue(source.contains("if ((originalKind == 0 || originalKind == 1) &&"))
        XCTAssertTrue(source.contains("if (originalKind == 2 && p.temperature >= 0.9 && p.age >= 8.0)"))
        XCTAssertTrue(source.contains("if (originalKind == 3 && p.temperature >= 2.0 && p.mass >= 2.8 && p.age >= 40.0)"))
        XCTAssertTrue(source.contains("if (originalKind == 4 &&"))
        XCTAssertFalse(source.contains("p.mass *= 1.25"))
        XCTAssertFalse(source.contains("p.temperature = 0.65"))
    }

    func testGpuSimParamsLayoutMatchesMetalSimParamsAudioInjectionFields() throws {
        let swiftSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MusicVizCore/Metal/CosmicRenderer.swift")
        let swiftSource = try String(contentsOf: swiftSourceURL, encoding: .utf8)
        let metalSource = try String(contentsOf: ShaderLibrary.shaderSourceURL(), encoding: .utf8)
        let expectedFields = [
            "deltaTime",
            "timeScale",
            "audioInfluence",
            "gravityStrength",
            "heatDecay",
            "turbulenceStrength",
            "starIgnitionThreshold",
            "collapseThreshold",
            "compressionStrength",
            "shockwaveStrength",
            "heatInput",
            "turbulenceInput",
            "radiationInput",
            "coolingBias",
            "particleCount",
            "fieldResolution"
        ]

        XCTAssertEqual(fieldNames(inSwiftStruct: "GPUSimParams", source: swiftSource), expectedFields)
        XCTAssertEqual(fieldNames(inMetalStruct: "SimParams", source: metalSource), expectedFields)
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

    private func fieldNames(inSwiftStruct structName: String, source: String) -> [String] {
        fieldLines(inStruct: structName, source: source).compactMap { line in
            guard line.hasPrefix("var ") else { return nil }
            return line
                .dropFirst("var ".count)
                .split(separator: ":", maxSplits: 1)
                .first
                .map(String.init)
        }
    }

    private func fieldNames(inMetalStruct structName: String, source: String) -> [String] {
        fieldLines(inStruct: structName, source: source).compactMap { line in
            guard line.hasSuffix(";") else { return nil }
            return line
                .dropLast()
                .split(separator: " ")
                .last
                .map(String.init)
        }
    }

    private func fieldLines(inStruct structName: String, source: String) -> [String] {
        guard let bodyStart = source.range(of: "struct \(structName) {")?.upperBound,
              let bodyEnd = source[bodyStart...].range(of: "\n}")?.lowerBound else {
            return []
        }

        return source[bodyStart..<bodyEnd]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
