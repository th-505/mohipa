import SwiftUI
import UniformTypeIdentifiers
import UIKit

@main
struct MohipaApp: App {
    var body: some Scene {
        WindowGroup {
            MohipaHome().environment(\.layoutDirection, .rightToLeft)
        }
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let file: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [file], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
