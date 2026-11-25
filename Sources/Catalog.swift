import Foundation
import SwiftUI
import UIKit

struct StoreApp: Decodable, Identifiable {
    let trackId: Int
    let trackName: String
    let bundleId: String
    let trackViewUrl: URL?
    let version: String?
    let artworkUrl100: URL?
    let minimumOsVersion: String?
    let fileSizeBytes: String?
    var id: Int { trackId }
}

private struct CatalogResponse: Decodable {
    let results: [StoreApp]
}

struct Catalog {
    static func search(_ query: String, country: String, limit: Int) async throws -> [StoreApp] {
        let storeLink = AppStoreLink(query)
        let appID = storeLink?.appID
        let isBundleID = query.range(of: #"^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+){2,}$"#, options: .regularExpression) != nil
        let lookup = appID != nil || isBundleID
        var url = URLComponents()
        url.scheme = "https"
        url.host = "itunes.apple.com"
        url.path = lookup ? "/lookup" : "/search"
        var items = [URLQueryItem(name: "country", value: storeLink?.country ?? country),
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

    @AppStorage("appearance") private var appearance: MohipaAppearance = .system
    @State private var selected = 0
    @State private var requestedSearch: String?

    var body: some View {
        ZStack {
            NavigationView { CatalogView(country: $country, requestedSearch: $requestedSearch, limit: limit) }
                .navigationViewStyle(.stack)
                .opacity(selected == 0 ? 1 : 0)
                .allowsHitTesting(selected == 0)
                .accessibilityHidden(selected != 0)
            IPAFileView { url in
                requestedSearch = url.absoluteString
                selected = 0
            }
                .opacity(selected == 1 ? 1 : 0)
                .allowsHitTesting(selected == 1)
                .accessibilityHidden(selected != 1)
            MohipaAccountsView()
                .opacity(selected == 2 ? 1 : 0)
                .allowsHitTesting(selected == 2)
                .accessibilityHidden(selected != 2)
            NavigationView {
                Form {
                    Section("المظهر") {
                        Picker("نمط الواجهة", selection: $appearance) {
                            ForEach(MohipaAppearance.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                    }
                    Stepper("نتائج البحث: \(limit)", value: $limit, in: 5...100, step: 5)
                }
                .navigationTitle("الإعدادات")
            }
            .navigationViewStyle(.stack)
            .opacity(selected == 3 ? 1 : 0)
            .allowsHitTesting(selected == 3)
            .accessibilityHidden(selected != 3)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 6) {
                tab("البحث", icon: "magnifyingglass", index: 0)
                tab("التنزيلات", icon: "arrow.down.square", index: 1)
                tab("الحسابات", icon: "person.crop.circle", index: 2)
                tab("الإعدادات", icon: "gearshape", index: 3)
            }
            .padding(5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.14)))
            .padding(.horizontal, 18)
            .padding(.vertical, 5)
        }
        .preferredColorScheme(appearance.scheme)
        .tint(.blue)
    }

    private func tab(_ label: String, icon: String, index: Int) -> some View {
        Button {
            selected = index
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(label).font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(selected == index ? .blue : .primary)
            .background(selected == index ? Color.blue.opacity(0.13) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected == index ? .isSelected : [])
    }
}

struct CatalogView: View {
    @Binding var country: String
    @Binding var requestedSearch: String?
    let limit: Int
    @State private var query = ""
    @State private var results: [StoreApp] = []
    @State private var message: String?
    @State private var loading = false
    @State private var searchTask: Task<Void, Never>?

    @FocusState private var searchFocused: Bool
    @State private var showingCountries = false

    var body: some View {
        VStack(spacing: 12) {
            searchBar
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        showingCountries = true
                    } label: {
                        Label(Locale(identifier: "ar").localizedString(forRegionCode: country) ?? country,
                              systemImage: "globe")
                            .font(.subheadline.weight(.semibold))
                    }
                    if loading { ProgressView("جارٍ البحث…") }
                    if let message = message { Text(message).foregroundColor(.secondary) }
                    if !results.isEmpty {
                        Text("النتائج (\(results.count))")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        LazyVStack(spacing: 0) {
                            ForEach(results) { app in
                                NavigationLink {
                                    appDetails(app)
                                } label: {
                                    resultRow(app)
                                }
                                .buttonStyle(.plain)
                                if app.id != results.last?.id {
                                    Divider().padding(.leading, 80)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showingCountries) {
            NavigationView {
                List {
                    ForEach(Locale.isoRegionCodes, id: \.self) { code in
                        Button(Locale(identifier: "ar").localizedString(forRegionCode: code) ?? code) {
                            country = code
                            showingCountries = false
                        }
                    }
                }
                .navigationTitle("واجهة المتجر")
                .toolbar { Button("تم") { showingCountries = false } }
            }
            .navigationViewStyle(.stack)
        }
        .navigationBarHidden(true)
        .onChange(of: country) { _ in runSearch() }
        .onChange(of: requestedSearch) { link in
            guard let link = link else { return }
            requestedSearch = nil
            query = link
            runSearch()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Button(action: runSearch) {
                Image(systemName: "magnifyingglass").font(.headline)
            }
            .accessibilityLabel("بحث")
            TextField("اسم التطبيق أو معرّف الحزمة أو الرابط", text: $query)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(runSearch)
            if !query.isEmpty {
                Button {
                    query = ""
                    searchTask?.cancel()
                    loading = false
                    results = []
                    message = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .accessibilityLabel("مسح البحث")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.14)))
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private func resultRow(_ app: StoreApp) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: app.artworkUrl100) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "app.fill")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.tertiarySystemFill))
            }
            .frame(width: 55, height: 55)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(app.trackName).font(.headline).foregroundColor(.primary).lineLimit(2)
                let bytes = app.fileSizeBytes.flatMap { Int64($0) }
                let details = [
                    app.version.map { "v\($0)" },
                    app.minimumOsVersion.map { "iOS \($0)" },
                    bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
                ].compactMap { $0 }.joined(separator: " • ")
                if !details.isEmpty {
                    Text(details).font(.footnote).foregroundColor(.secondary)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func appDetails(_ app: StoreApp) -> some View {
        List {
            resultRow(app)
            Text(app.bundleId).textSelection(.enabled)
            if let url = app.trackViewUrl, url.scheme == "https", url.host == "apps.apple.com" {
                Link("عرض في App Store", destination: url)
            }
        }
        .navigationTitle(app.trackName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func runSearch() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        searchFocused = false
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
