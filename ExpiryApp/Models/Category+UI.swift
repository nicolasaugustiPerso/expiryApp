import SwiftUI

extension Category {
    var displayName: String {
        if name.hasPrefix("category.") {
            let localized = L(name)
            return localized.hasPrefix("category.") ? name.replacingOccurrences(of: "category.", with: "").capitalized : localized
        }
        return name
    }

    var tintColor: Color {
        Color(hex: tintColorHex) ?? .blue
    }
}

extension String {
    var isLikelyEmojiIcon: Bool {
        if isEmpty { return false }
        if contains(".") || contains("/") { return false }
        return unicodeScalars.contains { $0.properties.isEmojiPresentation }
            || unicodeScalars.allSatisfy { $0.properties.isEmoji }
    }
}

struct CategorySymbolView: View {
    let symbolName: String
    var tint: Color = .primary
    var font: Font = .body
    var width: CGFloat? = nil

    var body: some View {
        Group {
            if symbolName.isLikelyEmojiIcon {
                Text(symbolName)
                    .font(font)
            } else {
                Image(systemName: symbolName)
                    .font(font)
                    .foregroundStyle(tint)
            }
        }
        .frame(width: width)
    }
}

extension Color {
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }

        guard sanitized.count == 6,
              let rgb = UInt64(sanitized, radix: 16) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self = Color(red: r, green: g, blue: b)
    }
}
