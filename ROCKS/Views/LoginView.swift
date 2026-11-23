import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: AuthViewModel
    @State private var showingRegistration = false
    @State private var showingPasswordReset = false
    @State private var showsPassword = false

    init(authService: any AuthService) {
        _viewModel = State(initialValue: AuthViewModel(authService: authService))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    logoHeader

                    if let authenticationError = appState.authenticationError {
                        Text(authenticationError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Authentication error: \(authenticationError)")
                    }

                    credentialFields

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }

                    signInButton

                    secondaryActions
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(ROCKSColor.background)
            .tint(ROCKSColor.goldText)
            .sheet(isPresented: $showingRegistration) {
                RegistrationView(authService: appState.authService) { user in
                    appState.authenticate(user)
                    showingRegistration = false
                }
            }
            .sheet(isPresented: $showingPasswordReset) {
                PasswordResetRequestView(authService: appState.authService, email: viewModel.email)
            }
        }
    }

    /// Large, centered emblem followed by the welcome copy. The logo scales
    /// with its container but is capped so controls stay visible on smaller
    /// iPhones without overlapping.
    private var logoHeader: some View {
        VStack(spacing: 14) {
            Image("rocksLogo")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 230)
                .frame(minHeight: 150)
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(ROCKSColor.gold.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 6)
                .padding(.horizontal, 36)
                .accessibilityLabel("The ROCKS, Inc. emblem")

            VStack(spacing: 6) {
                Text("Shaping Talent Through Mentorship")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ROCKSColor.primaryText)
                    .multilineTextAlignment(.center)
                Text("Sign in to access your ROCKS community.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 28)
    }

    private var credentialFields: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $viewModel.email, prompt: Text("Email").foregroundColor(ROCKSColor.subtleText))
                .foregroundStyle(ROCKSColor.primaryText)
                .tint(ROCKSColor.goldText)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
                .accessibilityLabel("Email")

            HStack {
                Group {
                    if showsPassword {
                        TextField("Password", text: $viewModel.password)
                    } else {
                        SecureField("Password", text: $viewModel.password)
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                Button {
                    showsPassword.toggle()
                } label: {
                    Image(systemName: showsPassword ? "eye.slash" : "eye")
                }
                .accessibilityLabel(showsPassword ? "Hide password" : "Show password")
            }
                .foregroundStyle(ROCKSColor.primaryText)
                .tint(ROCKSColor.goldText)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
        }
    }

    private var signInButton: some View {
        Button {
            Task {
                if let user = await viewModel.signIn() {
                    appState.authenticate(user)
                }
            }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(ROCKSColor.black)
                } else {
                    Text("Sign In")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(ROCKSColor.black)
            .background(ROCKSColor.gold)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(viewModel.isLoading)
        .accessibilityLabel(viewModel.isLoading ? "Signing in" : "Sign In")
    }

    private var secondaryActions: some View {
        VStack(spacing: 14) {
            Button("Create an Account") { showingRegistration = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ROCKSColor.goldText)
                .frame(minHeight: 44)

            Button("Forgot Password?") { showingPasswordReset = true }
            .font(.subheadline)
            .foregroundStyle(ROCKSColor.subtleText)
            .frame(minHeight: 44)
            .disabled(viewModel.isLoading)
        }
    }
}

struct RegistrationView: View {
    let authService: any AuthService
    let onAuthenticated: (AuthUser) -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AuthViewModel
    @State private var chapters: [Chapter] = []
    @State private var chapterLoadFailed = false
    @State private var confirmationEmail: String?
    @State private var presentedLink: IdentifiableURL?

    init(authService: any AuthService, onAuthenticated: @escaping (AuthUser) -> Void) {
        self.authService = authService
        self.onAuthenticated = onAuthenticated
        _viewModel = State(initialValue: AuthViewModel(authService: authService))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let confirmationEmail {
                    confirmationSent(email: confirmationEmail)
                } else {
                    form
                }
            }
            .navigationTitle("Join The ROCKS")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(confirmationEmail == nil ? "Cancel" : "Done") { dismiss() }
                }
            }
            .task { await loadChapters() }
            .officialLinkSheet($presentedLink)
        }
    }

    private var form: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Image("rocksLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 110)
                        .accessibilityLabel("The ROCKS, Inc. emblem")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section("Create your account") {
                TextField("First name", text: $viewModel.firstName)
                    .textContentType(.givenName)
                TextField("Last name", text: $viewModel.lastName)
                    .textContentType(.familyName)
                TextField("Email", text: $viewModel.email, prompt: Text("Email").foregroundColor(ROCKSColor.subtleText))
                    .foregroundStyle(ROCKSColor.primaryText)
                    .tint(ROCKSColor.goldText)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                SecureField("Password", text: $viewModel.password, prompt: Text("Password").foregroundColor(ROCKSColor.subtleText))
                    .foregroundStyle(ROCKSColor.primaryText)
                    .tint(ROCKSColor.goldText)
                    .textContentType(.newPassword)
                SecureField("Confirm password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
            }
            Section {
                Picker("Chapter", selection: $viewModel.requestedChapterID) {
                    Text("Not sure yet").tag(UUID?.none)
                    ForEach(chapters) { chapter in
                        Text(chapter.name).tag(UUID?.some(chapter.id))
                    }
                }
                .tint(ROCKSColor.goldText)
            } header: {
                Text("Chapter")
            } footer: {
                Text(chapterLoadFailed
                    ? "Chapters could not be loaded. You can continue and an administrator will assign your chapter."
                    : "Your chapter is confirmed by an administrator when your membership is approved.")
            }
            Section {
                Toggle(isOn: $viewModel.acceptedAcknowledgment) {
                    Text("I confirm this information is accurate and agree that The ROCKS, Inc. may use it to review my membership and operate ROCKS Connect.")
                        .font(.footnote)
                }
                .tint(ROCKSColor.gold)
                if let terms = appState.environment.configuration.termsURL {
                    Link("Terms of Use", destination: terms).foregroundStyle(ROCKSColor.goldText)
                }
                if let privacy = appState.environment.configuration.privacyPolicyURL {
                    Link("Privacy Policy", destination: privacy).foregroundStyle(ROCKSColor.goldText)
                }
            } footer: {
                Text("Creating an account does not grant membership. A ROCKS administrator reviews every application.")
            }
            Section {
                Button {
                    presentedLink = IdentifiableURL(url: OfficialLinks.joinMembership)
                } label: {
                    Label("Not a ROCKS member yet? Join on rocksinc.org", systemImage: "arrow.up.right.square")
                        .foregroundStyle(ROCKSColor.goldText)
                }
                .accessibilityHint("Opens the official new member sign-up and dues page")
            }
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }
            Button {
                Task {
                    switch await viewModel.signUp() {
                    case .confirmationRequired(let email):
                        confirmationEmail = email
                    case .signedIn(let user):
                        onAuthenticated(user)
                    case nil:
                        break
                    }
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text("Create Account")
                }
            }
            .disabled(viewModel.isLoading)
        }
    }

    private func confirmationSent(email: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 48))
                .foregroundStyle(ROCKSColor.goldText)
                .accessibilityHidden(true)
            Text("Check your email")
                .font(.title2.weight(.bold))
            Text("If \(email) can be used to register, we sent a confirmation link. Open it on this device, then sign in. Your membership will be reviewed by an administrator.")
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.subtleText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ROCKSColor.background)
    }

    private func loadChapters() async {
        guard chapters.isEmpty else { return }
        do {
            chapters = try await appState.environment.chapterRepository.fetchChapters()
            chapterLoadFailed = false
        } catch {
            chapterLoadFailed = true
        }
    }
}

private struct PasswordResetRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AuthViewModel
    @State private var sent = false

    init(authService: any AuthService, email: String) {
        let model = AuthViewModel(authService: authService)
        model.email = email
        _viewModel = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Text("If an account exists for that address, password reset instructions will be sent. Open the link on this device.")
                } else {
                    Section("Password recovery") {
                        TextField("Email address", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    if let message = viewModel.errorMessage {
                        Text(message).foregroundStyle(.red)
                    }
                    Button {
                        Task { sent = await viewModel.requestPasswordReset() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Send reset instructions")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationTitle("Forgot Password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
    }
}

struct PasswordRecoveryView: View {
    @Environment(AppState.self) private var appState
    let state: PasswordRecoveryState
    @State private var password = ""
    @State private var confirmation = ""
    @State private var validationError: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                switch state {
                case .opening:
                    ProgressView("Opening recovery link")
                case .ready:
                    Section("Choose a new password") {
                        SecureField("New password", text: $password)
                            .textContentType(.newPassword)
                        SecureField("Confirm new password", text: $confirmation)
                            .textContentType(.newPassword)
                    }
                    if let message = validationError ?? appState.passwordRecoveryError {
                        Text(message).foregroundStyle(.red)
                    }
                    Button("Update Password") { updatePassword() }
                        .disabled(isLoading)
                    Button("Cancel") { closeRecovery() }
                        .disabled(isLoading)
                case .updated:
                    Text("Your password was updated. Return to Sign In to continue.")
                    if let message = appState.passwordRecoveryError {
                        Text(message).foregroundStyle(.red)
                    }
                    Button("Return to Sign In") { closeRecovery() }
                        .disabled(isLoading)
                case .failed(let message):
                    Text(message).foregroundStyle(.red)
                    if let error = appState.passwordRecoveryError {
                        Text(error).foregroundStyle(.red)
                    }
                    Button("Return") { closeRecovery() }
                        .disabled(isLoading)
                }
                if isLoading { ProgressView() }
            }
            .navigationTitle("Password Recovery")
        }
    }

    private func updatePassword() {
        guard password.count >= 8 else {
            validationError = "Use at least 8 characters for your password."
            return
        }
        guard password == confirmation else {
            validationError = "Passwords do not match."
            return
        }
        validationError = nil
        isLoading = true
        Task {
            await appState.updateRecoveredPassword(password)
            isLoading = false
        }
    }

    private func closeRecovery() {
        isLoading = true
        Task {
            await appState.closePasswordRecovery()
            isLoading = false
        }
    }
}
