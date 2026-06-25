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
