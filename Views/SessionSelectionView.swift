import SwiftUI

struct SessionSelectionView: View {
    let routines: [RehabRoutine]
    let startRoutine: (RehabRoutine) -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Fun Fitness PT")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Choose a guided session")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    ForEach(routines) { routine in
                        Button(action: {
                            startRoutine(routine)
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(routine.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Text("\(routine.exercises.count) exercises • 5 reps each")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .contentShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    SessionSelectionView(
        routines: [
            RehabRoutine(name: "Beta Shoulders 1.0", exercises: []),
            RehabRoutine(name: "Beta Mobility 1.0", exercises: []),
            RehabRoutine(name: "Beta Rotator Cuff 1.0", exercises: [])
        ],
        startRoutine: { _ in }
    )
}
