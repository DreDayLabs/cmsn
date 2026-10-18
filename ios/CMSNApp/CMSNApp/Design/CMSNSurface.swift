import SwiftUI

/// v01 surfaces. Cards are a solid step from black to `#111111`, with a
/// continuous corner and no hairline. Chips and buttons are pills.
enum CMSNSurfaceStyle {
    static let cornerRadius: CGFloat = 20
    static let chipCornerRadius: CGFloat = 100

    static let fill = CMSNColor.Semantic.surface
    static let fillPressed = CMSNColor.Semantic.surfacePressed
    static let edge = CMSNColor.Semantic.border
    static let edgeSelected = CMSNColor.Semantic.textPrimary
}

private struct CMSNCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous)
                    .fill(CMSNSurfaceStyle.fill)
            )
    }
}

/// Selected chips invert to white. Unselected chips are a `#1A1A1A` pill.
private struct CMSNChipModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                Capsule()
                    .fill(isSelected ? CMSNColor.white : CMSNSurfaceStyle.fillPressed)
            )
    }
}

/// Wrapping row of pills. Measurement and placement share one width so a
/// wrapped row cannot be reserved as empty space and then clipped.
struct CMSNFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = resolvedWidth(proposal: proposal)
        let rows = rows(for: subviews, maxWidth: width)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height(of: rows))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.view.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    /// A nil or enormous proposal is the ideal-size pass. A flexible frame
    /// keeps that height and then places the row in a narrower bounds, which
    /// clips every wrapped line. Measure those passes at a phone content
    /// width so the second row is reserved.
    private func resolvedWidth(proposal: ProposedViewSize) -> CGFloat {
        if let width = proposal.width, width.isFinite, width > 0, width < 4_000 {
            return width
        }
        return 360
    }

    private func height(of rows: [Row]) -> CGFloat {
        let spacingTotal = spacing * CGFloat(max(rows.count - 1, 0))
        return rows.reduce(0) { $0 + $1.height } + spacingTotal
    }

    private struct Item {
        var view: LayoutSubview
        var size: CGSize
    }

    private struct Row {
        var items: [Item]
        var width: CGFloat
        var height: CGFloat
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current: [Item] = []
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            let next = current.isEmpty ? size.width : rowWidth + spacing + size.width
            if next > maxWidth, !current.isEmpty {
                rows.append(Row(items: current, width: rowWidth, height: rowHeight))
                current = []
                rowWidth = 0
                rowHeight = 0
            }
            current.append(Item(view: view, size: size))
            rowWidth = current.count == 1 ? size.width : rowWidth + spacing + size.width
            rowHeight = max(rowHeight, size.height)
        }
        if !current.isEmpty {
            rows.append(Row(items: current, width: rowWidth, height: rowHeight))
        }
        return rows
    }
}

/// Shared top of the revamp screens: the CMSN// mark, an optional trailing
/// meta line, and a system-font page title. Display type stays on the
/// headlines inside the screen, not on this title.
struct CMSNScreenHeader: View {
    var title: String
    var trailing: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                CMSNWordmark(height: 16)
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 15))
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                        .lineLimit(1)
                }
            }
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(CMSNColor.Semantic.textPrimary)
        }
    }
}

extension View {
    func cmsnCard() -> some View { modifier(CMSNCardModifier()) }
    func cmsnChip(isSelected: Bool) -> some View { modifier(CMSNChipModifier(isSelected: isSelected)) }
}
