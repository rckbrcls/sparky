import SwiftUI

struct MemoryWeekdaySelectionView: View {
    @Binding var selectedDays: Set<Int>
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...7, id: \.self) { day in
                    let isSelected = selectedDays.contains(day)
                    Button {
                        toggle(day)
                    } label: {
                        GeometryReader { proxy in
                            let diameter = proxy.size.width
                            Circle()
                                .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                                .overlay(
                                    Text(symbol(for: day))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                                )
                                .frame(width: diameter, height: diameter)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .accessibilityLabel(fullName(for: day))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var summaryText: String {
        if selectedDays.isEmpty {
            return "No weekdays selected."
        }
        let mask = selectedDays.reduce(into: Int16(0)) { result, day in
            result |= Int16(1 << day)
        }
        return weekdayMaskSummary(mask: mask)
    }

    private func toggle(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }

    private func symbol(for day: Int) -> String {
        let formatter = DateFormatter()
        let symbols = formatter.veryShortWeekdaySymbols ?? []
        guard !symbols.isEmpty else { return "" }
        return symbols[(day - 1) % symbols.count]
    }

    private func fullName(for day: Int) -> String {
        let formatter = DateFormatter()
        let symbols = formatter.weekdaySymbols ?? []
        guard !symbols.isEmpty else { return "" }
        return symbols[(day - 1) % symbols.count]
    }
}


