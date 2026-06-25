# Cosmic Visualizer Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first native macOS Tahoe 26+, Apple Silicon-only Swift + Metal prototype for the simulation-first cosmic music visualizer.

**Architecture:** Use a Swift Package with a tiny executable target and a testable `MusicVizCore` library. Build a real `.app` bundle with an Info.plist so macOS permissions and fullscreen behavior work, while Metal compute/render passes run the particle-field simulation.

**Tech Stack:** Swift, Swift Package Manager, AppKit, SwiftUI overlay where useful, Metal, MetalKit, Core Audio taps, Accelerate, XCTest, macOS Tahoe 26+.

---

## Scope

This plan builds the first vertical prototype from the approved design spec:

- A runnable native macOS app bundle.
- A fullscreen Metal view.
- A particle and field simulation loop.
- A simple cosmic lifecycle.
- System output audio analysis and simulation injection.
- Ambient default UI with an on-demand lab panel.

The plan does not implement recording/export, MIDI, 3D rendering, plugins, networking, or scientific astrophysics.

## File Structure

Create this structure:

```text
Package.swift
Makefile
Resources/AppBundle/Info.plist
Sources/MusicVizApp/main.swift
Sources/MusicVizCore/App/AppLauncher.swift
Sources/MusicVizCore/App/MainWindowController.swift
Sources/MusicVizCore/App/AppState.swift
Sources/MusicVizCore/Audio/AudioAnalyzer.swift
Sources/MusicVizCore/Audio/AudioFeatures.swift
Sources/MusicVizCore/Audio/AudioForceMapper.swift
Sources/MusicVizCore/Audio/AudioInputSource.swift
Sources/MusicVizCore/Audio/SystemAudioTap.swift
Sources/MusicVizCore/Audio/SyntheticAudioSource.swift
Sources/MusicVizCore/Lab/LabPanelView.swift
Sources/MusicVizCore/Metal/CosmicRenderer.swift
Sources/MusicVizCore/Metal/MetalCanvasView.swift
Sources/MusicVizCore/Metal/MetalFieldState.swift
Sources/MusicVizCore/Metal/MetalParticleState.swift
Sources/MusicVizCore/Metal/ShaderLibrary.swift
Sources/MusicVizCore/Resources/Shaders/CosmicShaders.metal
Sources/MusicVizCore/Simulation/AudioInjection.swift
Sources/MusicVizCore/Simulation/LifecycleRules.swift
Sources/MusicVizCore/Simulation/ParticleSeed.swift
Sources/MusicVizCore/Simulation/SeededRandom.swift
Sources/MusicVizCore/Simulation/SimulationParameters.swift
Tests/MusicVizCoreTests/AudioAnalyzerTests.swift
Tests/MusicVizCoreTests/AudioForceMapperTests.swift
Tests/MusicVizCoreTests/LifecycleRulesTests.swift
Tests/MusicVizCoreTests/ParticleSeedTests.swift
Tests/MusicVizCoreTests/SimulationParametersTests.swift
```

Responsibilities:

- `MusicVizApp`: executable entrypoint only.
- `App`: macOS app lifecycle, app state, fullscreen window, and view composition.
- `Audio`: capture abstraction, Core Audio tap implementation, synthetic fallback, analysis, and mapping from audio features to simulation forces.
- `Simulation`: pure Swift configuration, deterministic seed generation, lifecycle rules, and audio injection structs.
- `Metal`: GPU resources, shader loading, render loop, compute dispatch, and view integration.
- `Lab`: on-demand controls and debug state.
- `Resources`: Info.plist for the app bundle and Metal shader source.
- `Tests`: pure Swift tests for deterministic and bounded behavior.

## Task 1: Package, App Bundle, And Bootstrap

**Files:**
- Create: `Package.swift`
- Create: `Makefile`
- Create: `Resources/AppBundle/Info.plist`
- Create: `Sources/MusicVizApp/main.swift`
- Create: `Sources/MusicVizCore/App/AppLauncher.swift`
- Create: `Sources/MusicVizCore/App/AppState.swift`
- Create: `Sources/MusicVizCore/App/MainWindowController.swift`

- [ ] **Step 1: Create package manifest**

Add `Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MusicViz",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "MusicViz", targets: ["MusicVizApp"]),
        .library(name: "MusicVizCore", targets: ["MusicVizCore"])
    ],
    targets: [
        .target(
            name: "MusicVizCore",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("Accelerate"),
                .linkedFramework("AppKit"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "MusicVizApp",
            dependencies: ["MusicVizCore"]
        ),
        .testTarget(
            name: "MusicVizCoreTests",
            dependencies: ["MusicVizCore"]
        )
    ]
)
```

- [ ] **Step 2: Create app bundle Info.plist**

Add `Resources/AppBundle/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>MusicViz</string>
  <key>CFBundleIdentifier</key>
  <string>dev.maxisloud.musicviz</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>MusicViz</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAudioCaptureUsageDescription</key>
  <string>MusicViz analyzes system audio locally to drive the cosmic simulation.</string>
</dict>
</plist>
```

- [ ] **Step 3: Create build helper**

Add `Makefile`:

```make
.PHONY: build test app run clean

CONFIG ?= debug
EXECUTABLE := .build/$(CONFIG)/MusicViz
APP := .build/MusicViz.app
RESOURCE_BUNDLE := .build/$(CONFIG)/MusicViz_MusicVizCore.bundle

build:
	swift build -c $(CONFIG)

test:
	swift test

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	mkdir -p $(APP)/Contents/Resources
	cp $(EXECUTABLE) $(APP)/Contents/MacOS/MusicViz
	cp Resources/AppBundle/Info.plist $(APP)/Contents/Info.plist
	if [ -d "$(RESOURCE_BUNDLE)" ]; then cp -R "$(RESOURCE_BUNDLE)" "$(APP)/Contents/Resources/"; fi

run: app
	open $(APP)

clean:
	rm -rf .build
```

- [ ] **Step 4: Create executable entrypoint**

Add `Sources/MusicVizApp/main.swift`:

```swift
import MusicVizCore

AppLauncher.main()
```

- [ ] **Step 5: Create minimal app state and launcher**

Add `Sources/MusicVizCore/App/AppState.swift`:

```swift
import Combine
import Foundation

@MainActor
public final class AppState: ObservableObject {
    @Published public var isLabVisible: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var statusText: String = "Cosmic simmer"

    public init() {}
}
```

Add `Sources/MusicVizCore/App/AppLauncher.swift`:

```swift
import AppKit

@MainActor
public enum AppLauncher {
    public static func main() {
        let app = NSApplication.shared
        let delegate = BootstrapDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

@MainActor
private final class BootstrapDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        let controller = MainWindowController(appState: state)
        self.windowController = controller
        controller.showWindow(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
```

- [ ] **Step 6: Create a minimal native window controller**

Add `Sources/MusicVizCore/App/MainWindowController.swift`:

```swift
import AppKit

@MainActor
public final class MainWindowController: NSWindowController {
    private let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
        let label = NSTextField(labelWithString: appState.statusText)
        label.alignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .medium)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(
            red: 0.006,
            green: 0.008,
            blue: 0.018,
            alpha: 1
        ).cgColor
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let window = NSWindow(
            contentRect: container.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MusicViz"
        window.contentView = container
        window.collectionBehavior = [.fullScreenPrimary, .canJoinAllSpaces]
        window.titlebarAppearsTransparent = true
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }
}
```

- [ ] **Step 7: Run build**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add Package.swift Makefile Resources/AppBundle/Info.plist Sources/MusicVizApp Sources/MusicVizCore/App
git commit -m "feat: scaffold native Swift package"
```

## Task 2: Pure Simulation Types And Tests

**Files:**
- Create: `Sources/MusicVizCore/Simulation/SimulationParameters.swift`
- Create: `Sources/MusicVizCore/Simulation/SeededRandom.swift`
- Create: `Sources/MusicVizCore/Audio/AudioFeatures.swift`
- Create: `Tests/MusicVizCoreTests/SimulationParametersTests.swift`

- [ ] **Step 1: Write failing parameter tests**

Add `Tests/MusicVizCoreTests/SimulationParametersTests.swift`:

```swift
import XCTest
@testable import MusicVizCore

final class SimulationParametersTests: XCTestCase {
    func testClampedKeepsValuesInsideStableRanges() {
        let raw = SimulationParameters(
            timeScale: -10,
            audioInfluence: 9,
            particleCountTarget: 99_999_999,
            fieldResolution: 123,
            gravityStrength: -2,
            heatDecay: 2,
            turbulenceStrength: -1,
            starIgnitionThreshold: -50,
            collapseThreshold: 0,
            renderIntensity: 20,
            bloomStrength: -4
        )

        let clamped = raw.clamped()

        XCTAssertEqual(clamped.timeScale, 0.02, accuracy: 0.0001)
        XCTAssertEqual(clamped.audioInfluence, 3.0, accuracy: 0.0001)
        XCTAssertEqual(clamped.particleCountTarget, 2_000_000)
        XCTAssertEqual(clamped.fieldResolution, 128)
        XCTAssertEqual(clamped.gravityStrength, 0.0, accuracy: 0.0001)
        XCTAssertEqual(clamped.heatDecay, 0.999, accuracy: 0.0001)
        XCTAssertEqual(clamped.turbulenceStrength, 0.0, accuracy: 0.0001)
        XCTAssertEqual(clamped.starIgnitionThreshold, 0.01, accuracy: 0.0001)
        XCTAssertEqual(clamped.collapseThreshold, 0.01, accuracy: 0.0001)
        XCTAssertEqual(clamped.renderIntensity, 5.0, accuracy: 0.0001)
        XCTAssertEqual(clamped.bloomStrength, 0.0, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter SimulationParametersTests
```

Expected: FAIL with missing `SimulationParameters`.

- [ ] **Step 3: Implement simulation parameters**

Add `Sources/MusicVizCore/Simulation/SimulationParameters.swift`:

```swift
import Foundation

public struct SimulationParameters: Equatable, Sendable {
    public var timeScale: Float
    public var audioInfluence: Float
    public var particleCountTarget: Int
    public var fieldResolution: Int
    public var gravityStrength: Float
    public var heatDecay: Float
    public var turbulenceStrength: Float
    public var starIgnitionThreshold: Float
    public var collapseThreshold: Float
    public var renderIntensity: Float
    public var bloomStrength: Float

    public init(
        timeScale: Float = 1.0,
        audioInfluence: Float = 1.0,
        particleCountTarget: Int = 250_000,
        fieldResolution: Int = 512,
        gravityStrength: Float = 1.0,
        heatDecay: Float = 0.985,
        turbulenceStrength: Float = 0.35,
        starIgnitionThreshold: Float = 0.72,
        collapseThreshold: Float = 0.92,
        renderIntensity: Float = 1.0,
        bloomStrength: Float = 0.8
    ) {
        self.timeScale = timeScale
        self.audioInfluence = audioInfluence
        self.particleCountTarget = particleCountTarget
        self.fieldResolution = fieldResolution
        self.gravityStrength = gravityStrength
        self.heatDecay = heatDecay
        self.turbulenceStrength = turbulenceStrength
        self.starIgnitionThreshold = starIgnitionThreshold
        self.collapseThreshold = collapseThreshold
        self.renderIntensity = renderIntensity
        self.bloomStrength = bloomStrength
    }

    public func clamped() -> SimulationParameters {
        SimulationParameters(
            timeScale: timeScale.clamped(to: 0.02...8.0),
            audioInfluence: audioInfluence.clamped(to: 0.0...3.0),
            particleCountTarget: particleCountTarget.clamped(to: 1_024...2_000_000),
            fieldResolution: nearestPowerOfTwo(fieldResolution).clamped(to: 128...2048),
            gravityStrength: gravityStrength.clamped(to: 0.0...5.0),
            heatDecay: heatDecay.clamped(to: 0.80...0.999),
            turbulenceStrength: turbulenceStrength.clamped(to: 0.0...4.0),
            starIgnitionThreshold: starIgnitionThreshold.clamped(to: 0.01...2.0),
            collapseThreshold: collapseThreshold.clamped(to: 0.01...4.0),
            renderIntensity: renderIntensity.clamped(to: 0.0...5.0),
            bloomStrength: bloomStrength.clamped(to: 0.0...3.0)
        )
    }
}

private func nearestPowerOfTwo(_ value: Int) -> Int {
    guard value > 1 else { return 1 }
    let lower = 1 << Int(floor(log2(Double(value))))
    let upper = lower << 1
    return (value - lower) < (upper - value) ? lower : upper
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
```

- [ ] **Step 4: Add deterministic random and audio feature structs**

Add `Sources/MusicVizCore/Simulation/SeededRandom.swift`:

```swift
import Foundation

public struct SeededRandom: Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x4d595a56495a0001 : seed
    }

    public mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    public mutating func nextFloat() -> Float {
        Float(nextUInt64() >> 40) / Float(1 << 24)
    }

    public mutating func nextSignedFloat() -> Float {
        nextFloat() * 2 - 1
    }
}
```

Add `Sources/MusicVizCore/Audio/AudioFeatures.swift`:

```swift
import Foundation

public struct AudioFeatures: Equatable, Sendable {
    public var overallEnergy: Float
    public var bass: Float
    public var lowMid: Float
    public var mid: Float
    public var high: Float
    public var transient: Float
    public var brightness: Float
    public var sustainedIntensity: Float
    public var isSilent: Bool

    public static let silence = AudioFeatures(
        overallEnergy: 0,
        bass: 0,
        lowMid: 0,
        mid: 0,
        high: 0,
        transient: 0,
        brightness: 0,
        sustainedIntensity: 0,
        isSilent: true
    )

    public init(
        overallEnergy: Float,
        bass: Float,
        lowMid: Float,
        mid: Float,
        high: Float,
        transient: Float,
        brightness: Float,
        sustainedIntensity: Float,
        isSilent: Bool
    ) {
        self.overallEnergy = overallEnergy
        self.bass = bass
        self.lowMid = lowMid
        self.mid = mid
        self.high = high
        self.transient = transient
        self.brightness = brightness
        self.sustainedIntensity = sustainedIntensity
        self.isSilent = isSilent
    }
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter SimulationParametersTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/MusicVizCore/Simulation/SimulationParameters.swift Sources/MusicVizCore/Simulation/SeededRandom.swift Sources/MusicVizCore/Audio/AudioFeatures.swift Tests/MusicVizCoreTests/SimulationParametersTests.swift
git commit -m "feat: add simulation primitives"
```

## Task 3: Window, Metal View, And Clear Renderer

**Files:**
- Modify: `Sources/MusicVizCore/App/MainWindowController.swift`
- Create: `Sources/MusicVizCore/Metal/MetalCanvasView.swift`
- Create: `Sources/MusicVizCore/Metal/CosmicRenderer.swift`

- [ ] **Step 1: Add Metal canvas and renderer**

Add `Sources/MusicVizCore/Metal/CosmicRenderer.swift`:

```swift
import Foundation
import Metal
import MetalKit

@MainActor
public final class CosmicRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var time: Float = 0

    public init(view: MTKView) throws {
        guard let device = view.device else {
            throw RendererError.missingDevice
        }
        guard let queue = device.makeCommandQueue() else {
            throw RendererError.missingCommandQueue
        }
        self.device = device
        self.commandQueue = queue
        super.init()
        view.clearColor = MTLClearColor(red: 0.006, green: 0.008, blue: 0.018, alpha: 1)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        time += 1.0 / Float(max(view.preferredFramesPerSecond, 1))
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let pulse = Double((sin(time * 0.5) + 1) * 0.5)
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.006 + pulse * 0.015,
            green: 0.008 + pulse * 0.01,
            blue: 0.018 + pulse * 0.035,
            alpha: 1
        )

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.endEncoding()
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

public enum RendererError: LocalizedError {
    case missingDevice
    case missingCommandQueue

    public var errorDescription: String? {
        switch self {
        case .missingDevice:
            return "Metal device is unavailable."
        case .missingCommandQueue:
            return "Metal command queue could not be created."
        }
    }
}
```

Add `Sources/MusicVizCore/Metal/MetalCanvasView.swift`:

```swift
import AppKit
import Metal
import MetalKit

@MainActor
public final class MetalCanvasView: MTKView {
    private var cosmicRenderer: CosmicRenderer?

    public init(appState: AppState) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("MusicViz requires an Apple Silicon Mac with Metal support.")
        }
        super.init(frame: .zero, device: device)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = false
        preferredFramesPerSecond = 120
        enableSetNeedsDisplay = false
        isPaused = false
        autoResizeDrawable = true

        do {
            let renderer = try CosmicRenderer(view: self)
            self.cosmicRenderer = renderer
            delegate = renderer
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}
```

- [ ] **Step 2: Add main window controller**

Add `Sources/MusicVizCore/App/MainWindowController.swift`:

```swift
import AppKit

@MainActor
public final class MainWindowController: NSWindowController {
    private let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
        let content = MetalCanvasView(appState: appState)
        let window = NSWindow(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1600, height: 1000),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MusicViz"
        window.contentView = content
        window.collectionBehavior = [.fullScreenPrimary, .canJoinAllSpaces]
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }
}
```

- [ ] **Step 3: Build and run app bundle**

Run:

```bash
make app
open .build/MusicViz.app
```

Expected: A native app window opens with a subtly pulsing dark cosmic background.

- [ ] **Step 4: Run tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/MusicVizCore/App Sources/MusicVizCore/Metal
git commit -m "feat: add native Metal app shell"
```

## Task 4: Deterministic Particle Seeding

**Files:**
- Create: `Sources/MusicVizCore/Simulation/ParticleSeed.swift`
- Create: `Sources/MusicVizCore/Metal/MetalParticleState.swift`
- Create: `Tests/MusicVizCoreTests/ParticleSeedTests.swift`

- [ ] **Step 1: Write failing particle seed tests**

Add `Tests/MusicVizCoreTests/ParticleSeedTests.swift`:

```swift
import XCTest
@testable import MusicVizCore

final class ParticleSeedTests: XCTestCase {
    func testSeededParticlesAreDeterministic() {
        let a = ParticleSeed.generate(count: 4, seed: 42)
        let b = ParticleSeed.generate(count: 4, seed: 42)
        XCTAssertEqual(a, b)
    }

    func testSeededParticlesStayInsideNormalizedSpace() {
        let particles = ParticleSeed.generate(count: 256, seed: 9)
        XCTAssertEqual(particles.count, 256)
        for particle in particles {
            XCTAssertGreaterThanOrEqual(particle.x, -1)
            XCTAssertLessThanOrEqual(particle.x, 1)
            XCTAssertGreaterThanOrEqual(particle.y, -1)
            XCTAssertLessThanOrEqual(particle.y, 1)
            XCTAssertGreaterThan(particle.mass, 0)
            XCTAssertGreaterThanOrEqual(particle.temperature, 0)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter ParticleSeedTests
```

Expected: FAIL with missing `ParticleSeed`.

- [ ] **Step 3: Implement particle seed model**

Add `Sources/MusicVizCore/Simulation/ParticleSeed.swift`:

```swift
import Foundation

public struct SeedParticle: Equatable, Sendable {
    public var x: Float
    public var y: Float
    public var vx: Float
    public var vy: Float
    public var mass: Float
    public var temperature: Float
    public var age: Float
    public var kind: UInt32
}

public enum ParticleKind: UInt32, Sendable {
    case dust = 0
    case plasma = 1
    case protostar = 2
    case star = 3
    case unstableStar = 4
    case remnant = 5
    case ejecta = 6
}

public enum ParticleSeed {
    public static func generate(count: Int, seed: UInt64) -> [SeedParticle] {
        var rng = SeededRandom(seed: seed)
        return (0..<count).map { index in
            let radius = sqrt(rng.nextFloat()) * 0.92
            let angle = rng.nextFloat() * Float.pi * 2
            let swirl = Float(index % 17) / 17.0
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            return SeedParticle(
                x: x,
                y: y,
                vx: -y * 0.006 + rng.nextSignedFloat() * 0.002 + swirl * 0.0004,
                vy: x * 0.006 + rng.nextSignedFloat() * 0.002 - swirl * 0.0004,
                mass: 0.4 + rng.nextFloat() * 1.6,
                temperature: rng.nextFloat() * 0.08,
                age: 0,
                kind: rng.nextFloat() > 0.82 ? ParticleKind.plasma.rawValue : ParticleKind.dust.rawValue
            )
        }
    }
}
```

- [ ] **Step 4: Add GPU particle storage wrapper**

Add `Sources/MusicVizCore/Metal/MetalParticleState.swift`:

```swift
import Metal

public final class MetalParticleState {
    public let count: Int
    public let buffer: MTLBuffer

    public init(device: MTLDevice, particles: [SeedParticle]) {
        self.count = particles.count
        let byteCount = max(1, particles.count) * MemoryLayout<SeedParticle>.stride
        guard let buffer = device.makeBuffer(bytes: particles, length: byteCount, options: [.storageModeShared]) else {
            fatalError("Unable to create particle buffer.")
        }
        self.buffer = buffer
    }
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter ParticleSeedTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/MusicVizCore/Simulation/ParticleSeed.swift Sources/MusicVizCore/Metal/MetalParticleState.swift Tests/MusicVizCoreTests/ParticleSeedTests.swift
git commit -m "feat: add deterministic particle seeding"
```

## Task 5: Shader Library And Particle Rendering

**Files:**
- Create: `Sources/MusicVizCore/Metal/ShaderLibrary.swift`
- Create: `Sources/MusicVizCore/Resources/Shaders/CosmicShaders.metal`
- Modify: `Sources/MusicVizCore/Metal/CosmicRenderer.swift`

- [ ] **Step 1: Add shader loader**

Add `Sources/MusicVizCore/Metal/ShaderLibrary.swift`:

```swift
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
```

- [ ] **Step 2: Add particle shaders**

Add `Sources/MusicVizCore/Resources/Shaders/CosmicShaders.metal`:

```metal
#include <metal_stdlib>
using namespace metal;

struct SeedParticle {
    float x;
    float y;
    float vx;
    float vy;
    float mass;
    float temperature;
    float age;
    uint kind;
};

struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
};

vertex VertexOut particle_vertex(
    uint vertexID [[vertex_id]],
    const device SeedParticle *particles [[buffer(0)]]
) {
    SeedParticle p = particles[vertexID];
    float heat = clamp(p.temperature, 0.0, 1.0);
    float kindGlow = clamp(float(p.kind) / 6.0, 0.0, 1.0);

    VertexOut out;
    out.position = float4(p.x, p.y, 0.0, 1.0);
    out.pointSize = clamp(1.5 + p.mass * 1.4 + heat * 4.0, 1.0, 9.0);
    out.color = float4(
        0.25 + heat * 0.75 + kindGlow * 0.15,
        0.35 + heat * 0.45,
        0.65 + (1.0 - heat) * 0.30,
        0.72
    );
    return out;
}

fragment float4 particle_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}
```

- [ ] **Step 3: Modify renderer to draw seeded particles**

Update `CosmicRenderer` to:

- Create a `MetalParticleState` with `ParticleSeed.generate(count: 250_000, seed: 1)`.
- Create a render pipeline using `particle_vertex` and `particle_fragment`.
- Draw with `drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleState.count)`.

Use this pipeline setup:

```swift
let library = try ShaderLibrary.makeLibrary(device: device)
let descriptor = MTLRenderPipelineDescriptor()
descriptor.vertexFunction = library.makeFunction(name: "particle_vertex")
descriptor.fragmentFunction = library.makeFunction(name: "particle_fragment")
descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
descriptor.colorAttachments[0].isBlendingEnabled = true
descriptor.colorAttachments[0].rgbBlendOperation = .add
descriptor.colorAttachments[0].alphaBlendOperation = .add
descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
let particlePipeline = try device.makeRenderPipelineState(descriptor: descriptor)
```

Use this render encoder body:

```swift
encoder.setRenderPipelineState(particlePipeline)
encoder.setVertexBuffer(particleState.buffer, offset: 0, index: 0)
encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleState.count)
```

- [ ] **Step 4: Build and run**

Run:

```bash
make app
open .build/MusicViz.app
```

Expected: The window shows a dense seeded particle universe over a dark background.

- [ ] **Step 5: Run tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/MusicVizCore/Metal Sources/MusicVizCore/Resources/Shaders
git commit -m "feat: render seeded cosmic particles"
```

## Task 6: Field State, Decay, And Compute Dispatch

**Files:**
- Create: `Sources/MusicVizCore/Metal/MetalFieldState.swift`
- Modify: `Sources/MusicVizCore/Resources/Shaders/CosmicShaders.metal`
- Modify: `Sources/MusicVizCore/Metal/CosmicRenderer.swift`

- [ ] **Step 1: Add field state**

Add `Sources/MusicVizCore/Metal/MetalFieldState.swift`:

```swift
import Metal

public final class MetalFieldState {
    public let resolution: Int
    public let density: MTLTexture
    public let heat: MTLTexture

    public init(device: MTLDevice, resolution: Int) {
        self.resolution = resolution
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: resolution,
            height: resolution,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .private

        guard let density = device.makeTexture(descriptor: descriptor),
              let heat = device.makeTexture(descriptor: descriptor) else {
            fatalError("Unable to allocate field textures.")
        }
        self.density = density
        self.heat = heat
    }
}
```

- [ ] **Step 2: Add compute parameters and decay kernel**

Append to `CosmicShaders.metal`:

```metal
struct SimParams {
    float deltaTime;
    float timeScale;
    float audioInfluence;
    float gravityStrength;
    float heatDecay;
    float turbulenceStrength;
    float starIgnitionThreshold;
    float collapseThreshold;
    uint particleCount;
    uint fieldResolution;
};

kernel void decay_fields(
    texture2d<half, access::read_write> density [[texture(0)]],
    texture2d<half, access::read_write> heat [[texture(1)]],
    constant SimParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= params.fieldResolution || gid.y >= params.fieldResolution) {
        return;
    }

    half4 d = density.read(gid);
    half4 h = heat.read(gid);
    density.write(d * half4(0.992), gid);
    heat.write(h * half4(params.heatDecay), gid);
}
```

- [ ] **Step 3: Dispatch compute pass before rendering**

In `CosmicRenderer`, create:

```swift
private var fieldState: MetalFieldState
private var decayFieldsPipeline: MTLComputePipelineState
```

Initialize:

```swift
self.fieldState = MetalFieldState(device: device, resolution: 512)
guard let decayFunction = library.makeFunction(name: "decay_fields") else {
    throw RendererError.missingShaderFunction("decay_fields")
}
self.decayFieldsPipeline = try device.makeComputePipelineState(function: decayFunction)
```

Add `RendererError.missingShaderFunction(String)`.

Before the render encoder, dispatch:

```swift
var params = GPUSimParams(
    deltaTime: 1.0 / 120.0,
    timeScale: 1.0,
    audioInfluence: 1.0,
    gravityStrength: 1.0,
    heatDecay: 0.985,
    turbulenceStrength: 0.35,
    starIgnitionThreshold: 0.72,
    collapseThreshold: 0.92,
    particleCount: UInt32(particleState.count),
    fieldResolution: UInt32(fieldState.resolution)
)

if let compute = commandBuffer.makeComputeCommandEncoder() {
    compute.setComputePipelineState(decayFieldsPipeline)
    compute.setTexture(fieldState.density, index: 0)
    compute.setTexture(fieldState.heat, index: 1)
    compute.setBytes(&params, length: MemoryLayout<GPUSimParams>.stride, index: 0)
    let threads = MTLSize(width: 16, height: 16, depth: 1)
    let groups = MTLSize(
        width: (fieldState.resolution + 15) / 16,
        height: (fieldState.resolution + 15) / 16,
        depth: 1
    )
    compute.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
    compute.endEncoding()
}
```

Create `GPUSimParams` in Swift with fields matching the Metal struct order.

- [ ] **Step 4: Build and run**

Run:

```bash
make app
open .build/MusicViz.app
```

Expected: The app still renders particles and does not log Metal validation errors.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/MusicVizCore/Metal Sources/MusicVizCore/Resources/Shaders/CosmicShaders.metal
git commit -m "feat: add GPU field state and decay pass"
```

## Task 7: Particle Deposit And Motion Through Fields

**Files:**
- Modify: `Sources/MusicVizCore/Resources/Shaders/CosmicShaders.metal`
- Modify: `Sources/MusicVizCore/Metal/CosmicRenderer.swift`

- [ ] **Step 1: Add particle integration kernel**

Append to `CosmicShaders.metal`:

```metal
kernel void integrate_particles(
    device SeedParticle *particles [[buffer(0)]],
    constant SimParams &params [[buffer(1)]],
    texture2d<half, access::read_write> density [[texture(0)]],
    texture2d<half, access::read_write> heat [[texture(1)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= params.particleCount) {
        return;
    }

    SeedParticle p = particles[id];
    float2 pos = float2(p.x, p.y);
    float2 uv = clamp(pos * 0.5 + 0.5, 0.0, 0.999);
    uint2 cell = uint2(uv * float(params.fieldResolution));

    half4 oldDensity = density.read(cell);
    half4 oldHeat = heat.read(cell);
    float massDeposit = clamp(p.mass * 0.0008, 0.0, 0.02);
    float heatDeposit = clamp(p.temperature * 0.002, 0.0, 0.03);
    density.write(oldDensity + half4(massDeposit, 0.0, 0.0, 1.0), cell);
    heat.write(oldHeat + half4(heatDeposit, heatDeposit * 0.35, 0.0, 1.0), cell);

    float centerPull = 0.004 * params.gravityStrength;
    float2 acceleration = -pos * centerPull;
    acceleration += float2(
        sin((pos.y + p.age) * 19.0),
        cos((pos.x - p.age) * 17.0)
    ) * params.turbulenceStrength * 0.0004;

    float dt = params.deltaTime * params.timeScale;
    p.vx += acceleration.x * dt;
    p.vy += acceleration.y * dt;
    p.x += p.vx * dt * 60.0;
    p.y += p.vy * dt * 60.0;
    p.age += dt;
    p.temperature = clamp(p.temperature * 0.999 + length(acceleration) * 0.35, 0.0, 3.0);

    if (length(float2(p.x, p.y)) > 1.08) {
        p.x *= -0.86;
        p.y *= -0.86;
        p.vx *= -0.35;
        p.vy *= -0.35;
    }

    particles[id] = p;
}
```

- [ ] **Step 2: Dispatch integration before render**

In `CosmicRenderer`, create an `integrateParticlesPipeline` from `integrate_particles`.

Dispatch:

```swift
if let compute = commandBuffer.makeComputeCommandEncoder() {
    compute.setComputePipelineState(integrateParticlesPipeline)
    compute.setBuffer(particleState.buffer, offset: 0, index: 0)
    compute.setBytes(&params, length: MemoryLayout<GPUSimParams>.stride, index: 1)
    compute.setTexture(fieldState.density, index: 0)
    compute.setTexture(fieldState.heat, index: 1)
    let threads = MTLSize(width: 256, height: 1, depth: 1)
    let groups = MTLSize(width: (particleState.count + 255) / 256, height: 1, depth: 1)
    compute.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
    compute.endEncoding()
}
```

- [ ] **Step 3: Build and run**

Run:

```bash
make app
open .build/MusicViz.app
```

Expected: Particles drift, swirl, and remain bounded inside the visible universe.

- [ ] **Step 4: Commit**

Run:

```bash
git add Sources/MusicVizCore/Metal/CosmicRenderer.swift Sources/MusicVizCore/Resources/Shaders/CosmicShaders.metal
git commit -m "feat: move particles through GPU fields"
```

## Task 8: Lifecycle Rules

**Files:**
- Create: `Sources/MusicVizCore/Simulation/LifecycleRules.swift`
- Create: `Tests/MusicVizCoreTests/LifecycleRulesTests.swift`
- Modify: `Sources/MusicVizCore/Resources/Shaders/CosmicShaders.metal`

- [ ] **Step 1: Write failing lifecycle tests**

Add `Tests/MusicVizCoreTests/LifecycleRulesTests.swift`:

```swift
import XCTest
@testable import MusicVizCore

final class LifecycleRulesTests: XCTestCase {
    func testDenseHotDustBecomesProtostar() {
        let input = LifecycleSample(kind: .dust, mass: 2.0, temperature: 0.9, age: 4, localDensity: 0.95)
        XCTAssertEqual(LifecycleRules.nextKind(input, parameters: .init()), .protostar)
    }

    func testOldHotProtostarBecomesStar() {
        let input = LifecycleSample(kind: .protostar, mass: 2.5, temperature: 1.1, age: 12, localDensity: 1.0)
        XCTAssertEqual(LifecycleRules.nextKind(input, parameters: .init()), .star)
    }

    func testVeryHotMassiveStarBecomesUnstable() {
        let input = LifecycleSample(kind: .star, mass: 3.2, temperature: 2.3, age: 55, localDensity: 1.4)
        XCTAssertEqual(LifecycleRules.nextKind(input, parameters: .init()), .unstableStar)
    }

    func testUnstableStarCollapsesToRemnant() {
        let input = LifecycleSample(kind: .unstableStar, mass: 3.6, temperature: 2.6, age: 70, localDensity: 1.7)
        XCTAssertEqual(LifecycleRules.nextKind(input, parameters: .init()), .remnant)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter LifecycleRulesTests
```

Expected: FAIL with missing lifecycle types.

- [ ] **Step 3: Implement Swift lifecycle rules**

Add `Sources/MusicVizCore/Simulation/LifecycleRules.swift`:

```swift
import Foundation

public struct LifecycleSample: Equatable, Sendable {
    public var kind: ParticleKind
    public var mass: Float
    public var temperature: Float
    public var age: Float
    public var localDensity: Float

    public init(kind: ParticleKind, mass: Float, temperature: Float, age: Float, localDensity: Float) {
        self.kind = kind
        self.mass = mass
        self.temperature = temperature
        self.age = age
        self.localDensity = localDensity
    }
}

public enum LifecycleRules {
    public static func nextKind(_ sample: LifecycleSample, parameters: SimulationParameters) -> ParticleKind {
        switch sample.kind {
        case .dust, .plasma:
            if sample.localDensity >= parameters.starIgnitionThreshold,
               sample.temperature >= 0.55,
               sample.mass >= 1.2 {
                return .protostar
            }
            return sample.kind
        case .protostar:
            if sample.temperature >= 0.9 && sample.age >= 8 {
                return .star
            }
            return .protostar
        case .star:
            if sample.temperature >= 2.0 && sample.mass >= 2.8 && sample.age >= 40 {
                return .unstableStar
            }
            return .star
        case .unstableStar:
            if sample.localDensity >= parameters.collapseThreshold || sample.temperature >= 2.4 {
                return .remnant
            }
            return .unstableStar
        case .remnant, .ejecta:
            return sample.kind
        }
    }
}
```

- [ ] **Step 4: Mirror the same lifecycle thresholds in Metal**

Inside `integrate_particles`, after temperature update, read density and update `p.kind`:

```metal
float localDensity = float(density.read(cell).r);

if ((p.kind == 0 || p.kind == 1) &&
    localDensity >= params.starIgnitionThreshold &&
    p.temperature >= 0.55 &&
    p.mass >= 1.2) {
    p.kind = 2;
}

if (p.kind == 2 && p.temperature >= 0.9 && p.age >= 8.0) {
    p.kind = 3;
}

if (p.kind == 3 && p.temperature >= 2.0 && p.mass >= 2.8 && p.age >= 40.0) {
    p.kind = 4;
}

if (p.kind == 4 && (localDensity >= params.collapseThreshold || p.temperature >= 2.4)) {
    p.kind = 5;
    p.mass *= 1.25;
    p.temperature = 0.65;
}
```

- [ ] **Step 5: Run tests and app**

Run:

```bash
swift test --filter LifecycleRulesTests
make app
open .build/MusicViz.app
```

Expected: Tests pass. The app shows color and size changes as particles heat and age.

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/MusicVizCore/Simulation/LifecycleRules.swift Tests/MusicVizCoreTests/LifecycleRulesTests.swift Sources/MusicVizCore/Resources/Shaders/CosmicShaders.metal
git commit -m "feat: add first cosmic lifecycle rules"
```

## Task 9: Audio Analyzer

**Files:**
- Create: `Sources/MusicVizCore/Audio/AudioAnalyzer.swift`
- Create: `Tests/MusicVizCoreTests/AudioAnalyzerTests.swift`

- [ ] **Step 1: Write failing analyzer tests**

Add `Tests/MusicVizCoreTests/AudioAnalyzerTests.swift`:

```swift
import XCTest
@testable import MusicVizCore

final class AudioAnalyzerTests: XCTestCase {
    func testSilenceReturnsSilentFeatures() {
        var analyzer = AudioAnalyzer(sampleRate: 48_000)
        let features = analyzer.analyze(Array(repeating: 0, count: 2048))
        XCTAssertTrue(features.isSilent)
        XCTAssertEqual(features.overallEnergy, 0, accuracy: 0.0001)
    }

    func testImpulseProducesTransient() {
        var samples = Array(repeating: Float(0), count: 2048)
        samples[128] = 1

        var analyzer = AudioAnalyzer(sampleRate: 48_000)
        _ = analyzer.analyze(Array(repeating: 0, count: 2048))
        let features = analyzer.analyze(samples)

        XCTAssertFalse(features.isSilent)
        XCTAssertGreaterThan(features.transient, 0.2)
        XCTAssertGreaterThan(features.overallEnergy, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter AudioAnalyzerTests
```

Expected: FAIL with missing `AudioAnalyzer`.

- [ ] **Step 3: Implement analyzer**

Add `Sources/MusicVizCore/Audio/AudioAnalyzer.swift`:

```swift
import Accelerate
import Foundation

public struct AudioAnalyzer: Sendable {
    private let sampleRate: Float
    private var previousEnergy: Float = 0
    private var sustained: Float = 0

    public init(sampleRate: Float) {
        self.sampleRate = sampleRate
    }

    public mutating func analyze(_ monoSamples: [Float]) -> AudioFeatures {
        guard monoSamples.isEmpty == false else {
            return .silence
        }

        var squares = [Float](repeating: 0, count: monoSamples.count)
        vDSP_vsq(monoSamples, 1, &squares, 1, vDSP_Length(monoSamples.count))
        var meanSquare: Float = 0
        vDSP_meanv(squares, 1, &meanSquare, vDSP_Length(squares.count))
        let rms = sqrt(meanSquare)
        let energy = min(rms * 8, 1)
        sustained = sustained * 0.92 + energy * 0.08
        let transient = max(0, energy - previousEnergy) * 3.0
        previousEnergy = energy

        let third = max(1, monoSamples.count / 3)
        let bass = bandEnergy(Array(monoSamples[0..<third]))
        let mid = bandEnergy(Array(monoSamples[third..<(third * 2)]))
        let high = bandEnergy(Array(monoSamples[(third * 2)..<monoSamples.count]))
        let brightness = min(1, high / max(0.0001, bass + mid + high))

        return AudioFeatures(
            overallEnergy: energy,
            bass: min(bass * 8, 1),
            lowMid: min((bass + mid) * 4, 1),
            mid: min(mid * 8, 1),
            high: min(high * 8, 1),
            transient: min(transient, 1),
            brightness: brightness,
            sustainedIntensity: sustained,
            isSilent: energy < 0.01
        )
    }

    private func bandEnergy(_ samples: [Float]) -> Float {
        guard samples.isEmpty == false else { return 0 }
        var squares = [Float](repeating: 0, count: samples.count)
        vDSP_vsq(samples, 1, &squares, 1, vDSP_Length(samples.count))
        var mean: Float = 0
        vDSP_meanv(squares, 1, &mean, vDSP_Length(squares.count))
        return sqrt(mean)
    }
}
```

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter AudioAnalyzerTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/MusicVizCore/Audio/AudioAnalyzer.swift Tests/MusicVizCoreTests/AudioAnalyzerTests.swift
git commit -m "feat: add local audio analyzer"
```

## Task 10: Audio Force Mapping

**Files:**
- Create: `Sources/MusicVizCore/Simulation/AudioInjection.swift`
- Create: `Sources/MusicVizCore/Audio/AudioForceMapper.swift`
- Create: `Tests/MusicVizCoreTests/AudioForceMapperTests.swift`

- [ ] **Step 1: Write failing mapping tests**

Add `Tests/MusicVizCoreTests/AudioForceMapperTests.swift`:

```swift
import XCTest
@testable import MusicVizCore

final class AudioForceMapperTests: XCTestCase {
    func testSilenceCreatesSimmerInjection() {
        let injection = AudioForceMapper.map(.silence, parameters: .init())
        XCTAssertLessThan(injection.timeScaleMultiplier, 1)
        XCTAssertEqual(injection.shockwaveStrength, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(injection.coolingBias, 0)
    }

    func testBassAndTransientCreateShockwave() {
        let features = AudioFeatures(
            overallEnergy: 0.8,
            bass: 0.9,
            lowMid: 0.4,
            mid: 0.2,
            high: 0.1,
            transient: 0.7,
            brightness: 0.2,
            sustainedIntensity: 0.8,
            isSilent: false
        )
        let injection = AudioForceMapper.map(features, parameters: .init(audioInfluence: 1.5))
        XCTAssertGreaterThan(injection.shockwaveStrength, 0.8)
        XCTAssertGreaterThan(injection.compressionStrength, 0.9)
        XCTAssertGreaterThan(injection.heatInput, 0.5)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter AudioForceMapperTests
```

Expected: FAIL with missing mapper and injection.

- [ ] **Step 3: Implement mapping**

Add `Sources/MusicVizCore/Simulation/AudioInjection.swift`:

```swift
import Foundation

public struct AudioInjection: Equatable, Sendable {
    public var timeScaleMultiplier: Float
    public var compressionStrength: Float
    public var shockwaveStrength: Float
    public var heatInput: Float
    public var turbulenceInput: Float
    public var radiationInput: Float
    public var coolingBias: Float
}
```

Add `Sources/MusicVizCore/Audio/AudioForceMapper.swift`:

```swift
import Foundation

public enum AudioForceMapper {
    public static func map(_ features: AudioFeatures, parameters: SimulationParameters) -> AudioInjection {
        let influence = parameters.audioInfluence
        if features.isSilent {
            return AudioInjection(
                timeScaleMultiplier: 0.18,
                compressionStrength: 0,
                shockwaveStrength: 0,
                heatInput: 0,
                turbulenceInput: 0.03,
                radiationInput: 0,
                coolingBias: 0.18
            )
        }

        return AudioInjection(
            timeScaleMultiplier: 0.65 + features.sustainedIntensity * 1.6,
            compressionStrength: features.bass * influence,
            shockwaveStrength: features.bass * features.transient * influence,
            heatInput: features.sustainedIntensity * influence,
            turbulenceInput: (features.mid + features.high * 0.6) * influence,
            radiationInput: (features.high + features.brightness * 0.5) * influence,
            coolingBias: max(0, 0.08 - features.overallEnergy * 0.08)
        )
    }
}
```

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter AudioForceMapperTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/MusicVizCore/Simulation/AudioInjection.swift Sources/MusicVizCore/Audio/AudioForceMapper.swift Tests/MusicVizCoreTests/AudioForceMapperTests.swift
git commit -m "feat: map audio features to cosmic forces"
```

## Task 11: Audio Input Abstraction And System Tap

**Files:**
- Create: `Sources/MusicVizCore/Audio/AudioInputSource.swift`
- Create: `Sources/MusicVizCore/Audio/SyntheticAudioSource.swift`
- Create: `Sources/MusicVizCore/Audio/SystemAudioTap.swift`
- Modify: `Sources/MusicVizCore/App/AppState.swift`

- [ ] **Step 1: Add source protocol and synthetic fallback**

Add `Sources/MusicVizCore/Audio/AudioInputSource.swift`:

```swift
import Foundation

public protocol AudioInputSource: AnyObject {
    var latestFeatures: AudioFeatures { get }
    var statusText: String { get }
    var isUsingFallback: Bool { get }
    func start()
    func stop()
}
```

Add `Sources/MusicVizCore/Audio/SyntheticAudioSource.swift`:

```swift
import Foundation

public final class SyntheticAudioSource: AudioInputSource {
    private var startTime = Date()

    public init() {}

    public var latestFeatures: AudioFeatures {
        let t = Float(Date().timeIntervalSince(startTime))
        let pulse = (sin(t * 2.1) + 1) * 0.5
        return AudioFeatures(
            overallEnergy: pulse * 0.35,
            bass: pulse * 0.45,
            lowMid: pulse * 0.25,
            mid: 0.15,
            high: 0.08,
            transient: pulse > 0.92 ? 0.7 : 0,
            brightness: 0.2,
            sustainedIntensity: pulse * 0.3,
            isSilent: false
        )
    }

    public var statusText: String {
        "Synthetic audio"
    }

    public var isUsingFallback: Bool {
        true
    }

    public func start() {
        startTime = Date()
    }

    public func stop() {}
}
```

- [ ] **Step 2: Add Core Audio system output tap**

Add `Sources/MusicVizCore/Audio/SystemAudioTap.swift`:

```swift
import CoreAudio
import Foundation

public final class SystemAudioTap: AudioInputSource {
    private let ioQueue = DispatchQueue(label: "dev.maxisloud.musicviz.audio-tap")
    private let lock = NSLock()
    private var analyzer = AudioAnalyzer(sampleRate: 48_000)
    private var tap: AudioHardwareTap?
    private var aggregateDevice: AudioHardwareAggregateDevice?
    private var ioProcID: AudioDeviceIOProcID?
    private var features = AudioFeatures.silence
    private var status = "System audio idle"
    private var fallback = false

    public init() {}

    public var latestFeatures: AudioFeatures {
        lock.lock()
        defer { lock.unlock() }
        return features
    }

    public var statusText: String {
        lock.lock()
        defer { lock.unlock() }
        return status
    }

    public var isUsingFallback: Bool {
        lock.lock()
        defer { lock.unlock() }
        return fallback
    }

    public func start() {
        stop()

        do {
            let description = CATapDescription(monoGlobalTapButExcludeProcesses: [])
            description.name = "MusicViz System Output Tap"
            description.isPrivate = true
            description.muteBehavior = .unmuted

            guard let tap = try AudioHardwareSystem.shared.makeProcessTap(description: description) else {
                throw SystemAudioTapError.tapCreationReturnedNil
            }

            let format = try tap.format
            guard format.mFormatID == kAudioFormatLinearPCM else {
                throw SystemAudioTapError.unsupportedFormat("Expected linear PCM.")
            }
            guard (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0 else {
                throw SystemAudioTapError.unsupportedFormat("Expected floating-point PCM.")
            }

            self.analyzer = AudioAnalyzer(sampleRate: Float(format.mSampleRate))
            self.tap = tap

            let aggregateUID = "dev.maxisloud.musicviz.aggregate.\(UUID().uuidString)"
            let tapUID = try tap.uid
            let aggregateDescription: [String: Any] = [
                kAudioAggregateDeviceNameKey: "MusicViz Audio Capture",
                kAudioAggregateDeviceUIDKey: aggregateUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceTapListKey: [
                    [kAudioSubTapUIDKey: tapUID]
                ]
            ]

            guard let aggregate = try AudioHardwareSystem.shared.makeAggregateDevice(description: aggregateDescription) else {
                throw SystemAudioTapError.aggregateCreationReturnedNil
            }
            self.aggregateDevice = aggregate

            var createdIOProcID: AudioDeviceIOProcID?
            let createStatus = AudioDeviceCreateIOProcIDWithBlock(
                &createdIOProcID,
                aggregate.id,
                ioQueue
            ) { [weak self] _, inputData, _, _, _ in
                guard let self, let inputData else { return }
                let samples = Self.copyFloatSamples(from: inputData)
                guard samples.isEmpty == false else { return }

                var localAnalyzer = self.analyzer
                let analyzed = localAnalyzer.analyze(samples)

                self.lock.lock()
                self.analyzer = localAnalyzer
                self.features = analyzed
                self.status = "System audio active"
                self.fallback = false
                self.lock.unlock()
            }
            try Self.throwIfNeeded(createStatus, "AudioDeviceCreateIOProcIDWithBlock")

            guard let createdIOProcID else {
                throw SystemAudioTapError.ioProcCreationReturnedNil
            }
            self.ioProcID = createdIOProcID

            let startStatus = AudioDeviceStart(aggregate.id, createdIOProcID)
            try Self.throwIfNeeded(startStatus, "AudioDeviceStart")

            lock.lock()
            features = .silence
            status = "System audio waiting for output"
            fallback = false
            lock.unlock()
        } catch {
            lock.lock()
            features = .silence
            status = "System audio unavailable: \(error.localizedDescription)"
            fallback = true
            lock.unlock()
        }
    }

    public func stop() {
        if let aggregateDevice, let ioProcID {
            _ = AudioDeviceStop(aggregateDevice.id, ioProcID)
            _ = AudioDeviceDestroyIOProcID(aggregateDevice.id, ioProcID)
        }
        if let aggregateDevice {
            try? AudioHardwareSystem.shared.destroyAggregateDevice(aggregateDevice)
        }
        if let tap {
            try? AudioHardwareSystem.shared.destroyProcessTap(tap)
        }

        ioProcID = nil
        aggregateDevice = nil
        tap = nil

        lock.lock()
        status = "System audio stopped"
        features = .silence
        lock.unlock()
    }

    private static func copyFloatSamples(from audioBufferList: UnsafePointer<AudioBufferList>) -> [Float] {
        let buffers = UnsafeAudioBufferListPointer(audioBufferList)
        var samples: [Float] = []

        for buffer in buffers {
            guard let data = buffer.mData else { continue }
            let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride
            let pointer = data.bindMemory(to: Float.self, capacity: count)
            samples.append(contentsOf: UnsafeBufferPointer(start: pointer, count: count))
        }

        return samples
    }

    private static func throwIfNeeded(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw SystemAudioTapError.coreAudioFailure(operation: operation, status: status)
        }
    }
}

public enum SystemAudioTapError: LocalizedError {
    case tapCreationReturnedNil
    case aggregateCreationReturnedNil
    case ioProcCreationReturnedNil
    case unsupportedFormat(String)
    case coreAudioFailure(operation: String, status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .tapCreationReturnedNil:
            return "Core Audio returned no process tap."
        case .aggregateCreationReturnedNil:
            return "Core Audio returned no aggregate device for the tap."
        case .ioProcCreationReturnedNil:
            return "Core Audio returned no IOProc for the aggregate device."
        case .unsupportedFormat(let message):
            return message
        case .coreAudioFailure(let operation, let status):
            return "\(operation) failed with OSStatus \(status)."
        }
    }
}
```

- [ ] **Step 3: Verify source selection helper compiles**

Create this helper in `SystemAudioTap.swift` so the app can select real system audio and fall back cleanly:

```swift
public enum AudioSourceFactory {
    public static func makeDefaultSource() -> AudioInputSource {
        let systemTap = SystemAudioTap()
        systemTap.start()
        if systemTap.isUsingFallback {
            let fallback = SyntheticAudioSource()
            fallback.start()
            return fallback
        }
        return systemTap
    }
}
```

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 4: Build and run with real system audio**

Run:

```bash
make app
open .build/MusicViz.app
```

Expected:

- macOS prompts for audio capture permission the first time it is required.
- With Apple Music, Spotify, or browser audio playing, `SystemAudioTap.latestFeatures.overallEnergy` rises above silence.
- If permission is denied or the tap fails, the app stays usable with `SyntheticAudioSource`.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/MusicVizCore/Audio/AudioInputSource.swift Sources/MusicVizCore/Audio/SyntheticAudioSource.swift Sources/MusicVizCore/Audio/SystemAudioTap.swift
git commit -m "feat: capture system audio for analysis"
```

## Task 12: Audio Injection Into GPU Simulation

**Files:**
- Modify: `Sources/MusicVizCore/App/AppLauncher.swift`
- Modify: `Sources/MusicVizCore/App/MainWindowController.swift`
- Modify: `Sources/MusicVizCore/Metal/CosmicRenderer.swift`
- Modify: `Sources/MusicVizCore/Metal/MetalCanvasView.swift`
- Modify: `Sources/MusicVizCore/Resources/Shaders/CosmicShaders.metal`

- [ ] **Step 1: Extend GPU params with audio injection fields**

Add these fields to both Swift `GPUSimParams` and Metal `SimParams` in the same order:

```swift
var compressionStrength: Float
var shockwaveStrength: Float
var heatInput: Float
var turbulenceInput: Float
var radiationInput: Float
var coolingBias: Float
```

```metal
float compressionStrength;
float shockwaveStrength;
float heatInput;
float turbulenceInput;
float radiationInput;
float coolingBias;
```

- [ ] **Step 2: Apply audio injection in particle integration**

In `integrate_particles`, after `float2 acceleration = -pos * centerPull;`, add:

```metal
float radial = max(0.05, length(pos));
float2 inward = -normalize(pos + float2(0.0001, 0.0001));
float shockPhase = sin((radial * 18.0) - (p.age * 4.0));
acceleration += inward * params.compressionStrength * 0.002;
acceleration += normalize(pos + float2(0.0001, 0.0001)) * shockPhase * params.shockwaveStrength * 0.003;
p.temperature = clamp(p.temperature + params.heatInput * 0.0008 - params.coolingBias * 0.0006, 0.0, 3.0);
```

Replace the turbulence expression with:

```metal
float totalTurbulence = params.turbulenceStrength + params.turbulenceInput;
acceleration += float2(
    sin((pos.y + p.age) * 19.0),
    cos((pos.x - p.age) * 17.0)
) * totalTurbulence * 0.0004;
```

- [ ] **Step 3: Feed renderer with an audio source**

Change `CosmicRenderer` initializer to accept an `AudioInputSource`:

```swift
private let audioSource: AudioInputSource

public init(view: MTKView, audioSource: AudioInputSource) throws {
    self.audioSource = audioSource
}
```

Keep the existing device, queue, particle state, field state, shader library, render pipeline, and compute pipeline initialization from earlier tasks in the same initializer after `self.audioSource = audioSource`.

In each frame:

```swift
let clampedParameters = SimulationParameters().clamped()
let injection = AudioForceMapper.map(audioSource.latestFeatures, parameters: clampedParameters)
```

Apply `injection.timeScaleMultiplier` to `timeScale` and copy all injection values into `GPUSimParams`.

Change `MetalCanvasView` to accept and pass the source:

```swift
private let audioSource: AudioInputSource

public init(appState: AppState, audioSource: AudioInputSource) {
    self.audioSource = audioSource
    let renderer = try CosmicRenderer(view: self, audioSource: audioSource)
}
```

Keep the existing Metal device, pixel format, frame rate, resize, and delegate setup from Task 3 in the same initializer.

Change `MainWindowController` to accept the source:

```swift
private let audioSource: AudioInputSource

public init(appState: AppState, audioSource: AudioInputSource) {
    self.audioSource = audioSource
    let content = MetalCanvasView(appState: appState, audioSource: audioSource)
}
```

Keep the existing window creation and fullscreen collection behavior from Task 3 after the `content` assignment.

Change `BootstrapDelegate` to own the source strongly and pass it to the window:

```swift
@MainActor
private final class BootstrapDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?
    private var audioSource: AudioInputSource?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        let source = AudioSourceFactory.makeDefaultSource()
        self.audioSource = source
        state.statusText = source.statusText
        let controller = MainWindowController(appState: state, audioSource: source)
        self.windowController = controller
        controller.showWindow(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
```

- [ ] **Step 4: Build and run with system audio or fallback audio**

Run:

```bash
make app
open .build/MusicViz.app
```

Expected: System output audio creates visible pulses in particle temperature and motion. If macOS denies capture permission or the tap fails, fallback audio still creates visible pulses and the lab status reports the fallback.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/MusicVizCore/App/AppLauncher.swift Sources/MusicVizCore/App/MainWindowController.swift Sources/MusicVizCore/Metal/CosmicRenderer.swift Sources/MusicVizCore/Metal/MetalCanvasView.swift Sources/MusicVizCore/Resources/Shaders/CosmicShaders.metal
git commit -m "feat: inject audio forces into simulation"
```

## Task 13: Ambient UI And Lab Panel

**Files:**
- Create: `Sources/MusicVizCore/Lab/LabPanelView.swift`
- Modify: `Sources/MusicVizCore/App/MainWindowController.swift`
- Modify: `Sources/MusicVizCore/App/AppState.swift`

- [ ] **Step 1: Extend app state**

Update `AppState`:

```swift
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
```

- [ ] **Step 2: Add SwiftUI lab panel**

Add `Sources/MusicVizCore/Lab/LabPanelView.swift`:

```swift
import SwiftUI

public struct LabPanelView: View {
    @ObservedObject private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Simulation Lab")
                    .font(.headline)
                Spacer()
                Button("Hide") {
                    appState.isLabVisible = false
                }
            }

            Text(appState.statusText)
                .foregroundStyle(.secondary)

            Toggle("Paused", isOn: $appState.isPaused)
            slider("Time Scale", value: $appState.parameters.timeScale, range: 0.02...8.0)
            slider("Audio Influence", value: $appState.parameters.audioInfluence, range: 0.0...3.0)
            slider("Gravity", value: $appState.parameters.gravityStrength, range: 0.0...5.0)
            slider("Heat Decay", value: $appState.parameters.heatDecay, range: 0.80...0.999)
            slider("Turbulence", value: $appState.parameters.turbulenceStrength, range: 0.0...4.0)
            slider("Ignition", value: $appState.parameters.starIgnitionThreshold, range: 0.01...2.0)
            slider("Collapse", value: $appState.parameters.collapseThreshold, range: 0.01...4.0)
            slider("Render", value: $appState.parameters.renderIntensity, range: 0.0...5.0)
            slider("Bloom", value: $appState.parameters.bloomStrength, range: 0.0...3.0)

            Button("Reset Parameters") {
                appState.resetToDefaults()
            }
        }
        .padding(18)
        .frame(width: 340)
        .background(.regularMaterial)
    }

    private func slider(_ title: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title): \(value.wrappedValue, specifier: "%.2f")")
                .font(.caption)
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Float($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound)
            )
        }
    }
}
```

- [ ] **Step 3: Host panel over Metal view**

In `MainWindowController`, wrap the Metal view and lab panel in an `NSHostingView` backed by SwiftUI:

```swift
import SwiftUI

struct RootView: NSViewControllerRepresentable {
    let appState: AppState
    let audioSource: AudioInputSource

    func makeNSViewController(context: Context) -> NSViewController {
        let controller = NSViewController()
        controller.view = MetalCanvasView(appState: appState, audioSource: audioSource)
        return controller
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}

struct AppRootOverlay: View {
    @ObservedObject var appState: AppState
    let audioSource: AudioInputSource

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RootView(appState: appState, audioSource: audioSource)
                .ignoresSafeArea()
            if appState.isLabVisible {
                LabPanelView(appState: appState)
                    .padding(20)
            }
        }
    }
}
```

Set `window.contentView = NSHostingView(rootView: AppRootOverlay(appState: appState, audioSource: audioSource))`.

- [ ] **Step 4: Add keyboard toggle**

Add a local key monitor in `MainWindowController`:

```swift
private var keyMonitor: Any?

keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak appState] event in
    if event.charactersIgnoringModifiers == "l" {
        appState?.isLabVisible.toggle()
        return nil
    }
    if event.charactersIgnoringModifiers == " " {
        appState?.isPaused.toggle()
        return nil
    }
    return event
}
```

- [ ] **Step 5: Build and run**

Run:

```bash
make app
open .build/MusicViz.app
```

Expected: Press `l` to show or hide the lab panel. Press space to toggle pause state in the panel.

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/MusicVizCore/App Sources/MusicVizCore/Lab
git commit -m "feat: add ambient lab overlay"
```

## Task 14: Final Prototype Validation

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-06-25-cosmic-music-visualizer-design.md` only if implementation discovers a necessary design correction.

- [ ] **Step 1: Add README**

Add `README.md`:

```markdown
# MusicViz

Native macOS Tahoe 26+, Apple Silicon-only cosmic music visualizer.

MusicViz is a Swift + Metal experiment: a simulation-first 2D universe where
particles and fields evolve into clumps, protostars, stars, remnants, and
shockwaves. Audio analysis feeds energy into the simulation rather than playing
canned animations.

## Requirements

- macOS Tahoe 26 or newer
- Apple Silicon Mac
- Xcode 26 command line tools

## Build

```bash
make app
```

## Run

```bash
open .build/MusicViz.app
```

## Test

```bash
swift test
```

## Controls

- `l`: show or hide the simulation lab
- Space: pause or resume

## Audio

The first prototype uses a Core Audio system output tap so music from Apple
Music, Spotify, browser audio, or other players can drive the universe. If
permission is denied or the tap fails, the app falls back to a synthetic audio
source and keeps the simulation usable.
```

- [ ] **Step 2: Run full checks**

Run:

```bash
swift test
make app
```

Expected: Tests pass and `.build/MusicViz.app` is produced.

- [ ] **Step 3: Manual validation**

Run:

```bash
open .build/MusicViz.app
```

Verify:

- App opens as a native macOS window.
- Metal content is nonblank.
- Particles move continuously.
- System output audio produces visible pulses.
- Denying audio permission leaves the app usable through fallback audio.
- Pressing `l` shows and hides the lab.
- Lab sliders update values without crashing.
- Pressing space toggles pause state in the lab.

- [ ] **Step 4: Commit and push**

Run:

```bash
git add README.md
git commit -m "docs: add prototype build instructions"
git status --short
git push origin main
```

Expected: Working tree is clean and GitHub contains all prototype commits.

## Self-Review Checklist

- Spec coverage: This plan covers native Swift + Metal app shell, Apple Silicon-only Tahoe target, particle-field simulation, lifecycle rules, system output audio capture, audio analysis, audio-to-simulation mapping, ambient UI, lab controls, error fallback through synthetic audio, and build/test verification.
- Scope gaps: None for the approved first prototype scope.
- Placeholder scan: No task depends on undefined deferred work for the runnable prototype.
- Type consistency: `SimulationParameters`, `AudioFeatures`, `AudioInjection`, `SeedParticle`, `ParticleKind`, and `AppState` are introduced before use.
