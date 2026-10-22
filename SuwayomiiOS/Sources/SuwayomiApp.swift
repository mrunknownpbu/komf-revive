import SwiftUI

@main
struct SuwayomiApp: App {
    @StateObject private var settings = ServerSettings()

    var body: some Scene {
        WindowGroup {
            if settings.isConfigured {
                RootView().environmentObject(settings)
            } else {
                ServerSetupView().environmentObject(settings)
            }
        }
    }
}

/// Server address and optional basic-auth credentials, persisted in UserDefaults.
final class ServerSettings: ObservableObject {
    @Published var url: String { didSet { UserDefaults.standard.set(url, forKey: "serverUrl") } }
    @Published var username: String { didSet { UserDefaults.standard.set(username, forKey: "username") } }
    @Published var password: String { didSet { UserDefaults.standard.set(password, forKey: "password") } }

    init() {
        url = UserDefaults.standard.string(forKey: "serverUrl") ?? ""
        username = UserDefaults.standard.string(forKey: "username") ?? ""
        password = UserDefaults.standard.string(forKey: "password") ?? ""
    }

    var isConfigured: Bool { URL(string: url)?.host != nil }
    var client: SuwayomiClient { SuwayomiClient(baseURL: URL(string: url)!, username: username, password: password) }
}
