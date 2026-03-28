import SwiftUI

extension ProductCategory {
    var tintColor: Color {
        switch self {
        case .fruit: return .red
        case .vegetable: return .green
        case .bread: return .orange
        case .milk: return .blue
        case .cheese: return .yellow
        case .yogurt: return .teal
        case .meat: return .brown
        case .fish: return .cyan
        case .frozen: return .mint
        case .pantry: return .gray
        case .other: return .gray
        }
    }
}
