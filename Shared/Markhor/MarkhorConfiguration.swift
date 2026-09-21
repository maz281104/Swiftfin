//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v2.0.
//

import Foundation
import SwiftUI

enum MarkhorConfiguration {
    static let appName = "Markhor IPTV"
    static let bundleIdentifier = "com.markhor.iptv"

    static let xcPortalURL = URL(string: "http://192.168.40.2:8011/player_api.php")!
    static let jellyfinServerURL = URL(string: "http://192.168.40.2:8096")!
    static let updateFeedURL = URL(string: "http://192.168.40.2:8099/apple-update.json")!
}

enum MarkhorTheme {
    static let background = Color(red: 7 / 255, green: 19 / 255, blue: 14 / 255)
    static let panel = Color(red: 12 / 255, green: 35 / 255, blue: 25 / 255)
    static let accent = Color(red: 217 / 255, green: 184 / 255, blue: 74 / 255)
    static let success = Color(red: 31 / 255, green: 122 / 255, blue: 76 / 255)
}
