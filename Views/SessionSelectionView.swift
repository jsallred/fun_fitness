import SwiftUI

struct SessionSelectionView: View {
    let routines: [RehabRoutine]
    let appVersion: String
    let startRoutine: (RehabRoutine) -> Void

    @State private var selectedRoutine: RehabRoutine?

    var body: some View {
        NavigationStack {
            ZStack {
                appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        ForEach(RehabBodyRegion.allCases) { region in
                            let regionRoutines = routines.filter { $0.bodyRegion == region }

                            if !regionRoutines.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text(region.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(.white.opacity(0.92))
                                        .padding(.horizontal, 4)

                                    ForEach(regionRoutines) { routine in
                                        Button {
                                            selectedRoutine = routine
                                        } label: {
                                            routineCard(for: routine)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedRoutine) { routine in
                RoutineDetailSheet(
                    routine: routine,
                    onStart: {
                        selectedRoutine = nil
                        startRoutine(routine)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var appBackground: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.06, green: 0.10, blue: 0.16),
                Color(red: 0.12, green: 0.18, blue: 0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Home Screen")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("App version \(appVersion)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

            Text("Choose a guided routine to preview the exercises and start a session.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.top, 2)
        }
    }

    private func routineCard(for routine: RehabRoutine) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(routine.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(routine.summary)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.84))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 4)
            }

            HStack(spacing: 10) {
                pill(text: routine.mode == .demo ? "Live demo" : "\(routine.exercises.count) exercises")

                if routine.mode == .guided {
                    pill(text: "~\(routine.estimatedMinutes) min")
                } else {
                    pill(text: "No goal")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: cardGradient(for: routine.bodyRegion),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.30), radius: 16, x: 0, y: 10)
    }

    private func pill(text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.14))
            .clipShape(Capsule())
    }

    private func cardGradient(for region: RehabBodyRegion) -> [Color] {
        switch region {
        case .demo:
            return [
                Color(red: 0.24, green: 0.14, blue: 0.44),
                Color(red: 0.34, green: 0.18, blue: 0.58),
                Color(red: 0.46, green: 0.26, blue: 0.72)
            ]
        case .shoulder:
            return [
                Color(red: 0.08, green: 0.18, blue: 0.36),
                Color(red: 0.14, green: 0.28, blue: 0.56),
                Color(red: 0.22, green: 0.38, blue: 0.68)
            ]
        case .hip:
            return [
                Color(red: 0.08, green: 0.24, blue: 0.34),
                Color(red: 0.12, green: 0.38, blue: 0.50),
                Color(red: 0.22, green: 0.52, blue: 0.62)
            ]
        case .kneeAnkle:
            return [
                Color(red: 0.14, green: 0.16, blue: 0.22),
                Color(red: 0.22, green: 0.26, blue: 0.34),
                Color(red: 0.32, green: 0.36, blue: 0.46)
            ]
        case .general:
            return [
                Color(red: 0.18, green: 0.18, blue: 0.22),
                Color(red: 0.28, green: 0.30, blue: 0.38),
                Color(red: 0.40, green: 0.42, blue: 0.50)
            ]
        }
    }
}

private struct RoutineDetailSheet: View {
    let routine: RehabRoutine
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                sheetBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        topSummaryCard

                        VStack(alignment: .leading, spacing: 12) {
                            Text(routine.mode == .demo ? "Live counters in this demo" : "Exercises in this routine")
                                .font(.headline)
                                .foregroundStyle(.white)

                            ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { index, exercise in
                                exerciseCard(index: index, exercise: exercise)
                            }
                        }

                        Button(action: onStart) {
                            HStack {
                                Spacer()
                                Text(routine.mode == .demo ? "Start Demo" : "Start Routine")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.blue,
                                        Color.indigo
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .blue.opacity(0.24), radius: 10, x: 0, y: 6)
                        }
                    }
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private var sheetBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.14),
                Color(red: 0.10, green: 0.14, blue: 0.22),
                Color(red: 0.14, green: 0.20, blue: 0.30)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var topSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(routine.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(routine.summary)
                .font(.body)
                .foregroundStyle(.white.opacity(0.82))

            HStack(spacing: 10) {
                detailPill(routine.bodyRegion.rawValue)
                detailPill(routine.mode == .demo ? "Live demo" : "\(routine.exercises.count) exercises")
                detailPill(routine.mode == .demo ? "No goal" : "~\(routine.estimatedMinutes) min")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: summaryCardGradient(for: routine.bodyRegion),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
    }

    private func exerciseCard(index: Int, exercise: RehabExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(index + 1). \(exercise.type.displayName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text(exercise.targetRepsText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }

            Text(exercise.type.instructions)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.84))
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: detailCardGradient(for: routine.bodyRegion),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailPill(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.14))
            .clipShape(Capsule())
    }

    private func summaryCardGradient(for region: RehabBodyRegion) -> [Color] {
        switch region {
        case .demo:
            return [
                Color(red: 0.22, green: 0.14, blue: 0.42),
                Color(red: 0.34, green: 0.18, blue: 0.62)
            ]
        case .shoulder:
            return [
                Color(red: 0.10, green: 0.22, blue: 0.42),
                Color(red: 0.18, green: 0.34, blue: 0.62)
            ]
        case .hip:
            return [
                Color(red: 0.08, green: 0.26, blue: 0.38),
                Color(red: 0.16, green: 0.42, blue: 0.56)
            ]
        case .kneeAnkle:
            return [
                Color(red: 0.18, green: 0.20, blue: 0.28),
                Color(red: 0.28, green: 0.32, blue: 0.42)
            ]
        case .general:
            return [
                Color(red: 0.20, green: 0.20, blue: 0.26),
                Color(red: 0.32, green: 0.34, blue: 0.42)
            ]
        }
    }

    private func detailCardGradient(for region: RehabBodyRegion) -> [Color] {
        switch region {
        case .demo:
            return [
                Color(red: 0.30, green: 0.18, blue: 0.52),
                Color(red: 0.42, green: 0.24, blue: 0.68)
            ]
        case .shoulder:
            return [
                Color(red: 0.16, green: 0.28, blue: 0.52),
                Color(red: 0.24, green: 0.40, blue: 0.70)
            ]
        case .hip:
            return [
                Color(red: 0.12, green: 0.34, blue: 0.46),
                Color(red: 0.22, green: 0.48, blue: 0.62)
            ]
        case .kneeAnkle:
            return [
                Color(red: 0.20, green: 0.22, blue: 0.30),
                Color(red: 0.34, green: 0.38, blue: 0.46)
            ]
        case .general:
            return [
                Color(red: 0.24, green: 0.24, blue: 0.30),
                Color(red: 0.36, green: 0.38, blue: 0.46)
            ]
        }
    }
}

private extension RehabExercise {
    var targetRepsText: String {
        if let targetReps {
            return "\(targetReps) reps"
        } else {
            return "Live counter"
        }
    }
}

#Preview {
    SessionSelectionView(
        routines: RehabRoutineLibrary.all,
        appVersion: "v1.0",
        startRoutine: { _ in }
    )
}
