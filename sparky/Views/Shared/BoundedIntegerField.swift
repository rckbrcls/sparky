import SwiftUI

struct BoundedIntegerField: View {
    @Binding private var value: Int

    private let range: ClosedRange<Int>
    private let accessibilityLabel: String

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        accessibilityLabel: String
    ) {
        _value = value
        self.range = range
        self.accessibilityLabel = accessibilityLabel
        _text = State(initialValue: String(value.wrappedValue))
    }

    var body: some View {
        TextField("", text: $text)
            .multilineTextAlignment(.center)
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: 56)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.Theme.elementBackground)
            )
            .focused($isFocused)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(String(value))
            .onChange(of: text) { _, newText in
                updateValue(from: newText)
            }
            .onChange(of: value) { _, newValue in
                guard !isFocused else { return }
                text = String(newValue)
            }
            .onChange(of: isFocused) { _, hasFocus in
                if !hasFocus {
                    commitText()
                }
            }
    }

    private func updateValue(from newText: String) {
        let sanitizedText = String(newText.filter(\.isNumber))

        if sanitizedText != newText {
            text = sanitizedText
            return
        }

        guard let newValue = Int(sanitizedText) else {
            return
        }

        value = min(max(newValue, range.lowerBound), range.upperBound)
    }

    private func commitText() {
        guard let enteredValue = Int(text) else {
            text = String(value)
            return
        }

        let clampedValue = min(max(enteredValue, range.lowerBound), range.upperBound)
        value = clampedValue
        text = String(clampedValue)
    }
}
