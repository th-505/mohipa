import Foundation
import ZIPFoundation

struct IPAInspection {
    let name: String?
    let bundleID: String
    let version: String?
    let build: String?
    let minimumOS: String?

    static func read(_ url: URL) throws -> IPAInspection {
        guard let archive = try? Archive(url: url, accessMode: .read),
              let entry = archive.first(where: isApplicationInfo) else {
            throw InspectionError.invalidPackage
        }

        let metadataLimit = 1_048_576
        guard entry.uncompressedSize <= metadataLimit else {
            throw InspectionError.invalidPackage
        }

        var data = Data()
        let checksum = try archive.extract(entry) { chunk in
            guard chunk.count <= metadataLimit - data.count else {
                throw InspectionError.invalidPackage
            }
            data.append(chunk)
        }
        guard checksum == entry.checksum,
              let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String,
              !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw InspectionError.invalidPackage
        }
        return IPAInspection(name: (plist["CFBundleDisplayName"] ?? plist["CFBundleName"]) as? String,
                             bundleID: bundleID,
                             version: plist["CFBundleShortVersionString"] as? String,
                             build: plist["CFBundleVersion"] as? String,
                             minimumOS: plist["MinimumOSVersion"] as? String)
    }

    private static func isApplicationInfo(_ entry: Entry) -> Bool {
        let path = entry.path.split(separator: "/", omittingEmptySubsequences: false)
        return entry.type == .file && path.count == 3 && path[0] == "Payload" &&
            path[1].hasSuffix(".app") && path[2] == "Info.plist"
    }
}

private enum InspectionError: LocalizedError {
    case invalidPackage

    var errorDescription: String? {
        "ما أمكن قراءة بيانات تطبيق صالحة داخل ملف IPA."
    }
}
