//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v2.0.
//

import Factory
import JellyfinAPI
import SwiftUI

struct MarkhorMediaLibraryView: View {

    enum Section {
        case movies
        case series

        var title: String {
            switch self {
            case .movies:
                return "Movies"
            case .series:
                return "Series"
            }
        }

        var itemType: BaseItemKind {
            switch self {
            case .movies:
                return .movie
            case .series:
                return .series
            }
        }

        var storageID: String {
            switch self {
            case .movies:
                return "markhor-movies"
            case .series:
                return "markhor-series"
            }
        }
    }

    private let section: Section
    private let onBack: () -> Void
    private let libraryViewModel: ItemLibraryViewModel

    @State
    private var hasJellyfinSession: Bool

    init(
        section: Section,
        onBack: @escaping () -> Void
    ) {
        self.section = section
        self.onBack = onBack
        self._hasJellyfinSession = State(
            initialValue: Container.shared.currentUserSession() != nil
        )

        let filters = ItemFilterCollection(
            itemTypes: [section.itemType],
            sortBy: [.premiereDate],
            sortOrder: [.descending]
        )

        self.libraryViewModel = ItemLibraryViewModel(
            title: section.title,
            id: section.storageID,
            filters: filters
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MarkhorTheme.background
                .ignoresSafeArea()

            if hasJellyfinSession {
                NavigationInjectionView(coordinator: .init()) {
                    PagingLibraryView(viewModel: libraryViewModel)
                }
            } else {
                RootView()
            }

            Button(action: onBack) {
                Label("Home", systemImage: "chevron.left")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(MarkhorTheme.panel)
            .padding()
        }
        .onReceive(Notifications[.didSignIn].publisher) { _ in
            hasJellyfinSession = true
        }
        .onReceive(Notifications[.didSignOut].publisher) { _ in
            hasJellyfinSession = false
        }
    }
}
