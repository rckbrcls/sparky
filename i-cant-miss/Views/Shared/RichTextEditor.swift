//
//  RichTextEditor.swift
//  i-cant-miss
//
//  Created by Codex on 26/03/24.
//

import Combine
import SwiftUI
import UIKit

private extension NSAttributedString.Key {
    static let memoryAttachmentID = NSAttributedString.Key("memoryAttachmentID")
}

/// UIKit-backed rich text editor that understands inline Memory attachments and keeps the SwiftUI view model in sync.
struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    var attachments: [MemoryModel.Attachment]
    var formatter: MemoryRichTextFormatter
    @ObservedObject var controller: RichTextEditorController
    var onReferencedAttachmentChange: (Set<UUID>) -> Void

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
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        textView.formatter = formatter
        textView.baseFont = baseFont
        textView.typingAttributes = textView.defaultTextAttributes
        _ = textView.updateIfNeeded(text: text, attachments: attachments, maintainSelection: false)
        controller.attach(textView)
        return textView
    }

    func updateUIView(_ uiView: RichTextView, context: Context) {
        context.coordinator.parent = self
        if uiView.formatter == nil {
            uiView.formatter = formatter
        }
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        uiView.baseFont = baseFont

        context.coordinator.isProgrammaticChange = true
        _ = uiView.updateIfNeeded(text: text,
                                  attachments: attachments,
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

            let (text, referenced) = parent.formatter.textString(from: textView.attributedText)
            if parent.text != text {
                parent.text = text
            }
            parent.onReferencedAttachmentChange(referenced)
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
    nonisolated let objectWillChange = ObservableObjectPublisher()
    fileprivate weak var textView: RichTextView?
    fileprivate(set) var selectedRange: NSRange = NSRange(location: 0, length: 0)

    func attach(_ textView: RichTextView) {
        self.textView = textView
        restoreSelection(on: textView)
    }

    func updateSelection(from textView: RichTextView) {
        selectedRange = normalizedRange(for: textView, range: textView.selectedRange)
    }

    @discardableResult
    func insertAttachment(_ attachment: MemoryModel.Attachment) -> Bool {
        guard let textView else { return false }
        restoreSelection(on: textView)
        if !textView.isFirstResponder {
            textView.becomeFirstResponder()
        }
        textView.insertAttachment(attachment)
        updateSelection(from: textView)
        objectWillChange.send()
        return true
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

/// UITextView subclass that keeps rich text + attachment state aligned with SwiftUI bindings.
final class RichTextView: UITextView {
    var formatter: MemoryRichTextFormatter?
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
    private var lastAttachmentIDs: [UUID] = []

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
                        attachments: [MemoryModel.Attachment],
                        maintainSelection: Bool) -> Bool {
        guard let formatter else { return false }

        let attachmentIDs = attachments.map(\.id)
        let shouldUpdate = text != lastAppliedText || attachmentIDs != lastAttachmentIDs
        guard shouldUpdate else { return false }

        let currentSelection = selectedRange
        let (attributedText, _) = formatter.makeAttributedString(from: text,
                                                                 attachments: attachments,
                                                                 baseFont: baseFont)

        isPerformingProgrammaticUpdate = true
        self.attributedText = attributedText
        typingAttributes = defaultTextAttributes
        if maintainSelection {
            let location = min(currentSelection.location, textStorage.length)
            selectedRange = NSRange(location: location, length: 0)
        } else {
            selectedRange = NSRange(location: textStorage.length, length: 0)
        }
        isPerformingProgrammaticUpdate = false
        lastAppliedText = text
        lastAttachmentIDs = attachmentIDs
        return true
    }

    func insertAttachment(_ attachment: MemoryModel.Attachment) {
        guard let image = UIImage(data: attachment.data) else { return }

        let newAttachment = MemoryImageAttachment(id: attachment.id, image: image)
        let insertionRange = selectedRange
        let mutable = NSMutableAttributedString()

        if shouldPrependLineBreak(before: insertionRange.location) {
            mutable.append(NSAttributedString(string: "\n", attributes: defaultTextAttributes))
        }
        let attachmentString = NSMutableAttributedString(attachment: newAttachment)
        attachmentString.addAttribute(.memoryAttachmentID,
                                      value: attachment.id as NSUUID,
                                      range: NSRange(location: 0, length: attachmentString.length))
        mutable.append(attachmentString)
        mutable.append(NSAttributedString(string: "\n", attributes: defaultTextAttributes))

        isPerformingProgrammaticUpdate = true
        textStorage.replaceCharacters(in: insertionRange, with: mutable)
        let newCursorLocation = insertionRange.location + mutable.length
        selectedRange = NSRange(location: min(newCursorLocation, textStorage.length), length: 0)
        typingAttributes = defaultTextAttributes
        isPerformingProgrammaticUpdate = false

        lastAppliedText = ""
        lastAttachmentIDs = []
        delegate?.textViewDidChange?(self)
    }

    private func shouldPrependLineBreak(before index: Int) -> Bool {
        guard index > 0 else { return false }
        let nsString = textStorage.string as NSString
        let previousCharacter = nsString.character(at: index - 1)
        return previousCharacter != 10 && previousCharacter != 13
    }
}

final class MemoryImageAttachment: NSTextAttachment {
    let attachmentID: UUID

    init(id: UUID, image: UIImage) {
        self.attachmentID = id
        super.init(data: nil, ofType: nil)
        self.image = image
    }

    required init?(coder: NSCoder) {
        self.attachmentID = UUID()
        super.init(coder: coder)
    }

    override func attachmentBounds(for textContainer: NSTextContainer?,
                                   proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint,
                                   characterIndex charIndex: Int) -> CGRect {
        guard let image else {
            return super.attachmentBounds(for: textContainer,
                                          proposedLineFragment: lineFrag,
                                          glyphPosition: position,
                                          characterIndex: charIndex)
        }

        let maxWidth: CGFloat
        if let textContainer {
            maxWidth = textContainer.size.width - textContainer.lineFragmentPadding * 2
        } else if lineFrag.width > 0 {
            maxWidth = lineFrag.width
        } else {
            maxWidth = 320
        }
        let scale = min(maxWidth / max(image.size.width, 1), 1.0)
        let width = image.size.width * scale
        let height = image.size.height * scale
        return CGRect(x: 0, y: 4, width: width, height: height)
    }
}

struct MemoryRichTextFormatter {
    private static let attachmentPattern = #"\!\[attachment\]\(memory-attachment:([0-9a-fA-F-]+)\)"#
    private static let attachmentRegex: NSRegularExpression = {
        let expression = try? NSRegularExpression(pattern: attachmentPattern, options: [])
        return expression ?? NSRegularExpression()
    }()

    static func attachmentToken(for id: UUID) -> String {
        "![attachment](memory-attachment:\(id.uuidString.lowercased()))"
    }

    func makeAttributedString(from text: String,
                              attachments: [MemoryModel.Attachment],
                              baseFont: UIFont) -> (NSMutableAttributedString, Set<UUID>) {
        let attributed = NSMutableAttributedString(string: text,
                                                   attributes: [
                                                    .font: baseFont,
                                                    .foregroundColor: UIColor.label
                                                   ])
        let nsString = text as NSString
        var usedAttachmentIDs = Set<UUID>()
        let attachmentMap = Dictionary(uniqueKeysWithValues: attachments.map { ($0.id, $0) })
        let matches = Self.attachmentRegex.matches(in: text,
                                                   options: [],
                                                   range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            let idRange = match.range(at: 1)
            let identifier = nsString.substring(with: idRange)
            guard let uuid = UUID(uuidString: identifier.lowercased()) else { continue }
            guard let attachment = attachmentMap[uuid],
                  let image = UIImage(data: attachment.data) else { continue }

            usedAttachmentIDs.insert(uuid)
            let attachmentText = NSMutableAttributedString(attachment: MemoryImageAttachment(id: uuid, image: image))
            attachmentText.addAttribute(.memoryAttachmentID,
                                        value: uuid as NSUUID,
                                        range: NSRange(location: 0, length: attachmentText.length))
            attributed.replaceCharacters(in: match.range, with: attachmentText)
        }

        return (attributed, usedAttachmentIDs)
    }

    func textString(from attributed: NSAttributedString) -> (String, Set<UUID>) {
        var result = ""
        var usedIDs = Set<UUID>()

        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length),
                                       options: []) { attributes, range, _ in
            if let attachmentID = Self.attachmentID(from: attributes) {
                let token = Self.attachmentToken(for: attachmentID)
                result.append(token)
                usedIDs.insert(attachmentID)
            } else {
                let substring = attributed.attributedSubstring(from: range).string
                result.append(substring)
            }
        }

        return (result, usedIDs)
    }

    private static func attachmentID(from attributes: [NSAttributedString.Key: Any]) -> UUID? {
        if let uuid = attributes[.memoryAttachmentID] as? UUID {
            return uuid
        }
        if let nsuuid = attributes[.memoryAttachmentID] as? NSUUID {
            return nsuuid as UUID
        }
        if let string = attributes[.memoryAttachmentID] as? String,
           let uuid = UUID(uuidString: string) {
            return uuid
        }
        if let attachment = attributes[.attachment] as? MemoryImageAttachment {
            return attachment.attachmentID
        }
        return nil
    }
}
