//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v2.0.
//

import Factory
import SwiftUI

@MainActor
final class MarkhorAppleUpdateModel: ObservableObject {

    @Published private(set) var isChecking = false
    @Published private(set) var updateAvailable = false
    @Published private(set) var latestVersion = ""
    @Published private(set) var notes = ""
    @Published private(set) var destinationURL: URL?
    @Published var status = ""

    var currentVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0.0"
    }

    func check() {
        guard !isChecking else {
            return
        }

        isChecking = true
        status = "Checking for updates..."
        updateAvailable = false
        destinationURL = nil

        Task {
            defer {
                isChecking = false
            }

            do {
                var request = URLRequest(url: MarkhorConfiguration.updateFeedURL)
                request.timeoutInterval = 10
                request.cachePolicy = .reloadIgnoringLocalCacheData

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200 ... 299).contains(httpResponse.statusCode)
                else {
                    status = "Unable to check for updates."
                    return
                }

                let info = try JSONDecoder().decode(
                    MarkhorAppleUpdateInfo.self,
                    from: data
                )

                latestVersion = info.version
                notes = info.notes ?? ""
                destinationURL =
                    info.appStoreURL.flatMap(URL.init(string:))
                    ?? info.testFlightURL.flatMap(URL.init(string:))

                updateAvailable = Self.compare(
                    info.version,
                    isNewerThan: currentVersion
                )

                status = updateAvailable
                    ? "Markhor IPTV \(info.version) is available."
                    : "Markhor IPTV is up to date."
            } catch {
                status = "Unable to check for updates."
            }
        }
    }

    private static func compare(
        _ candidate: String,
        isNewerThan installed: String
    ) -> Bool {
        let left = candidate
            .split(separator: "-")
            .first?
            .split(separator: ".")
            .map { Int($0) ?? 0 } ?? []

        let right = installed
            .split(separator: "-")
            .first?
            .split(separator: ".")
            .map { Int($0) ?? 0 } ?? []

        let count = max(left.count, right.count)

        for index in 0 ..< count {
            let lhs = index < left.count ? left[index] : 0
            let rhs = index < right.count ? right[index] : 0

            if lhs != rhs {
                return lhs > rhs
            }
        }

        return false
    }
}

private struct MarkhorAppleUpdateInfo: Decodable {
    let version: String
    let notes: String?
    let appStoreURL: String?
    let testFlightURL: String?
}

struct MarkhorSettingsView: View {

    let onBack: () -> Void

    @AppStorage("markhor.apple.live.resumeLast")
    private var resumeLastLiveChannel = true

    @AppStorage("markhor.apple.live.aspectFill")
    private var liveAspectFill = false

    @AppStorage("markhor.apple.live.networkCachingMs")
    private var liveNetworkCachingMs = 1500

    @StateObject
    private var updateModel = MarkhorAppleUpdateModel()

    @State
    private var showAdvancedSettings = false

    private var hasJellyfinSession: Bool {
        Container.shared.currentUserSession() != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("PLAYER") {
                    Toggle(
                        "Fill screen for Live TV",
                        isOn: $liveAspectFill
                    )

                    Picker(
                        "Live TV network buffer",
                        selection: $liveNetworkCachingMs
                    ) {
                        Text("Auto").tag(1000)
                        Text("Large").tag(1500)
                        Text("Extra Large").tag(3000)
                    }
                }

                Section("LIVE TV") {
                    Toggle(
                        "Resume last Live TV channel",
                        isOn: $resumeLastLiveChannel
                    )
                }

                Section("JELLYFIN") {
                    Button("Advanced Player & Jellyfin Settings") {
                        showAdvancedSettings = true
                    }
                    .disabled(!hasJellyfinSession)

                    if !hasJellyfinSession {
                        Text("Sign in to Movies, Series, or Jellyfin first to open the advanced Jellyfin settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("APP UPDATE") {
                    LabeledContent(
                        "Current Version",
                        value: updateModel.currentVersion
                    )

                    Button {
                        updateModel.check()
                    } label: {
                        HStack {
                            if updateModel.isChecking {
                                ProgressView()
                            }

                            Text(
                                updateModel.isChecking
                                    ? "Checking..."
                                    : "Check for Update"
                            )
                        }
                    }
                    .disabled(updateModel.isChecking)

                    if !updateModel.status.isEmpty {
                        Text(updateModel.status)
                            .foregroundStyle(
                                updateModel.updateAvailable
                                    ? MarkhorTheme.accent
                                    : Color.gray
                            )
                    }

                    if updateModel.updateAvailable,
                       !updateModel.notes.isEmpty
                    {
                        Text(updateModel.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if updateModel.updateAvailable,
                       let destinationURL = updateModel.destinationURL
                    {
                        Link(
                            "Open Update",
                            destination: destinationURL
                        )
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onBack) {
                        Label("Home", systemImage: "chevron.left")
                    }
                }
            }
            .sheet(isPresented: $showAdvancedSettings) {
                NavigationInjectionView(coordinator: .init()) {
                    SettingsView()
                }
            }
        }
    }
}
