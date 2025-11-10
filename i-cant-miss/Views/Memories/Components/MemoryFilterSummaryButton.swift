import SwiftUI

struct MemoryFilterSummaryButton: View {
    let activeFilterCount: Int
    let filterDescription: String
    let isSheetPresented: Bool
    let isDisabled: Bool
    var paddingInsets: EdgeInsets
    let onTap: () -> Void

    init(
        activeFilterCount: Int,
        filterDescription: String,
        isSheetPresented: Bool,
        isDisabled: Bool = false,
        paddingInsets: EdgeInsets = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10),
        onTap: @escaping () -> Void
    ) {
        self.activeFilterCount = activeFilterCount
        self.filterDescription = filterDescription
        self.isSheetPresented = isSheetPresented
        self.isDisabled = isDisabled
        self.paddingInsets = paddingInsets
        self.onTap = onTap
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .symbolEffect(.bounce, value: activeFilterCount)
                Text(filterDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: filterDescription)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .rotationEffect(.degrees(isSheetPresented ? 180 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSheetPresented)
            }
            .foregroundStyle(activeFilterCount > 0 ? Color.accent : .primary)
            .animation(.easeInOut(duration: 0.2), value: activeFilterCount)
            .padding(paddingInsets)
            .glassEffect(.regular.interactive())
        }
        .disabled(isDisabled)
    }
}
