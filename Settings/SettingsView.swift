import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Binding var selectedModel: PoseModelVariant

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Multi-person tracking", isOn: $settings.multiPersonTrackingEnabled)
                    Toggle("Show person HUDs", isOn: $settings.showPersonHUDs)
                    Toggle("Show person IDs", isOn: $settings.showPersonIDs)
                    Toggle("Highlight tentative tracks", isOn: $settings.highlightTentativeTracks)

                    Stepper(value: $settings.maxVisiblePeople, in: 1...8) {
                        Text("Max visible people: \(settings.maxVisiblePeople)")
                    }
                } header: {
                    Text("Tracking")
                } footer: {
                    Text("Highlight tentative tracks only changes how unstable tracks are emphasized visually. When it is on, newly stabilizing tracks are easier to spot.")
                }

                Section {
                    Toggle("Audio cues", isOn: $settings.audioCuesEnabled)
                } header: {
                    Text("Audio")
                } footer: {
                    Text("Plays a positive system sound when a person becomes valid and when a rep is completed. Plays a sharper negative cue if tracking quality drops out of the valid range.")
                }

                Section {
                    Toggle("Face-assisted recognition", isOn: $settings.faceAssistedRecognitionEnabled)

                    Text("Face-assisted recognition is currently experimental and is off by default.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Recognition")
                }

                Section {
                    Picker("Pose model", selection: $selectedModel) {
                        ForEach(PoseModelVariant.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Model")
                } footer: {
                    Text("Lite is fastest. Full and Heavy may improve tracking quality, but can reduce performance.")
                }

                Section {
                    Text("People are only counted when their full-body pose confidence is strong enough. Skeleton color ranges from red to green to indicate whether reps can be tracked.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(
        settings: AppSettings(),
        selectedModel: .constant(.lite)
    )
}
