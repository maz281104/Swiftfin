//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v2.0.
//

import Foundation
import KeychainSwift

@MainActor
final class MarkhorXCSession: ObservableObject {

    @Published private(set) var isSignedIn = false
    @Published private(set) var isBusy = false
    @Published private(set) var accountName = ""
    @Published private(set) var accountExpiry = ""
    @Published var errorMessage = ""

    private let keychain = KeychainSwift(keyPrefix: "markhor.apple.xc.")

    private var activeUsername = ""
    private var activePassword = ""

    private enum Key {
        static let username = "username"
        static let password = "password"
    }

    init() {
        guard let username = keychain.get(Key.username),
              let password = keychain.get(Key.password),
              !username.isEmpty,
              !password.isEmpty
        else {
            return
        }

        Task {
            await authenticate(username: username, password: password, persist: false)
        }
    }

    func signIn(username: String, password: String) {
        Task {
            await authenticate(
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                persist: true
            )
        }
    }

    var credentials: MarkhorXCCredentials? {
        guard isSignedIn, !activeUsername.isEmpty, !activePassword.isEmpty else {
            return nil
        }

        return MarkhorXCCredentials(
            username: activeUsername,
            password: activePassword
        )
    }

    func signOut() {
        keychain.delete(Key.username)
        keychain.delete(Key.password)
        activeUsername = ""
        activePassword = ""
        accountName = ""
        accountExpiry = ""
        errorMessage = ""
        isSignedIn = false
    }

    private func authenticate(
        username: String,
        password: String,
        persist: Bool
    ) async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Username and password are required."
            return
        }

        guard var components = URLComponents(
            url: MarkhorConfiguration.xcPortalURL,
            resolvingAgainstBaseURL: false
        ) else {
            errorMessage = "Invalid Markhor IPTV portal URL."
            return
        }

        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
        ]

        guard let url = components.url else {
            errorMessage = "Unable to build the Markhor IPTV login request."
            return
        }

        isBusy = true
        errorMessage = ""

        defer {
            isBusy = false
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.setValue("Markhor-IPTV-Apple/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode)
            else {
                throw MarkhorXCError.connection
            }

            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let userInfo = object["user_info"] as? [String: Any],
                  Self.isAuthenticated(userInfo["auth"])
            else {
                throw MarkhorXCError.invalidCredentials
            }

            let status = String(describing: userInfo["status"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if !status.isEmpty, status != "active" {
                throw MarkhorXCError.accountStatus(status)
            }

            let expiryEpoch = Self.epoch(userInfo["exp_date"])
            if expiryEpoch > 0, expiryEpoch <= Int(Date().timeIntervalSince1970) {
                throw MarkhorXCError.expired
            }

            activeUsername = username
            activePassword = password
            accountName = username
            accountExpiry = Self.expiryText(expiryEpoch)
            isSignedIn = true

            if persist {
                keychain.set(username, forKey: Key.username)
                keychain.set(password, forKey: Key.password)
            }
        } catch let error as MarkhorXCError {
            isSignedIn = false
            errorMessage = error.message
        } catch {
            isSignedIn = false
            errorMessage = "Unable to connect to the Markhor IPTV server."
        }
    }

    private static func isAuthenticated(_ value: Any?) -> Bool {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.intValue == 1
        case let value as String:
            return ["1", "true"].contains(value.lowercased())
        default:
            return false
        }
    }

    private static func epoch(_ value: Any?) -> Int {
        switch value {
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value) ?? 0
        default:
            return 0
        }
    }

    private static func expiryText(_ epoch: Int) -> String {
        guard epoch > 0 else {
            return "Unlimited"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(epoch)))
    }
}

private enum MarkhorXCError: Error {
    case connection
    case invalidCredentials
    case expired
    case accountStatus(String)

    var message: String {
        switch self {
        case .connection:
            return "Unable to connect to the Markhor IPTV server."
        case .invalidCredentials:
            return "Incorrect username or password."
        case .expired:
            return "This IPTV account has expired."
        case let .accountStatus(status):
            return status.isEmpty
                ? "This IPTV account is not active."
                : "This IPTV account is \(status)."
        }
    }
}
