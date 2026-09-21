//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v2.0.
//

import SwiftUI
import VLCUI

@MainActor
final class MarkhorLiveTVModel: ObservableObject {

    @Published private(set) var categories: [MarkhorLiveCategory] = []
    @Published private(set) var channels: [MarkhorLiveChannel] = []
    @Published private(set) var selectedCategory: MarkhorLiveCategory?
    @Published private(set) var selectedChannel: MarkhorLiveChannel?
    @Published private(set) var currentProgram: MarkhorEPGProgram?
    @Published private(set) var nextProgram: MarkhorEPGProgram?
    @Published private(set) var playbackURL: URL?
    @Published private(set) var playbackIdentity = UUID()
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published var isChannelMenuVisible = false
    @Published var isChannelOverlayVisible = false
    @Published var errorMessage = ""

    private let client: MarkhorXCClient
    private let defaultsKey: String

    private var candidateURLs: [URL] = []
    private var candidateIndex = 0
    private var fallbackTask: Task<Void, Never>?
    private var overlayTask: Task<Void, Never>?
    private var epgTask: Task<Void, Never>?
    private var receivedPlayingState = false
    private var hasRestoredLastChannel = false

    init(credentials: MarkhorXCCredentials) {
        client = MarkhorXCClient(credentials: credentials)
        defaultsKey = "markhor.apple.live.last.\(credentials.username)"
    }

    deinit {
        fallbackTask?.cancel()
        overlayTask?.cancel()
        epgTask?.cancel()
    }

    func start() {
        Task {
            await loadCategories()
        }
    }

    func loadCategories() async {
        isLoading = true
        errorMessage = ""

        do {
            let loaded = try await client.liveCategories()
            categories = loaded

            let shouldResume = UserDefaults.standard.object(
                forKey: "markhor.apple.live.resumeLast"
            ) as? Bool ?? true

            guard let first = (shouldResume ? restoredCategory(from: loaded) : nil) ?? loaded.first else {
                selectedCategory = nil
                channels = []
                errorMessage = "No Live TV categories are available."
                isLoading = false
                return
            }

            await selectCategory(first, restoreLastChannel: shouldResume)
        } catch let error as MarkhorLiveTVError {
            errorMessage = error.message
        } catch {
            errorMessage = "Unable to load Live TV categories."
        }

        isLoading = false
    }

    func selectCategory(
        _ category: MarkhorLiveCategory,
        restoreLastChannel: Bool = false
    ) async {
        selectedCategory = category
        channels = []
        errorMessage = ""
        isLoading = true

        do {
            let loaded = try await client.liveChannels(categoryID: category.id)
            channels = loaded

            if restoreLastChannel,
               !hasRestoredLastChannel,
               let channel = restoredChannel(from: loaded, categoryID: category.id)
            {
                hasRestoredLastChannel = true
                play(channel)
            } else if restoreLastChannel {
                hasRestoredLastChannel = true
            }
        } catch let error as MarkhorLiveTVError {
            errorMessage = error.message
        } catch {
            errorMessage = "Unable to load Live TV channels."
        }

        isLoading = false
    }

    func play(_ channel: MarkhorLiveChannel) {
        guard let category = selectedCategory else {
            return
        }

        selectedChannel = channel
        currentProgram = nil
        nextProgram = nil
        errorMessage = ""
        isChannelMenuVisible = false
        isPlaying = true

        candidateURLs = client.streamCandidates(
            channel: channel,
            categoryName: category.name
        )
        candidateIndex = 0

        guard !candidateURLs.isEmpty else {
            isPlaying = false
            errorMessage = "Unable to create a playback URL for this channel."
            return
        }

        saveLastChannel(channel, category: category)
        startCandidate(at: 0)
        loadEPG(for: channel)
        showChannelOverlay()
    }

    func nextChannel() {
        changeChannel(step: 1)
    }

    func previousChannel() {
        changeChannel(step: -1)
    }

    func stop() {
        fallbackTask?.cancel()
        overlayTask?.cancel()
        epgTask?.cancel()

        playbackURL = nil
        isPlaying = false
        isChannelMenuVisible = false
        isChannelOverlayVisible = false
        receivedPlayingState = false
        errorMessage = ""
    }

    func playerDidStartPlaying() {
        receivedPlayingState = true
        fallbackTask?.cancel()
    }

    func playerFailed() {
        tryNextCandidate(
            reason: "The selected stream source could not be played."
        )
    }

    func toggleChannelMenu() {
        isChannelMenuVisible.toggle()
        if isChannelMenuVisible {
            isChannelOverlayVisible = false
        } else if isPlaying {
            showChannelOverlay()
        }
    }

    private func changeChannel(step: Int) {
        guard !channels.isEmpty else {
            return
        }

        let currentIndex = selectedChannel
            .flatMap { selected in channels.firstIndex(where: { $0.id == selected.id }) }
            ?? 0

        var nextIndex = currentIndex + step
        if nextIndex < 0 {
            nextIndex = channels.count - 1
        } else if nextIndex >= channels.count {
            nextIndex = 0
        }

        play(channels[nextIndex])
    }

    private func startCandidate(at index: Int) {
        guard candidateURLs.indices.contains(index) else {
            return
        }

        fallbackTask?.cancel()
        candidateIndex = index
        receivedPlayingState = false
        playbackURL = candidateURLs[index]
        playbackIdentity = UUID()

        if index > 0 {
            errorMessage = "Trying alternate stream source…"
        }

        fallbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self, !self.receivedPlayingState else {
                    return
                }
                self.tryNextCandidate(reason: "No video frame was received.")
            }
        }
    }

    private func tryNextCandidate(reason: String) {
        fallbackTask?.cancel()

        if candidateIndex < candidateURLs.count - 1 {
            startCandidate(at: candidateIndex + 1)
            return
        }

        playbackURL = nil
        isPlaying = false
        errorMessage = "Channel playback failed for every source: \(reason)"
    }

    private func loadEPG(for channel: MarkhorLiveChannel) {
        epgTask?.cancel()

        epgTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let programs = try await client.shortEPG(streamID: channel.id)
                guard !Task.isCancelled,
                      selectedChannel?.id == channel.id
                else {
                    return
                }

                currentProgram = programs.first
                nextProgram = programs.dropFirst().first

                if currentProgram != nil || nextProgram != nil {
                    showChannelOverlay()
                }
            } catch {
                // EPG failure must never interrupt playback.
            }
        }
    }

    private func showChannelOverlay() {
        overlayTask?.cancel()
        isChannelOverlayVisible = true

        overlayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.isChannelOverlayVisible = false
            }
        }
    }

    private func saveLastChannel(
        _ channel: MarkhorLiveChannel,
        category: MarkhorLiveCategory
    ) {
        UserDefaults.standard.set(
            [
                "categoryID": category.id,
                "channelID": channel.id,
            ],
            forKey: defaultsKey
        )
    }

    private func restoredCategory(
        from availableCategories: [MarkhorLiveCategory]
    ) -> MarkhorLiveCategory? {
        guard let saved = UserDefaults.standard.dictionary(forKey: defaultsKey),
              let categoryID = saved["categoryID"] as? String
        else {
            return nil
        }

        return availableCategories.first(where: { $0.id == categoryID })
    }

    private func restoredChannel(
        from availableChannels: [MarkhorLiveChannel],
        categoryID: String
    ) -> MarkhorLiveChannel? {
        guard let saved = UserDefaults.standard.dictionary(forKey: defaultsKey),
              saved["categoryID"] as? String == categoryID,
              let channelID = saved["channelID"] as? String
        else {
            return nil
        }

        return availableChannels.first(where: { $0.id == channelID })
    }
}

struct MarkhorLiveTVView: View {

    private let onBack: () -> Void

    @StateObject
    private var model: MarkhorLiveTVModel

    @StateObject
    private var playerProxy = VLCVideoPlayer.Proxy()

    @State
    private var isPaused = false

    @State
    private var audioTracks: [MediaTrack] = []

    @State
    private var selectedAudioTrackIndex: Int = -1

    @AppStorage("markhor.apple.live.aspectFill")
    private var liveAspectFill = false

    @AppStorage("markhor.apple.live.networkCachingMs")
    private var liveNetworkCachingMs = 1500

    init(
        credentials: MarkhorXCCredentials,
        onBack: @escaping () -> Void
    ) {
        self.onBack = onBack
        _model = StateObject(
            wrappedValue: MarkhorLiveTVModel(credentials: credentials)
        )
    }

    var body: some View {
        ZStack {
            MarkhorTheme.background
                .ignoresSafeArea()

            if model.isPlaying, let playbackURL = model.playbackURL {
                playerView(url: playbackURL)
            } else {
                channelBrowser
            }

            if model.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
        .task {
            model.start()
        }
        .onDisappear {
            playerProxy.stop()
            model.stop()
        }
    }

    private var channelBrowser: some View {
        VStack(spacing: 16) {
            header

            HStack(alignment: .top, spacing: 14) {
                categoryColumn
                    .frame(minWidth: 170, idealWidth: 230, maxWidth: 280)

                channelColumn
                    .frame(maxWidth: .infinity)
            }

            if !model.errorMessage.isEmpty {
                Text(model.errorMessage)
                    .foregroundStyle(.orange)
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Label("Home", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)

            Text("Live TV")
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            if !model.channels.isEmpty {
                Text("\(model.channels.count) Channels")
                    .foregroundStyle(MarkhorTheme.accent)
                    .fontWeight(.semibold)
            }

            Button {
                model.start()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var categoryColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Categories")
                .font(.headline)
                .foregroundStyle(MarkhorTheme.accent)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.categories) { category in
                        Button {
                            Task {
                                await model.selectCategory(category)
                            }
                        } label: {
                            HStack {
                                Text(category.name)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        model.selectedCategory?.id == category.id
                                            ? MarkhorTheme.success.opacity(0.8)
                                            : MarkhorTheme.panel.opacity(0.9)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var channelColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.selectedCategory?.name ?? "Channels")
                    .font(.headline)

                Spacer()
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.channels) { channel in
                        channelButton(channel)
                    }
                }
            }
        }
    }

    private func channelButton(
        _ channel: MarkhorLiveChannel
    ) -> some View {
        Button {
            model.play(channel)
        } label: {
            HStack(spacing: 14) {
                channelLogo(channel)
                    .frame(width: 54, height: 54)

                if !channel.number.isEmpty {
                    Text(channel.number)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(MarkhorTheme.accent)
                        .frame(minWidth: 35)
                }

                Text(channel.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "play.fill")
                    .foregroundStyle(MarkhorTheme.accent)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(MarkhorTheme.panel.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(MarkhorTheme.accent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func channelLogo(
        _ channel: MarkhorLiveChannel
    ) -> some View {
        if let iconURL = channel.iconURL {
            AsyncImage(url: iconURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    Image(systemName: "play.tv.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .foregroundStyle(MarkhorTheme.accent)
                }
            }
        } else {
            Image(systemName: "play.tv.fill")
                .resizable()
                .scaledToFit()
                .padding(10)
                .foregroundStyle(MarkhorTheme.accent)
        }
    }

    private func playerView(url: URL) -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VLCVideoPlayer(
                configuration: playerConfiguration(url: url)
            )
            .proxy(playerProxy)
            .onStateUpdated { state, info in
                Task { @MainActor in
                    audioTracks = info.audioTracks
                    selectedAudioTrackIndex = info.currentAudioTrack.index
                    switch state {
                    case .playing:
                        isPaused = false
                        model.playerDidStartPlaying()
                    case .paused:
                        isPaused = true
                    case .error:
                        model.playerFailed()
                    default:
                        break
                    }
                }
            }
            .id(model.playbackIdentity)
            .ignoresSafeArea()

            playbackControlsOverlay
        }
        #if os(tvOS)
        .onMoveCommand { direction in
            guard !model.isChannelMenuVisible else {
                return
            }

            switch direction {
            case .up:
                model.nextChannel()
            case .down:
                model.previousChannel()
            default:
                break
            }
        }
        .onExitCommand {
            if model.isChannelMenuVisible {
                model.isChannelMenuVisible = false
            } else {
                model.toggleChannelMenu()
            }
        }
        .onPlayPauseCommand {
            if isPaused {
                playerProxy.play()
            } else {
                playerProxy.pause()
            }
            isPaused.toggle()
        }
        #else
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard !model.isChannelMenuVisible else {
                        return
                    }

                    if value.translation.height < -60 {
                        model.nextChannel()
                    } else if value.translation.height > 60 {
                        model.previousChannel()
                    }
                }
        )
        #endif
    }

    private func playerConfiguration(
        url: URL
    ) -> VLCVideoPlayer.Configuration {
        var configuration = VLCVideoPlayer.Configuration(url: url)
        configuration.autoPlay = true
        configuration.aspectFill = liveAspectFill
        configuration.audioIndex = .auto
        configuration.subtitleIndex = .absolute(-1)
        configuration.options = [
            "network-caching": liveNetworkCachingMs,
            "http-user-agent": "Mozilla/5.0",
        ]
        return configuration
    }

    @ViewBuilder
    private var playbackControlsOverlay: some View {
        ZStack(alignment: .top) {
            VStack {
                HStack(spacing: 12) {
                    Button {
                        playerProxy.stop()
                        model.stop()
                        onBack()
                    } label: {
                        Label("Home", systemImage: "chevron.left")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MarkhorTheme.panel)

                    Button {
                        model.toggleChannelMenu()
                    } label: {
                        Label("Channels", systemImage: "list.bullet")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MarkhorTheme.panel)

                    if !audioTracks.isEmpty {
                        Menu {
                            ForEach(audioTracks, id: \.index) { track in
                                Button {
                                    playerProxy.setAudioTrack(.absolute(track.index))
                                    selectedAudioTrackIndex = track.index
                                } label: {
                                    Label(
                                        track.title,
                                        systemImage: selectedAudioTrackIndex == track.index
                                            ? "checkmark.circle.fill"
                                            : "circle"
                                    )
                                }
                            }
                        } label: {
                            Label("Audio", systemImage: "speaker.wave.2.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MarkhorTheme.panel)
                    }

                    Spacer()
                }
                .padding()

                Spacer()
            }

            if model.isChannelOverlayVisible,
               !model.isChannelMenuVisible,
               let channel = model.selectedChannel
            {
                channelOverlay(channel)
                    .transition(
                        .move(edge: .top)
                            .combined(with: .opacity)
                    )
                    .padding(.top, 26)
                    .padding(.horizontal, 80)
            }

            if model.isChannelMenuVisible {
                channelMenuOverlay
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: model.isChannelOverlayVisible)
        .animation(.easeOut(duration: 0.22), value: model.isChannelMenuVisible)
    }

    private func channelOverlay(
        _ channel: MarkhorLiveChannel
    ) -> some View {
        HStack(spacing: 16) {
            channelLogo(channel)
                .frame(width: 70, height: 70)

            if !channel.number.isEmpty {
                Text(channel.number)
                    .font(.headline)
                    .foregroundStyle(MarkhorTheme.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(channel.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)

                if let current = model.currentProgram {
                    HStack(spacing: 8) {
                        Text("NOW")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(MarkhorTheme.accent)

                        Text(current.title)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        if !current.timeRange.isEmpty {
                            Text(current.timeRange)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let next = model.nextProgram {
                    HStack(spacing: 8) {
                        Text("NEXT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)

                        Text(next.title)
                            .font(.caption)
                            .lineLimit(1)

                        if !next.timeRange.isEmpty {
                            Text(next.timeRange)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: 760)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(MarkhorTheme.panel.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(MarkhorTheme.accent.opacity(0.35), lineWidth: 1)
        )
    }

    private var channelMenuOverlay: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(model.selectedCategory?.name ?? "Channels")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        model.isChannelMenuVisible = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.channels) { channel in
                            channelButton(channel)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 520, maxHeight: .infinity)
            .background(MarkhorTheme.background.opacity(0.97))

            Spacer()
        }
        .ignoresSafeArea()
    }
}
