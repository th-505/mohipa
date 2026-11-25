import Foundation

struct AppStoreLink {
    let url: URL
    let appID: String
    let country: String?

    init?(_ input: String) {
        guard let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              (url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "http"),
              url.host?.lowercased() == "apps.apple.com",
              url.user == nil, url.password == nil else { return nil }
        let path = url.path.split(separator: "/")
        guard let appIndex = path.firstIndex(of: "app"),
              let last = path.last, last.hasPrefix("id"),
              let id = Int64(last.dropFirst(2)), id > 0 else { return nil }
        self.url = url
        self.appID = String(id)
        let region = appIndex == 1 ? path.first.map { $0.uppercased() } : nil
        self.country = region.flatMap { Locale.isoRegionCodes.contains($0) ? $0 : nil }
    }
}
