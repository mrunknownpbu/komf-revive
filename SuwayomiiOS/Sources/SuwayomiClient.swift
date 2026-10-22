import Foundation

struct Manga: Identifiable, Decodable, Hashable {
    let id: Int
    let title: String
    let thumbnailUrl: String?
    let description: String?
}

struct Chapter: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
    let chapterNumber: Double
    let isRead: Bool
}

struct ClientError: LocalizedError {
    let errorDescription: String?
}

/// Minimal Suwayomi GraphQL client. Mihon extensions run server-side, so the app only needs this API.
struct SuwayomiClient {
    let baseURL: URL
    let username: String
    let password: String

    func absolute(_ path: String) -> URL? {
        path.hasPrefix("http") ? URL(string: path) : URL(string: path, relativeTo: baseURL)?.absoluteURL
    }

    func request(for url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        if !username.isEmpty {
            let token = Data("\(username):\(password)".utf8).base64EncodedString()
            req.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func query<T: Decodable>(_ query: String, variables: [String: Any] = [:], as: T.Type) async throws -> T {
        var req = request(for: baseURL.appendingPathComponent("api/graphql"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "variables": variables])
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Envelope: Decodable { let data: T?; let errors: [GQLError]? }
        struct GQLError: Decodable { let message: String }
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        if let msg = env.errors?.first?.message { throw ClientError(errorDescription: msg) }
        guard let result = env.data else { throw ClientError(errorDescription: "Empty response") }
        return result
    }

    func library() async throws -> [Manga] {
        struct R: Decodable { struct M: Decodable { let nodes: [Manga] }; let mangas: M }
        let q = "{ mangas(condition: {inLibrary: true}) { nodes { id title thumbnailUrl description } } }"
        return try await query(q, as: R.self).mangas.nodes
    }

    func chapters(mangaId: Int) async throws -> [Chapter] {
        struct R: Decodable { struct C: Decodable { let nodes: [Chapter] }; let chapters: C }
        let q = "query($id: Int!) { chapters(condition: {mangaId: $id}, orderBy: SOURCE_ORDER, orderByType: DESC) { nodes { id name chapterNumber isRead } } }"
        return try await query(q, variables: ["id": mangaId], as: R.self).chapters.nodes
    }

    func pages(chapterId: Int) async throws -> [URL] {
        struct R: Decodable { struct F: Decodable { let pages: [String] }; let fetchChapterPages: F }
        let q = "mutation($id: Int!) { fetchChapterPages(input: {chapterId: $id}) { pages } }"
        let r = try await query(q, variables: ["id": chapterId], as: R.self)
        return r.fetchChapterPages.pages.compactMap(absolute)
    }

    func markRead(chapterId: Int) async throws {
        struct R: Decodable { let updateChapter: Empty }
        struct Empty: Decodable {}
        let q = "mutation($id: Int!) { updateChapter(input: {id: $id, patch: {isRead: true}}) { clientMutationId } }"
        _ = try await query(q, variables: ["id": chapterId], as: R.self)
    }
}
