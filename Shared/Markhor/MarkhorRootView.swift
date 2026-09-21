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
                    MarkhorMediaLibraryView(
                        section: .movies,
                        onBack: { route = .home }
                    )

                case .series:
                    MarkhorMediaLibraryView(
                        section: .series,
                        onBack: { route = .home }
                    )

                case .liveTV:
                    if let credentials = xcSession.credentials {
                        MarkhorLiveTVView(
                            credentials: credentials,
                            onBack: { route = .home }
                        )
                    } else {
                        MarkhorModulePlaceholderView(
                            title: "Live TV",
                            message: "Please sign in to Markhor IPTV again.",
                            onBack: { route = .home }
                        )
                    }

                case .settings:
                    MarkhorSettingsView(
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
            MarkhorBrandedBackground()

            ScrollView {
                VStack(spacing: 20) {
                    Image("markhor-header-emblem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)

                    Image("markhor-wordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 360)
                        .frame(height: 94)
                        .padding(.top, -10)

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
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
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
            MarkhorBrandedBackground()

            ScrollView {
                VStack(spacing: 26) {
                    VStack(spacing: 0) {
                        Image("markhor-header-emblem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 128, height: 128)

                        Image("markhor-wordmark")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300)
                            .frame(height: 76)
                            .padding(.top, -12)
                    }

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
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
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

private struct MarkhorBrandedBackground: View {

    var body: some View {
        GeometryReader { proxy in
            Image(
                proxy.size.height > proxy.size.width
                    ? "markhor-background-portrait"
                    : "markhor-background-landscape"
            )
            .resizable()
            .scaledToFill()
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.35),
                        MarkhorTheme.background.opacity(0.58),
                        Color.black.opacity(0.72),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .ignoresSafeArea()
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
