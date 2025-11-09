import SwiftUI

extension LocationPickerView {
    struct EventSection: View {
        @Binding var event: LocationEvent
        let description: String

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("When should we remind you?")
                    .font(.headline)

                Picker("Event", selection: $event) {
                    ForEach(LocationEvent.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
        }
    }
}
