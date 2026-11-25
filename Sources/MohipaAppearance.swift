import SwiftUI

enum MohipaAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: return "اتباع النظام"
        case .light: return "فاتح"
        case .dark: return "داكن"
        }
    }

    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct MohipaAccountsView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image("MohipaMark")
                            .resizable()
                            .frame(width: 52, height: 52)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("mohipa").font(.headline)
                            Text("ربط حساب Apple داخل التطبيق غير متاح حاليًا.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let url = URL(string: "https://account.apple.com/") {
                        Link(destination: url) {
                            Label("إدارة حساب Apple", systemImage: "arrow.up.right.square")
                        }
                    }
                }
            }
            .navigationTitle("الحسابات")
        }
        .navigationViewStyle(.stack)
    }
}
