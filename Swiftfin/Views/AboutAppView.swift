//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct AboutAppView: View {

    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 10) {

                    Image("markhor-header-emblem")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)

                    Image("markhor-wordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .frame(height: 68)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {

                LabeledContent(
                    L10n.version,
                    value: "\(UIApplication.appVersion ?? .emptyDash) (\(UIApplication.bundleVersion ?? .emptyDash))"
                )

                ChevronButton(
                    L10n.sourceCode,
                    image: .logoGithub,
                    external: true
                ) {
                    if let url = URL(string: "https://github.com/maz281104/Swiftfin") {
                        UIApplication.shared.open(url)
                    }
                }

                ChevronButton(
                    L10n.bugsAndFeatures,
                    systemName: "plus.circle.fill",
                    external: true
                ) {
                    if let url = URL(string: "https://github.com/maz281104/Swiftfin/issues") {
                        UIApplication.shared.open(url)
                    }
                }
                .symbolRenderingMode(.monochrome)

                ChevronButton(
                    L10n.settings,
                    systemName: "gearshape.fill",
                    external: true
                ) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}
