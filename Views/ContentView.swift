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
        Group {
            switch viewModel.sessionManager.state {
            case .idle:
                SessionSelectionView(
                    routines: viewModel.availableRoutines,
                    startRoutine: { routine in
                        viewModel.startRoutine(routine)
                    }
                )

            case .active, .transitioning, .completed:
                GuidedSessionView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
