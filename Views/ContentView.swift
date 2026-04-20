import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WorkoutViewModel()

    var body: some View {
        Group {
            switch viewModel.sessionManager.state {
            case .login:
                LoginView {
                    viewModel.continuePastLogin()
                }

            case .home:
                SessionSelectionView(
                    routines: viewModel.availableRoutines,
                    appVersion: viewModel.appVersionText,
                    startRoutine: { routine in
                        viewModel.startRoutine(routine)
                    }
                )

            case .active, .transitioning, .quitting, .completed:
                GuidedSessionView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
