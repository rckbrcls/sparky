import SwiftUI

struct MemoryFilterSummaryButton: View {
    let activeFilterCount: Int
    let filterDescription: String
    let isSheetPresented: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    init(
        activeFilterCount: Int,
        filterDescription: String,
        isSheetPresented: Bool,
        isDisabled: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.activeFilterCount = activeFilterCount
        self.filterDescription = filterDescription
        self.isSheetPresented = isSheetPresented
        self.isDisabled = isDisabled
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            Label(filterDescription, systemImage: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .labelStyle(.iconOnly)
                .symbolEffect(.bounce, value: activeFilterCount)
                .foregroundStyle(activeFilterCount > 0 ? Color.accent : .primary)
            .animation(.easeInOut(duration: 0.2), value: activeFilterCount)
        }
        .disabled(isDisabled)
    }
}
