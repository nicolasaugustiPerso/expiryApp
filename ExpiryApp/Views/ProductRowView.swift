import SwiftUI

struct ProductRowView: View {
    let product: Product
    let effectiveExpiry: Date
    let onToggleOpened: (() -> Void)?
    let onConsumeOne: (() -> Void)?

    init(
        product: Product,
        effectiveExpiry: Date,
        onToggleOpened: (() -> Void)? = nil,
        onConsumeOne: (() -> Void)? = nil
    ) {
        self.product = product
        self.effectiveExpiry = effectiveExpiry
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

                Text(effectiveExpiry, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

            if onToggleOpened != nil {
                Button {
                    onToggleOpened?()
                } label: {
                    Image(systemName: isOpened ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isOpened ? .green : .blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("product.open"))
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
}
