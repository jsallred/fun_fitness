//
//  ContentView.swift
//  fun_fitness
//
//  Created by Joseph Allred on 3/2/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WorkoutViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: viewModel.cameraService.session)
                .ignoresSafeArea()

            PoseOverlayView(frame: viewModel.snapshot.poseFrame)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                topBar
                Spacer()
                bottomCard
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Text("Fun Fitness")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Picker("Model", selection: $viewModel.selectedModel) {
                ForEach(PoseModelVariant.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            .scaleEffect(0.9)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            compactRow("Activity", viewModel.snapshot.activity.rawValue.capitalized)
            compactRow("Squats", "\(viewModel.snapshot.squatReps)")
            compactRow("Jacks", "\(viewModel.snapshot.jackReps)")
            compactRow("Knee", kneeText)
            compactRow("FPS", fpsText)
            compactRow("Model", viewModel.snapshot.model.displayName)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var kneeText: String {
        guard let angle = viewModel.snapshot.kneeAngle else { return "--" }
        return String(format: "%.0f°", angle)
    }
    
    private var fpsText: String {
        if viewModel.snapshot.inferenceFPS <= 0 {
            return "--"
        }
        return String(format: "%.1f", viewModel.snapshot.inferenceFPS)
    }

    private func compactRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.gray)

            Spacer()

            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    ContentView()
}
