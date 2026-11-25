import SwiftUI
import UniformTypeIdentifiers

private struct LocalIPA: Identifiable {
    let url: URL
    var id: URL { url }
}

struct IPAFileView: View {
    @State private var importing = false
    @State private var files: [LocalIPA] = []
    @State private var sharing: LocalIPA?
    @State private var preview: LocalIPA?
    @State private var pendingDeletion: LocalIPA?
    @State private var sourceLink = ""
    @State private var expectedChecksum = ""
    @State private var downloadTask: Task<Void, Never>?
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            List {
                Section("إضافة ملف") {
                    Button("استيراد من الملفات") { importing = true }
                    TextField("رابط HTTPS مباشر لملف IPA", text: $sourceLink)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .environment(\.layoutDirection, .leftToRight)
                    TextField("بصمة SHA-256 من المصدر (اختياري)", text: $expectedChecksum)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .environment(\.layoutDirection, .leftToRight)
                    if let downloadTask = downloadTask {
                        ProgressView("جارٍ التنزيل…")
                        Button("إلغاء التنزيل") { downloadTask.cancel() }
                    } else {
                        Button("تنزيل الملف") { startDownload() }
                            .disabled(sourceLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if let errorMessage = errorMessage {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
                Section("المكتبة") {
                    Text("الملفات ← تصفح ← على الـ iPhone ← mohipa")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    if files.isEmpty {
                        Text("ما فيه ملفات محفوظة").foregroundColor(.secondary)
                    }
                    ForEach(files) { file in
                        Button {
                            sharing = file
                        } label: {
                            Label(file.url.lastPathComponent, systemImage: "square.and.arrow.up")
                                .lineLimit(2)
                        }
                        .contextMenu {
                            Button {
                                preview = file
                            } label: {
                                Label("معاينة بيانات الحزمة", systemImage: "info.circle")
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) { pendingDeletion = file } label: {
                                Label("حذف", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .refreshable { perform { try reload() } }
            .navigationTitle("ملفات IPA")
        }
        .onAppear { perform { try reload() } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
            perform {
                let source = try result.get()
                let access = source.startAccessingSecurityScopedResource()
                defer { if access { source.stopAccessingSecurityScopedResource() } }
                try IPALibrary.save(source, named: source.lastPathComponent)
                try reload()
            }
        }
        .sheet(item: $sharing) { ActivitySheet(file: $0.url) }
        .sheet(item: $preview) { file in
            NavigationView {
                Form {
                    if let metadata = try? IPAInspection.read(file.url) {
                        Text(metadata.name ?? file.url.lastPathComponent)
                        Label(metadata.bundleID, systemImage: "tag")
                        if let version = metadata.version { Text("الإصدار \(version)") }
                        if let build = metadata.build { Text("رقم البناء \(build)") }
                        if let minimumOS = metadata.minimumOS { Text("يتطلب iOS \(minimumOS) أو أحدث") }
                    } else {
                        Text("ما أمكن قراءة بيانات الحزمة.")
                    }
                }
                .navigationTitle("بيانات الحزمة")
                .toolbar { Button("تم") { preview = nil } }
            }
        }
        .alert("حذف الملف؟", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), presenting: pendingDeletion) { file in
            Button("حذف", role: .destructive) {
                perform {
                    try FileManager.default.removeItem(at: file.url)
                    try reload()
                }
            }
            Button("إلغاء", role: .cancel) {}
        } message: { file in
            Text(file.url.lastPathComponent)
        }
    }

    private func reload() throws {
        files = try IPALibrary.list().map { LocalIPA(url: $0) }
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startDownload() {
        guard downloadTask == nil else { return }
        let input = sourceLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let checksum = expectedChecksum
        errorMessage = nil
        downloadTask = Task { @MainActor in
            defer { downloadTask = nil }
            do {
                try await IPALibrary.download(input, checksum: checksum)
                try reload()
            } catch is CancellationError {
                return
            } catch let error as URLError {
                switch error.code {
                case .cancelled:
                    return
                case .notConnectedToInternet, .networkConnectionLost:
                    errorMessage = "انقطع الاتصال. تأكد من الشبكة وجرّب التنزيل مرة ثانية."
                case .timedOut:
                    errorMessage = "انتهت مهلة الاتصال بمصدر التنزيل. جرّب مرة ثانية."
                default:
                    errorMessage = error.localizedDescription
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
