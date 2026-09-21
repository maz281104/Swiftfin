//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v2.0.
//

import SwiftUI

struct MarkhorRootView: View {

    private enum Route {
        case home
        case liveTV
        case movies
        case series
        case jellyfin
        case settings
    }

    @StateObject
    private var xcSession = MarkhorXCSession()

    @State
    private var route: Route = .home

    var body: some View {
        Group {
            if !xcSession.isSignedIn {
                MarkhorXCLoginView(session: xcSession)
            } else {
                switch route {
                case .home:
                    MarkhorHomeView(
                        accountName: xcSession.accountName,
                        accountExpiry: xcSession.accountExpiry,
                        onModule: { module in
                            switch module {
                            case .liveTV:
                                route = .liveTV
                            case .movies:
                                route = .movies
                            case .series:
                                route = .series
                            case .jellyfin:
                                route = .jellyfin
                            case .settings:
                                route = .settings
                            }
                        },
                        onSignOut: {
                            xcSession.signOut()
                            route = .home
                        }
                    )

                case .jellyfin:
                    MarkhorEmbeddedSwiftfinView(title: "Jellyfin") {
                        route = .home
                    }

                case .movies:
                    MarkhorEmbeddedSwiftfinView(title: "Movies") {
                        route = .home
                    }

                case .series:
                    MarkhorEmbeddedSwiftfinView(title: "Series") {
                        route = .home
                    }

                case .liveTV:
                    MarkhorModulePlaceholderView(
                        title: "Live TV",
                        message: "XC Live TV module",
                        onBack: { route = .home }
                    )

                case .settings:
                    MarkhorModulePlaceholderView(
                        title: "Settings",
                        message: "Markhor IPTV Apple settings",
                        onBack: { route = .home }
                    )
                }
            }
        }
        .background(MarkhorTheme.background.ignoresSafeArea())
    }
}

private struct MarkhorEmbeddedSwiftfinView: View {

    let title: String
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RootView()

            Button(action: onBack) {
                Label("Markhor Home", systemImage: "chevron.left")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(MarkhorTheme.panel)
            .padding()
        }
    }
}

private struct MarkhorXCLoginView: View {

    @ObservedObject
    var session: MarkhorXCSession

    @State
    private var username = ""
    @State
    private var password = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    MarkhorTheme.background,
                    Color(red: 9 / 255, green: 38 / 255, blue: 27 / 255),
                    .black,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Image("markhor-app-icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)

                    Text("MARKHOR IPTV")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(MarkhorTheme.accent)

                    Text("Sign in to Markhor IPTV")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(spacing: 14) {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .markhorInput()

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .markhorInput()

                        Button {
                            session.signIn(username: username, password: password)
                        } label: {
                            HStack {
                                if session.isBusy {
                                    ProgressView()
                                }

                                Text(session.isBusy ? "Connecting..." : "Sign In")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MarkhorTheme.success)
                        .disabled(session.isBusy || username.isEmpty || password.isEmpty)

                        if !session.errorMessage.isEmpty {
                            Text(session.errorMessage)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(32)
                .frame(maxWidth: 620)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(MarkhorTheme.panel.opacity(0.93))
                        .stroke(MarkhorTheme.accent.opacity(0.35), lineWidth: 1)
                )
                .padding(30)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private enum MarkhorHomeModule: CaseIterable {
    case liveTV
    case movies
    case series
    case jellyfin
    case settings

    var title: String {
        switch self {
        case .liveTV: "Live TV"
        case .movies: "Movies"
        case .series: "Series"
        case .jellyfin: "Jellyfin"
        case .settings: "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .liveTV: "Watch live channels"
        case .movies: "Browse your movie library"
        case .series: "Continue your favourite shows"
        case .jellyfin: "Open the full Jellyfin experience"
        case .settings: "Manage app preferences"
        }
    }

    var symbol: String {
        switch self {
        case .liveTV: "play.tv"
        case .movies: "film"
        case .series: "rectangle.stack.badge.play"
        case .jellyfin: "play.circle"
        case .settings: "gearshape"
        }
    }
}

private struct MarkhorHomeView: View {

    let accountName: String
    let accountExpiry: String
    let onModule: (MarkhorHomeModule) -> Void
    let onSignOut: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 330), spacing: 16),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    MarkhorTheme.background,
                    Color(red: 9 / 255, green: 38 / 255, blue: 27 / 255),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    Image("markhor-app-icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 118, height: 118)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(MarkhorHomeModule.allCases, id: \.title) { module in
                            Button {
                                onModule(module)
                            } label: {
                                HStack(spacing: 18) {
                                    Image(systemName: module.symbol)
                                        .font(.system(size: 32, weight: .semibold))
                                        .foregroundStyle(MarkhorTheme.accent)
                                        .frame(width: 48)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(module.title)
                                            .font(.headline)
                                            .foregroundStyle(.white)

                                        Text(module.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, minHeight: 112)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(MarkhorTheme.panel.opacity(0.9))
                                        .stroke(MarkhorTheme.accent.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(spacing: 8) {
                        Text("Account: \(accountName)")
                        Text("Expiry: \(accountExpiry)")
                            .foregroundStyle(MarkhorTheme.accent)

                        Button("Sign Out", action: onSignOut)
                            .buttonStyle(.bordered)
                    }
                    .font(.callout)
                }
                .padding(30)
            }
        }
    }
}

private struct MarkhorModulePlaceholderView: View {

    let title: String
    let message: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Button(action: onBack) {
                Label("Home", systemImage: "chevron.left")
            }

            Spacer()

            Image(systemName: "play.tv.fill")
                .font(.system(size: 72))
                .foregroundStyle(MarkhorTheme.accent)

            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(message)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MarkhorTheme.background)
    }
}

private extension View {

    func markhorInput() -> some View {
        padding(.horizontal, 15)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.95))
            )
            .foregroundStyle(Color.black)
    }
}
