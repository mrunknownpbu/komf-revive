import SwiftUI

struct ServerSetupView: View {
    @EnvironmentObject var settings: ServerSettings
    @State private var draft = "http://"

    var body: some View {
        Form {
            Section("Suwayomi server") {
                TextField("http://192.168.1.10:4567", text: $draft)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                TextField("Username (optional)", text: $settings.username).textInputAutocapitalization(.never)
                SecureField("Password", text: $settings.password)
            }
            Button("Connect") { settings.url = draft }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var settings: ServerSettings
    @State private var mangas: [Manga] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                    ForEach(mangas) { manga in
                        NavigationLink(value: manga) { Cover(manga: manga) }.buttonStyle(.plain)
                    }
                }.padding()
            }
            .navigationTitle("Library")
            .navigationDestination(for: Manga.self) { ChapterListView(manga: $0) }
            .toolbar { Button("Server") { settings.url = "" } }
            .overlay { if let error { Text(error).foregroundStyle(.red).padding() } }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        do { mangas = try await settings.client.library(); error = nil }
        catch { self.error = error.localizedDescription }
    }
}

struct Cover: View {
    @EnvironmentObject var settings: ServerSettings
    let manga: Manga

    var body: some View {
        VStack(alignment: .leading) {
            AuthImage(url: manga.thumbnailUrl.flatMap(settings.client.absolute))
                .aspectRatio(2 / 3, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(manga.title).font(.caption).lineLimit(2)
        }
    }
}

struct ChapterListView: View {
    @EnvironmentObject var settings: ServerSettings
    let manga: Manga
    @State private var chapters: [Chapter] = []
    @State private var reading: Chapter?

    var body: some View {
        List(chapters) { chapter in
            Button { reading = chapter } label: {
                Text(chapter.name).foregroundStyle(chapter.isRead ? .secondary : .primary)
            }
        }
        .navigationTitle(manga.title)
        .task { chapters = (try? await settings.client.chapters(mangaId: manga.id)) ?? [] }
        .fullScreenCover(item: $reading) { ReaderView(chapter: $0) }
    }
}

struct ReaderView: View {
    @EnvironmentObject var settings: ServerSettings
    @Environment(\.dismiss) private var dismiss
    let chapter: Chapter
    @State private var pages: [URL] = []

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView {
                ForEach(pages, id: \.self) { AuthImage(url: $0, fit: true) }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            Button("Close") { dismiss() }.padding()
        }
        .task {
            pages = (try? await settings.client.pages(chapterId: chapter.id)) ?? []
            try? await settings.client.markRead(chapterId: chapter.id)
        }
    }
}

/// AsyncImage can't send basic-auth headers, so load through URLSession.
struct AuthImage: View {
    @EnvironmentObject var settings: ServerSettings
    let url: URL?
    var fit = false
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: fit ? .fit : .fill)
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .task(id: url) {
            guard let url else { return }
            let req = settings.client.request(for: url)
            if let (data, _) = try? await URLSession.shared.data(for: req) { image = UIImage(data: data) }
        }
    }
}
