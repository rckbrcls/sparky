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
        Button(action: onTap) {
            Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .symbolEffect(.bounce, value: activeFilterCount)
                .foregroundStyle(activeFilterCount > 0 ? Color.accent : .primary)
                .animation(.easeInOut(duration: 0.2), value: activeFilterCount)
                .padding(paddingInsets)
                .glassEffect(.regular.interactive())
        }
        .disabled(isDisabled)
    }
}
