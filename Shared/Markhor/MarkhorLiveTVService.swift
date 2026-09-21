//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v2.0.
//

import Foundation

struct MarkhorXCCredentials: Sendable {
    let username: String
    let password: String
}

struct MarkhorLiveCategory: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

struct MarkhorLiveChannel: Identifiable, Hashable, Sendable {
    let id: String
    let number: String
    let name: String
    let iconURL: URL?
    let directSource: String
    let epgID: String
}

struct MarkhorEPGProgram: Identifiable, Hashable, Sendable {
    let id = UUID()
    let title: String
    let start: String
    let end: String
    let startTimestamp: Int
    let endTimestamp: Int

    var timeRange: String {
        let startText = Self.clock(startTimestamp, fallback: start)
        let endText = Self.clock(endTimestamp, fallback: end)

        if startText.isEmpty {
            return endText
        }
        if endText.isEmpty {
            return startText
        }
        return "\(startText) – \(endText)"
    }

    private static func clock(_ timestamp: Int, fallback: String) -> String {
        if timestamp > 0 {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
        }

        let parts = fallback.split(separator: " ")
        if let match = parts.first(where: { $0.contains(":") }) {
            return String(match.prefix(5))
        }

        return ""
    }
}

struct MarkhorXCClient: Sendable {

    let credentials: MarkhorXCCredentials

    func liveCategories() async throws -> [MarkhorLiveCategory] {
        let object = try await request(action: "get_live_categories")

        guard let array = object as? [[String: Any]] else {
            throw MarkhorLiveTVError.invalidData
        }

        return array.compactMap { item in
            let id = Self.string(item["category_id"])
            let name = Self.string(item["category_name"])

            guard !id.isEmpty, !name.isEmpty else {
                return nil
            }

            return MarkhorLiveCategory(id: id, name: name)
        }
    }

    func liveChannels(categoryID: String) async throws -> [MarkhorLiveChannel] {
        let object = try await request(
            action: "get_live_streams",
            extra: [
                URLQueryItem(name: "category_id", value: categoryID),
            ]
        )

        guard let array = object as? [[String: Any]] else {
            throw MarkhorLiveTVError.invalidData
        }

        return array.compactMap { item in
            let streamID = Self.string(item["stream_id"])
            let name = Self.string(item["name"])

            guard !streamID.isEmpty, !name.isEmpty else {
                return nil
            }

            return MarkhorLiveChannel(
                id: streamID,
                number: Self.string(item["num"]),
                name: name,
                iconURL: URL(string: Self.string(item["stream_icon"])),
                directSource: Self.string(item["direct_source"]),
                epgID: Self.string(item["epg_channel_id"])
            )
        }
    }

    func shortEPG(streamID: String) async throws -> [MarkhorEPGProgram] {
        let object = try await request(
            action: "get_short_epg",
            extra: [
                URLQueryItem(name: "stream_id", value: streamID),
                URLQueryItem(name: "limit", value: "2"),
            ]
        )

        guard let dictionary = object as? [String: Any],
              let listings = dictionary["epg_listings"] as? [[String: Any]]
        else {
            return []
        }

        return listings.prefix(2).map { item in
            MarkhorEPGProgram(
                title: Self.decodeMaybeBase64(Self.string(item["title"])),
                start: Self.string(item["start"]),
                end: Self.string(item["end"]),
                startTimestamp: Self.integer(item["start_timestamp"]),
                endTimestamp: Self.integer(item["stop_timestamp"])
            )
        }
    }

    func streamCandidates(
        channel: MarkhorLiveChannel,
        categoryName: String
    ) -> [URL] {
        let generatedTS = generatedStreamURL(
            streamID: channel.id,
            streamExtension: "ts"
        )
        let generatedHLS = generatedStreamURL(
            streamID: channel.id,
            streamExtension: "m3u8"
        )
        let generatedRaw = generatedRawStreamURL(streamID: channel.id)
        let direct = URL(string: channel.directSource)

        let normalizedCategory = categoryName.lowercased()
        let hlsFirst =
            normalizedCategory.contains("titans")
            || normalizedCategory.contains("falcons")
            || normalizedCategory == "islamic 1"
            || normalizedCategory.contains("cinewave")

        let ordered: [URL?] = hlsFirst
            ? [generatedHLS, generatedTS, direct, generatedRaw]
            : [direct, generatedTS, generatedHLS, generatedRaw]

        var seen = Set<String>()
        return ordered.compactMap { url in
            guard let url else {
                return nil
            }

            let key = url.absoluteString
            guard seen.insert(key).inserted else {
                return nil
            }

            return url
        }
    }

    private func request(
        action: String,
        extra: [URLQueryItem] = []
    ) async throws -> Any {
        guard var components = URLComponents(
            url: MarkhorConfiguration.xcPortalURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw MarkhorLiveTVError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "username", value: credentials.username),
            URLQueryItem(name: "password", value: credentials.password),
            URLQueryItem(name: "action", value: action),
        ] + extra

        guard let url = components.url else {
            throw MarkhorLiveTVError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Markhor-IPTV-Apple/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw MarkhorLiveTVError.connection
        }

        return try JSONSerialization.jsonObject(with: data)
    }

    private func generatedStreamURL(
        streamID: String,
        streamExtension: String
    ) -> URL? {
        URL(
            string: "http://192.168.40.2:8011/live/"
                + Self.pathSegment(credentials.username) + "/"
                + Self.pathSegment(credentials.password) + "/"
                + Self.pathSegment(streamID) + "."
                + streamExtension
        )
    }

    private func generatedRawStreamURL(streamID: String) -> URL? {
        URL(
            string: "http://192.168.40.2:8011/live/"
                + Self.pathSegment(credentials.username) + "/"
                + Self.pathSegment(credentials.password) + "/"
                + Self.pathSegment(streamID)
        )
    }

    private static func pathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func string(_ value: Any?) -> String {
        switch value {
        case let value as String:
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        case let value as NSNumber:
            return value.stringValue
        default:
            return ""
        }
    }

    private static func integer(_ value: Any?) -> Int {
        switch value {
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value) ?? 0
        default:
            return 0
        }
    }

    private static func decodeMaybeBase64(_ source: String) -> String {
        let clean = source.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty,
              let data = Data(base64Encoded: clean),
              let decoded = String(data: data, encoding: .utf8),
              !decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return clean
        }

        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MarkhorLiveTVError: Error {
    case invalidURL
    case connection
    case invalidData

    var message: String {
        switch self {
        case .invalidURL:
            return "Unable to create the Live TV request."
        case .connection:
            return "Unable to connect to the Live TV server."
        case .invalidData:
            return "The Live TV server returned invalid data."
        }
    }
}
