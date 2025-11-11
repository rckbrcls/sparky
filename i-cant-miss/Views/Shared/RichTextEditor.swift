//
//  RichTextEditor.swift
//  i-cant-miss
//
//  Created by Codex on 26/03/24.
//

import Combine
import SwiftUI
import UIKit

/// UIKit-backed rich text editor that keeps the SwiftUI view model in sync for plain text.
struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @ObservedObject var controller: RichTextEditorController

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> RichTextView {
        let textView = RichTextView()
        textView.delegate = context.coordinator
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.backgroundColor = .clear
        textView.keyboardDismissMode = .interactive
        textView.isScrollEnabled = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.baseFont = UIFont.preferredFont(forTextStyle: .body)
        textView.typingAttributes = textView.defaultTextAttributes
        _ = textView.updateIfNeeded(text: text, maintainSelection: false)
        controller.attach(textView)
        return textView
    }

    func updateUIView(_ uiView: RichTextView, context: Context) {
        context.coordinator.parent = self
        uiView.baseFont = UIFont.preferredFont(forTextStyle: .body)

        context.coordinator.isProgrammaticChange = true
        _ = uiView.updateIfNeeded(text: text,
                                  maintainSelection: !context.coordinator.didProgrammaticallyUpdateSelection)
        context.coordinator.isProgrammaticChange = false
        controller.updateSelection(from: uiView)
        controller.attach(uiView)
    }
}

extension RichTextEditor {
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var isProgrammaticChange = false
        var didProgrammaticallyUpdateSelection = false

        init(parent: RichTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isProgrammaticChange,
                  let textView = textView as? RichTextView,
                  !textView.isPerformingProgrammaticUpdate else {
                return
            }
            parent.text = textView.text ?? ""
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let textView = textView as? RichTextView else { return }
            parent.controller.updateSelection(from: textView)
            didProgrammaticallyUpdateSelection = false
        }
    }
}

@MainActor
final class RichTextEditorController: ObservableObject {
    fileprivate weak var textView: RichTextView?
    fileprivate(set) var selectedRange: NSRange = NSRange(location: 0, length: 0)

    func attach(_ textView: RichTextView) {
        self.textView = textView
        restoreSelection(on: textView)
    }

    func updateSelection(from textView: RichTextView) {
        selectedRange = normalizedRange(for: textView, range: textView.selectedRange)
    }

    private func restoreSelection(on textView: RichTextView) {
        let range = normalizedRange(for: textView, range: selectedRange)
        if textView.selectedRange != range {
            textView.selectedRange = range
        }
    }

    private func normalizedRange(for textView: RichTextView, range: NSRange) -> NSRange {
        let length = textView.textStorage.length
        let clampedLocation = max(0, min(range.location, length))
        return NSRange(location: clampedLocation, length: 0)
    }
}

/// UITextView subclass that keeps rich text state aligned with SwiftUI bindings.
final class RichTextView: UITextView {
    var baseFont: UIFont = UIFont.preferredFont(forTextStyle: .body) {
        didSet {
            typingAttributes = defaultTextAttributes
        }
    }

    var defaultTextAttributes: [NSAttributedString.Key: Any] {
        [
            .font: baseFont,
            .foregroundColor: UIColor.label
        ]
    }

    private(set) var isPerformingProgrammaticUpdate = false
    private var lastAppliedText: String = ""

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .clear
        textContainerInset = UIEdgeInsets(top: 8, left: -4, bottom: 8, right: 0)
        textContainer.lineFragmentPadding = 0
        typingAttributes = defaultTextAttributes
    }

    @discardableResult
    func updateIfNeeded(text: String,
                        maintainSelection: Bool) -> Bool {
        let shouldUpdate = text != lastAppliedText
        guard shouldUpdate else { return false }

        let currentSelection = selectedRange

        isPerformingProgrammaticUpdate = true
        self.text = text
        typingAttributes = defaultTextAttributes
        if maintainSelection {
            let location = min(currentSelection.location, textStorage.length)
            selectedRange = NSRange(location: location, length: 0)
        } else {
            selectedRange = NSRange(location: textStorage.length, length: 0)
        }
        isPerformingProgrammaticUpdate = false
        lastAppliedText = text
        return true
    }
}
