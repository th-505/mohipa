import Foundation
import SwiftUI

struct StoreApp: Decodable, Identifiable {
    let trackId: Int
    let trackName: String
    let bundleId: String
    let trackViewUrl: URL?
    let version: String?
    var id: Int { trackId }
}

private struct CatalogResponse: Decodable {
    let results: [StoreApp]
}

struct Catalog {
    static func search(_ query: String, country: String, limit: Int) async throws -> [StoreApp] {
        let appID = URLComponents(string: query).flatMap { url -> String? in
            guard url.scheme == "https", url.host == "apps.apple.com" else { return nil }
            return url.path.split(separator: "/").last.flatMap { part in
                guard part.hasPrefix("id"), let id = Int(part.dropFirst(2)) else { return nil }
                return String(id)
            }
        }
        let isBundleID = query.range(of: #"^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+){2,}$"#, options: .regularExpression) != nil
        let lookup = appID != nil || isBundleID
        var url = URLComponents()
        url.scheme = "https"
        url.host = "itunes.apple.com"
        url.path = lookup ? "/lookup" : "/search"
        var items = [URLQueryItem(name: "country", value: country),
                     URLQueryItem(name: "entity", value: "software")]
        if let appID = appID {
            items.append(URLQueryItem(name: "id", value: appID))
        } else if isBundleID {
            items.append(URLQueryItem(name: "bundleId", value: query))
        } else {
            items.append(URLQueryItem(name: "media", value: "software"))
            items.append(URLQueryItem(name: "term", value: query))
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        url.queryItems = items
        guard let endpoint = url.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: endpoint)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CatalogResponse.self, from: data).results
    }
}

struct MohipaHome: View {
    @AppStorage("storeCountry") private var country = "SA"
    @AppStorage("searchLimit") private var limit = 25

    var body: some View {
        TabView {
            CatalogView(country: $country, limit: limit)
                .tabItem { Label("المتجر", systemImage: "magnifyingglass") }
            IPAFileView()
                .tabItem { Label("ملفات IPA", systemImage: "archivebox") }
            NavigationView {
                Form {
                    Stepper("نتائج البحث: \(limit)", value: $limit, in: 5...100, step: 5)
                }
                .navigationTitle("إعدادات mohipa")
            }
            .tabItem { Label("الإعدادات", systemImage: "slider.horizontal.3") }
        }
        .tint(.mint)
    }
}

struct CatalogView: View {
    @Binding var country: String
    let limit: Int
    @State private var query = ""
    @State private var results: [StoreApp] = []
    @State private var message: String?
    @State private var loading = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            List {
                Section {
                    Picker("واجهة المتجر", selection: $country) {
                        ForEach(Locale.isoRegionCodes, id: \.self) { code in
                            Text(Locale(identifier: "ar").localizedString(forRegionCode: code) ?? code)
                                .tag(code)
                        }
                    }
                    TextField("اسم التطبيق أو Bundle ID أو رابط App Store", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(runSearch)
                    Button("بحث", action: runSearch)
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if loading { ProgressView("جارٍ البحث…") }
                if let message = message { Text(message).foregroundColor(.secondary) }
                ForEach(results) { app in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(app.trackName).font(.headline)
                        Text(app.bundleId).font(.caption).foregroundColor(.secondary)
                        if let version = app.version { Text("الإصدار \(version)").font(.caption) }
                        if let url = app.trackViewUrl, url.scheme == "https", url.host == "apps.apple.com" {
                            Link("عرض في App Store", destination: url)
                        }
                    }
                }
            }
            .navigationTitle("mohipa")
            .onChange(of: country) { _ in
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { runSearch() }
            }
        }
    }

    private func runSearch() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        searchTask?.cancel()
        let selectedCountry = country
        loading = true
        message = nil
        results = []
        searchTask = Task { @MainActor in
            do {
                let matches = try await Catalog.search(term, country: selectedCountry, limit: limit)
                guard !Task.isCancelled else { return }
                results = matches
                message = matches.isEmpty ? "ما فيه نتائج في واجهة المتجر المحددة." : nil
            } catch {
                guard !Task.isCancelled else { return }
                message = "تعذّر البحث. جرّب مرة ثانية."
            }
            loading = false
        }
    }
}
