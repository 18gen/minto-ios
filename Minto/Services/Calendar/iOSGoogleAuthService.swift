import Foundation
import AuthenticationServices
import CryptoKit
import Observation

@Observable
@MainActor
final class iOSGoogleAuthService: NSObject {
    static let shared = iOSGoogleAuthService()

    private let scope = "https://www.googleapis.com/auth/calendar.readonly"
    private let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    private let accessTokenKey = "google_access_token"
    private let refreshTokenKey = "google_refresh_token"
    private let expirationKey = "google_token_expiration"

    private let callbackScheme = "com.genichihashi.minto"
    private let redirectURI = "com.genichihashi.minto:/oauth2redirect"

    var isAuthenticated: Bool {
        KeychainService.loadToken(forKey: refreshTokenKey) != nil
    }

    private var clientID: String { AppSettings.shared.googleClientID }
    private var clientSecret: String { AppSettings.shared.googleClientSecret }

    private override init() {
        super.init()
    }

    func signIn() async throws {
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            throw AuthError.missingCredentials
        }

        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else {
            throw AuthError.invalidURL
        }

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL,
                      let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.noAuthCode)
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)
    }

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]

        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.tokenExchangeFailed(body)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let accessToken = json?["access_token"] as? String else {
            throw AuthError.noAccessToken
        }

        KeychainService.saveToken(accessToken, forKey: accessTokenKey)

        if let refreshToken = json?["refresh_token"] as? String {
            KeychainService.saveToken(refreshToken, forKey: refreshTokenKey)
        }

        if let expiresIn = json?["expires_in"] as? Int {
            let expiration = Date.now.addingTimeInterval(TimeInterval(expiresIn))
            KeychainService.saveToken(String(expiration.timeIntervalSince1970), forKey: expirationKey)
        }
    }

    func refreshAccessToken() async throws {
        guard let refreshToken = KeychainService.loadToken(forKey: refreshTokenKey) else {
            throw AuthError.noRefreshToken
        }

        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            signOut()
            throw AuthError.tokenRefreshFailed(body)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let accessToken = json?["access_token"] as? String else {
            throw AuthError.noAccessToken
        }

        KeychainService.saveToken(accessToken, forKey: accessTokenKey)

        if let expiresIn = json?["expires_in"] as? Int {
            let expiration = Date.now.addingTimeInterval(TimeInterval(expiresIn))
            KeychainService.saveToken(String(expiration.timeIntervalSince1970), forKey: expirationKey)
        }
    }

    func getValidAccessToken() async throws -> String {
        if let expirationStr = KeychainService.loadToken(forKey: expirationKey),
           let expiration = Double(expirationStr),
           Date.now.timeIntervalSince1970 < expiration - 60,
           let token = KeychainService.loadToken(forKey: accessTokenKey) {
            return token
        }

        try await refreshAccessToken()

        guard let token = KeychainService.loadToken(forKey: accessTokenKey) else {
            throw AuthError.noAccessToken
        }
        return token
    }

    func signOut() {
        KeychainService.delete(key: accessTokenKey)
        KeychainService.delete(key: refreshTokenKey)
        KeychainService.delete(key: expirationKey)
    }

    // MARK: - PKCE helpers

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64URLEncoded()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .ascii) else { return verifier }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncoded()
    }

    enum AuthError: Error, LocalizedError {
        case missingCredentials
        case invalidURL
        case noAuthCode
        case sessionFailed
        case tokenExchangeFailed(String)
        case noAccessToken
        case noRefreshToken
        case tokenRefreshFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingCredentials: "Google Client ID or Secret not set"
            case .invalidURL: "Invalid auth URL"
            case .noAuthCode: "No authorization code in callback"
            case .sessionFailed: "Auth session failed to start"
            case .tokenExchangeFailed(let msg): "Token exchange failed: \(msg)"
            case .noAccessToken: "No access token in response"
            case .noRefreshToken: "No refresh token available"
            case .tokenRefreshFailed(let msg): "Token refresh failed: \(msg)"
            }
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension iOSGoogleAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

// MARK: - Data base64url encoding
private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
