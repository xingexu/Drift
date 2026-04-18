import SwiftUI
import AuthenticationServices

struct AuthView: View {
    var onBack: (() -> Void)? = nil
    var onSuccess: (() -> Void)? = nil
    @EnvironmentObject var appState: AppState

    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var appleSignInLoading = false
    @State private var googleSignInLoading = false
    @State private var googlePollTask: Task<Void, Never>?
    @State private var submitCooldown = false

    // Tab navigation focus management
    @FocusState private var focusedField: AuthField?

    enum AuthMode: String, CaseIterable {
        case login = "Sign In"
        case signup = "Sign Up"
    }

    enum AuthField: Hashable {
        case email
        case password
        case name
    }

    var body: some View {
        HStack(spacing: 0) {
            brandingPanel
            formPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Anim.quick, value: mode)
        .animation(Anim.quick, value: errorMessage != nil)
        .animation(Anim.quick, value: successMessage != nil)
        .onChange(of: mode) { _, _ in
            errorMessage = nil
            successMessage = nil
            focusedField = .email
        }
        .onDisappear {
            googlePollTask?.cancel()
            googlePollTask = nil
        }
    }

    // MARK: - Left Panel: Branding

    private var brandingPanel: some View {
        ZStack(alignment: .topLeading) {
            Color.accent

            VStack(alignment: .leading, spacing: 0) {
                Image("DriftLogo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 48, height: 48)
                    .colorMultiply(.white)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.top, Space.xxxl + Space.lg)
                    .accessibilityLabel("Drift logo")

                Spacer().frame(height: Space.xxxl + Space.sm)

                Text("Focus better.\nWork smarter.")
                    .font(TypeScale.hero)
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .accessibilityAddTraits(.isHeader)

                Spacer().frame(height: Space.xxxl)

                VStack(alignment: .leading, spacing: Space.md + Space.xxxs) {
                    AuthFeatureBullet(text: "Automatic app tracking")
                    AuthFeatureBullet(text: "Real-time focus analytics")
                    AuthFeatureBullet(text: "Pomodoro focus timer")
                    AuthFeatureBullet(text: "Session history & streaks")
                    AuthFeatureBullet(text: "Website blocker with password lock")
                }

                Spacer()

                Text("drift.app")
                    .font(TypeScale.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, Space.xxxl + Space.lg)
            }
            .padding(.horizontal, Space.xxxl + Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Right Panel: Form

    private var formPanel: some View {
        ZStack(alignment: .topLeading) {
            Color(.windowBackgroundColor)

            VStack(spacing: 0) {
                backButton
                    .padding(.top, Space.xxl)
                    .padding(.horizontal, Space.xxxl)

                Spacer()

                formContent
                    .frame(maxWidth: 340)
                    .padding(.horizontal, Space.xxxl)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var backButton: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    HStack(spacing: Space.xxs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                            .font(TypeScale.body)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .driftButton(.ghost)
                .accessibilityLabel("Go back")
            }
            Spacer()
        }
    }

    private var formContent: some View {
        VStack(spacing: Space.xxl) {
            // Title + subtitle
            VStack(spacing: Space.sm) {
                Text(mode == .login ? "Welcome back" : "Create your account")
                    .font(TypeScale.title)
                    .accessibilityAddTraits(.isHeader)

                Text(mode == .login
                     ? "Sign in to sync your data across devices"
                     : "Get started with focus tracking")
                    .font(TypeScale.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Mode picker
            Picker("Authentication mode", selection: $mode) {
                ForEach(AuthMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .labelsHidden()

            // Social sign-in buttons
            socialButtons

            // Divider
            HStack(spacing: Space.md) {
                Rectangle()
                    .fill(Color.sep)
                    .frame(height: 1)
                Text("or")
                    .font(TypeScale.caption)
                    .foregroundStyle(.tertiary)
                    .layoutPriority(1)
                Rectangle()
                    .fill(Color.sep)
                    .frame(height: 1)
            }
            .accessibilityHidden(true)

            // Form fields
            formFields

            // Messages
            messageArea

            // Submit button
            submitButton

            // Skip option
            Button(action: {
                onSuccess?()
            }) {
                Text("Continue without account")
                    .font(TypeScale.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip sign in and continue without an account")
        }
    }

    // MARK: - Social Buttons

    private var socialButtons: some View {
        VStack(spacing: Space.md - 2) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                handleAppleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .disabled(isAnyLoading)
            .overlay {
                if appleSignInLoading {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(.black.opacity(0.6))
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }
            .accessibilityLabel("Sign in with Apple")

            AuthGoogleSignInButton(isLoading: googleSignInLoading, isDisabled: isAnyLoading) {
                handleGoogleSignIn()
            }
        }
    }

    // MARK: - Form Fields

    private var formFields: some View {
        VStack(spacing: Space.md + Space.xxxs) {
            AuthLabeledField(
                label: "Email",
                text: $email,
                placeholder: "you@example.com",
                keyboardType: .emailAddress,
                isDisabled: isAnyLoading
            )
            .focused($focusedField, equals: .email)
            .onSubmit { focusedField = .password }
            .accessibilityLabel("Email address")

            AuthLabeledSecureField(
                label: "Password",
                text: $password,
                placeholder: "Minimum 8 characters",
                isDisabled: isAnyLoading
            )
            .focused($focusedField, equals: .password)
            .onSubmit {
                if mode == .signup {
                    focusedField = .name
                } else if canSubmit {
                    handleSubmit()
                }
            }
            .accessibilityLabel("Password, minimum 8 characters")

            if mode == .signup {
                AuthLabeledField(
                    label: "Name",
                    text: $name,
                    placeholder: "Your name",
                    isDisabled: isAnyLoading
                )
                .focused($focusedField, equals: .name)
                .onSubmit {
                    if canSubmit { handleSubmit() }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityLabel("Your display name")
            }
        }
    }

    // MARK: - Messages

    @ViewBuilder private var messageArea: some View {
        if let error = errorMessage {
            HStack(spacing: Space.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(TypeScale.caption)
                Text(error)
                    .font(TypeScale.caption)
            }
            .foregroundStyle(Color.distraction)
            .padding(Space.md - 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.distraction.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityLabel("Error: \(error)")
        } else if let success = successMessage {
            HStack(spacing: Space.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(TypeScale.caption)
                Text(success)
                    .font(TypeScale.caption)
            }
            .foregroundStyle(Color.productive)
            .padding(Space.md - 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.productive.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityLabel("Success: \(success)")
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button(action: handleSubmit) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Text(mode == .login ? "Sign In" : "Create Account")
                }
            }
            .font(TypeScale.body)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(canSubmit ? Color.accent : Color.accent.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .driftButton()
        .disabled(!canSubmit)
        .keyboardShortcut(.return, modifiers: [.command])
        .accessibilityLabel(mode == .login ? "Sign in" : "Create account")
        .accessibilityHint(canSubmit ? "Double tap to submit" : submitDisabledReason)
    }

    // MARK: - Validation Logic

    private var isAnyLoading: Bool {
        isLoading || appleSignInLoading || googleSignInLoading
    }

    private var canSubmit: Bool {
        !isAnyLoading && !submitCooldown && isValidEmail(email) && isValidPassword(password)
    }

    private var submitDisabledReason: String {
        if isAnyLoading { return "Loading, please wait" }
        if submitCooldown { return "Please wait before trying again" }
        if email.isEmpty { return "Enter your email address" }
        if !isValidEmail(email) { return "Enter a valid email address" }
        if password.isEmpty { return "Enter your password" }
        if !isValidPassword(password) { return "Password must be at least 8 characters" }
        return ""
    }

    private func isValidEmail(_ email: String) -> Bool {
        guard !email.isEmpty else { return false }
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
    }

    // MARK: - Submit Handler

    private func handleSubmit() {
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard isValidPassword(password) else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                if mode == .signup {
                    let response = try await APIClient.shared.signup(
                        email: email, password: password, name: name.isEmpty ? nil : name
                    )
                    await MainActor.run {
                        successMessage = response.message
                        isLoading = false
                    }
                } else {
                    let response = try await APIClient.shared.login(email: email, password: password)
                    await MainActor.run {
                        appState.saveTokens(access: response.accessToken, refresh: response.refreshToken)
                        appState.saveUser(User(
                            userId: response.user.userId,
                            email: response.user.email,
                            name: response.user.name,
                            plan: response.user.plan
                        ))
                        isLoading = false
                        onSuccess?()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = sanitizedErrorMessage(from: error)
                    isLoading = false
                    applySubmitCooldown()
                }
            }
        }
    }

    private func applySubmitCooldown() {
        submitCooldown = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            submitCooldown = false
        }
    }

    private func sanitizedErrorMessage(from error: Error) -> String {
        let message = error.localizedDescription
        if message.lowercased().contains("token") || message.lowercased().contains("bearer") {
            return "Authentication failed. Please try again."
        }
        return message
    }

    // MARK: - Apple Sign-In

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "Could not process Apple sign-in response."
                return
            }

            let fullName: String? = {
                if let nameComponents = credential.fullName {
                    let parts = [nameComponents.givenName, nameComponents.familyName].compactMap { $0 }
                    return parts.isEmpty ? nil : parts.joined(separator: " ")
                }
                return nil
            }()

            let userEmail = credential.email

            appleSignInLoading = true
            errorMessage = nil

            Task {
                do {
                    let response = try await APIClient.shared.appleSignIn(
                        identityToken: identityToken,
                        name: fullName,
                        email: userEmail
                    )
                    await MainActor.run {
                        appState.saveTokens(access: response.accessToken, refresh: response.refreshToken)
                        appState.saveUser(User(
                            userId: response.user.userId,
                            email: response.user.email,
                            name: response.user.name,
                            plan: response.user.plan
                        ))
                        appleSignInLoading = false
                        onSuccess?()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = sanitizedErrorMessage(from: error)
                        appleSignInLoading = false
                    }
                }
            }

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = "Apple sign-in failed. Please try again."
        }
    }

    // MARK: - Google Sign-In

    private func handleGoogleSignIn() {
        googleSignInLoading = true
        errorMessage = nil

        googlePollTask?.cancel()
        googlePollTask = nil

        Task {
            do {
                let oauthURL = try await APIClient.shared.getGoogleOAuthURL()

                await MainActor.run {
                    if let url = URL(string: oauthURL.url) {
                        NSWorkspace.shared.open(url)
                    }
                    googleSignInLoading = false
                    successMessage = "Complete sign-in in your browser. The app will update automatically."
                }

                await startCancellableAuthPoll()
            } catch {
                await MainActor.run {
                    errorMessage = "Google sign-in is being configured. Use email/password or Apple sign-in for now."
                    googleSignInLoading = false
                }
            }
        }
    }

    private func startCancellableAuthPoll() async {
        googlePollTask?.cancel()

        googlePollTask = Task { @MainActor in
            for _ in 0..<30 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }

                if let token = appState.accessToken, !token.isEmpty {
                    onSuccess?()
                    return
                }
            }

            if !Task.isCancelled {
                errorMessage = "Sign-in timed out. Please try again."
                successMessage = nil
            }
        }
    }
}

// MARK: - Feature Bullet

private struct AuthFeatureBullet: View {
    let text: String

    var body: some View {
        HStack(spacing: Space.md - 2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
            Text(text)
                .font(TypeScale.heading)
        }
        .foregroundStyle(.white.opacity(0.7))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Google Sign-In Button

private struct AuthGoogleSignInButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md - 2) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                    Text("G")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .yellow, .green, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                Text("Continue with Google")
                    .font(TypeScale.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.primary.opacity(0.04))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(Color.sep.opacity(0.3), lineWidth: 1)
            )
        }
        .driftButton(.secondary)
        .disabled(isDisabled)
        .overlay {
            if isLoading {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(Color(.windowBackgroundColor).opacity(0.7))
                ProgressView()
                    .controlSize(.small)
            }
        }
        .accessibilityLabel("Continue with Google")
    }
}

// MARK: - Field Components

struct AuthLabeledField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: NSTextContentType? = nil
    var isDisabled: Bool = false
    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(label)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(TypeScale.body)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.6 : 1)
                .accessibilityLabel(label)
        }
    }
}

struct AuthLabeledSecureField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var isDisabled: Bool = false
    @State private var showPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(label)
                .font(TypeScale.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            HStack(spacing: Space.xxs) {
                Group {
                    if showPassword {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(TypeScale.body)

                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .font(TypeScale.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
            }
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.6 : 1)
            .accessibilityLabel(label)
        }
    }
}

// MARK: - Backwards-compatible aliases

typealias LabeledField = AuthLabeledField
typealias LabeledSecureField = AuthLabeledSecureField
