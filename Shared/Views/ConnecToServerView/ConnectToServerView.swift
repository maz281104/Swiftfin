//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import SwiftUI

struct ConnectToServerView: View {

    @Default(.accentColor)
    private var accentColor

    @FocusState
    private var isURLFocused: Bool

    @Router
    private var router

    @StateObject
    private var viewModel = ConnectToServerViewModel()

    @State
    private var duplicateServer: ServerState? = nil
    @State
    private var isPresentingDuplicateServer: Bool = false
    @State
    private var url: String = MarkhorConfiguration.jellyfinServerURL.absoluteString

    private let timer = Timer.publish(every: 12, on: .main, in: .common).autoconnect()

    private func onEvent(_ event: ConnectToServerViewModel._Event) {
        switch event {
        case let .connected(server):
            UIDevice.feedback(.success)
            Notifications[.didConnectToServer].post(server)
            router.dismiss()
        case let .duplicateServer(server):
            UIDevice.feedback(.warning)
            duplicateServer = server
            isPresentingDuplicateServer = true
        }
    }

    @ViewBuilder
    private var connectSection: some View {
        Section("Markhor IPTV Media Server") {
            Text(MarkhorConfiguration.jellyfinServerURL.absoluteString)
                .foregroundStyle(.secondary)
        }

        if viewModel.state == .connecting {
            ListRowButton(L10n.cancel, role: .cancel) {
                viewModel.cancel()
            }
            .frame(maxHeight: 75)
        } else {
            ListRowButton(L10n.connect) {
                isURLFocused = false
                viewModel.connect(url: url)
            }
            .frame(maxHeight: 75)
            .disabled(url.isEmpty)
            .foregroundStyle(
                accentColor.overlayColor,
                accentColor
            )
            .opacity(url.isEmpty ? 0.5 : 1)
        }
    }

    // MARK: - Local Servers Section

    @ViewBuilder
    private var localServersSection: some View {
        Section(L10n.localServers) {
            if viewModel.localServers.isEmpty {
                Text(L10n.noLocalServersFound)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.localServers) { server in
                    LocalServerButton(server: server) {
                        url = server.currentURL.absoluteString
                        viewModel.connect(url: server.currentURL.absoluteString)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        #if os(iOS)
        List {
            connectSection
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarCloseButton(disabled: viewModel.state == .connecting) {
            router.dismiss()
        }
        #else
        SplitLoginWindowView(
            isLoading: viewModel.state == .connecting
        ) {
            connectSection
        } trailingContentView: {
            VStack(spacing: 18) {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(MarkhorTheme.accent)

                Text(MarkhorConfiguration.appName)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        #endif
    }

    // MARK: - Body

    var body: some View {
        contentView
            .navigationTitle(MarkhorConfiguration.appName)
            .interactiveDismissDisabled(viewModel.state == .connecting)
            .onFirstAppear {
                if viewModel.state != .connecting {
                    viewModel.connect(url: MarkhorConfiguration.jellyfinServerURL.absoluteString)
                }
            }
            .onReceive(viewModel.events, perform: onEvent)
            .onReceive(viewModel.$error) { error in
                guard error != nil else { return }
                UIDevice.feedback(.error)
                isURLFocused = true
            }
            .topBarTrailing {
                if viewModel.state == .connecting {
                    ProgressView()
                }
            }
            .alert(
                Text(L10n.server),
                isPresented: $isPresentingDuplicateServer,
                presenting: duplicateServer
            ) { server in
                Button(L10n.dismiss, role: .destructive)

                Button(L10n.addURL) {
                    viewModel.addNewURL(serverState: server)
                    router.dismiss()
                }
            } message: { server in
                Text(L10n.serverAlreadyExistsPrompt(server.name))
            }
            .errorMessage($viewModel.error)
    }
}
