import SwiftUI

struct MemoryEditorAddLinkSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var urlString: String = ""
    @State private var validationMessage: String?

    var onAddLink: (URL) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("https://example.com", text: $urlString, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 12.0))
                        .onChange(of: urlString) { _, _ in
                            validationMessage = nil
                        }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
            }
            .padding()
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        handleAddLink()
                    }
                    .disabled(sanitizedURL == nil)
                }
            }
        }
    }

    private func handleAddLink() {
        guard let url = sanitizedURL else {
            validationMessage = "Enter a valid URL."
            return
        }
        onAddLink(url)
        dismiss()
    }

    private var sanitizedURL: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        if let httpsURL = URL(string: "https://\(trimmed)") {
            return httpsURL
        }

        return nil
    }
}
