import SwiftUI

enum ProductRowSubtitleStyle {
    case expiryDate
    case openedStatus
}

struct ProductRowView: View {
    let product: Product
    let effectiveExpiry: Date
    let subtitleStyle: ProductRowSubtitleStyle
    let onToggleOpened: (() -> Void)?
    let onConsumeOne: (() -> Void)?

    init(
        product: Product,
        effectiveExpiry: Date,
        subtitleStyle: ProductRowSubtitleStyle = .expiryDate,
        onToggleOpened: (() -> Void)? = nil,
        onConsumeOne: (() -> Void)? = nil
    ) {
        self.product = product
        self.effectiveExpiry = effectiveExpiry
        self.subtitleStyle = subtitleStyle
        self.onToggleOpened = onToggleOpened
        self.onConsumeOne = onConsumeOne
    }

    private var days: Int {
        ExpiryCalculator.daysUntilExpiry(effectiveExpiry)
    }
    
    private var isOpened: Bool {
        product.openedAt != nil
    }

    private var stateColor: Color {
        if days < 0 { return .red }
        if days <= 2 { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: product.category.symbolName)
                .font(.title3)
                .foregroundStyle(stateColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(localizedProductName(product.name))
                        .font(.headline)
                    Text("x\(product.quantity)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(spacing: 6) {
                    if onToggleOpened != nil {
                        Button {
                            onToggleOpened?()
                        } label: {
                            Image(systemName: isOpened ? "checkmark.square.fill" : "square")
                                .foregroundStyle(isOpened ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("product.open"))
                    }

                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
            }

            Spacer()

            Text(daysLabel)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(stateColor.opacity(0.15))
                .clipShape(Capsule())

            if onConsumeOne != nil {
                Button {
                    onConsumeOne?()
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("product.consume_one"))
            }

        }
    }

    private var daysLabel: String {
        if days < 0 {
            return L("status.expired")
        }

        if days == 0 {
            return L("status.today")
        }

        let format = L("status.in_days")
        return String(format: format, days)
    }

    private var subtitleText: String {
        switch subtitleStyle {
        case .expiryDate:
            return effectiveExpiry.formatted(date: .long, time: .omitted)
        case .openedStatus:
            guard let openedAt = product.openedAt else {
                return L("product.not_opened")
            }
            let format = L("product.opened_on")
            let shortDate = openedAt.formatted(.dateTime.day().month(.abbreviated))
            return String(format: format, shortDate)
        }
    }
}
