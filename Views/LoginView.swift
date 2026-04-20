import SwiftUI

struct LoginView: View {
    let continueAction: () -> Void

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.35),
                    Color.indigo.opacity(0.22),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)

                    Text("Fun Fitness PT")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Physical therapy movement coach")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        TextField("name@example.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        SecureField("Enter password", text: $password)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button("Login") { }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.18))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("Demo build: use Continue to enter the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
                .padding(.horizontal)

                Button(action: continueAction) {
                    HStack {
                        Text("Continue")
                            .fontWeight(.semibold)

                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)

                Spacer()

                Text("Beta")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .padding()
        }
    }
}

#Preview {
    LoginView { }
}
