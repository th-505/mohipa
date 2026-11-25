import Foundation

enum IPALibrary {
    private static func directory() throws -> URL {
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
    }

    private static func availableDestination(in directory: URL, named name: String) -> URL {
        let manager = FileManager.default
        let filename = name as NSString
        var destination = directory.appendingPathComponent(name)
        var suffix = 2
        while manager.fileExists(atPath: destination.path) {
            let uniqueName = "\(filename.deletingPathExtension) (\(suffix)).ipa"
            destination = directory.appendingPathComponent(uniqueName)
            suffix += 1
        }
        return destination
    }

    private static func migrateLegacyFiles(to documents: URL) throws {
        let manager = FileManager.default
        let support = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                      appropriateFor: nil, create: true)
        let legacy = support.appendingPathComponent("IPAFiles", isDirectory: true)
        guard manager.fileExists(atPath: legacy.path) else { return }
        for folder in try manager.contentsOfDirectory(at: legacy, includingPropertiesForKeys: nil) {
            guard UUID(uuidString: folder.lastPathComponent) != nil else { continue }
            let files = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension.lowercased() == "ipa" {
                let destination = availableDestination(in: documents, named: file.lastPathComponent)
                try manager.moveItem(at: file, to: destination)
            }
            if try manager.contentsOfDirectory(atPath: folder.path).isEmpty {
                try manager.removeItem(at: folder)
            }
        }
    }

    static func list() throws -> [URL] {
        let documents = try directory()
        try migrateLegacyFiles(to: documents)
        let files = try FileManager.default.contentsOfDirectory(
            at: documents, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        return files.filter {
            $0.pathExtension.lowercased() == "ipa" &&
                (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    static func save(_ source: URL, named name: String) throws {
        let filename = (name as NSString).lastPathComponent
        guard (filename as NSString).pathExtension.lowercased() == "ipa" else {
            throw IPAFileError.invalidFile
        }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { throw IPAFileError.invalidFile }
        let manager = FileManager.default
        let staging = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? manager.removeItem(at: staging) }
        try manager.copyItem(at: source, to: staging)
        _ = try IPAInspection.read(staging)
        let destination = try availableDestination(in: directory(), named: filename)
        try manager.moveItem(at: staging, to: destination)
    }

    static func download(_ input: String, checksum: String) async throws {
        let expected = try IPAChecksum.expected(checksum)
        guard let url = URL(string: input), isHTTPS(url) else { throw IPAFileError.invalidLink }
        let session = URLSession(configuration: .ephemeral, delegate: HTTPSRedirects(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (temporary, response) = try await session.download(from: url)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse,
              let finalURL = http.url, isHTTPS(finalURL) else {
            throw IPAFileError.downloadFailed
        }
        guard http.statusCode == 200 else {
            throw IPAFileError.serverStatus(http.statusCode)
        }
        let names = [response.suggestedFilename, finalURL.lastPathComponent, url.lastPathComponent]
        let name = names.compactMap { $0 }.first {
            ($0 as NSString).pathExtension.lowercased() == "ipa"
        }
        if let expected = expected { try IPAChecksum.verify(temporary, expected: expected) }
        try Task.checkCancellation()
        try save(temporary, named: name ?? "تنزيل.ipa")
    }

    fileprivate static func isHTTPS(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.host != nil && url.user == nil && url.password == nil
    }
}

private final class HTTPSRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url, IPALibrary.isHTTPS(url) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

private enum IPAFileError: LocalizedError {
    case invalidLink, invalidFile, downloadFailed
    case serverStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidLink: return "أدخل رابط HTTPS مباشر لملف IPA."
        case .invalidFile: return "اختر ملفًا عاديًا بامتداد IPA."
        case .downloadFailed: return "استجابة مصدر التنزيل غير صالحة."
        case .serverStatus(401), .serverStatus(403):
            return "مصدر التنزيل رفض الوصول. تأكد من صلاحية الرابط."
        case .serverStatus(404), .serverStatus(410):
            return "الملف غير متاح على هذا الرابط."
        case .serverStatus(429):
            return "مصدر التنزيل تلقّى طلبات كثيرة. جرّب بعد قليل."
        case .serverStatus(let status):
            return "مصدر التنزيل أعاد خطأ HTTP \(status)."
        }
    }
}
