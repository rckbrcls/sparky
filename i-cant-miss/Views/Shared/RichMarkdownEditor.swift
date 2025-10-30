//
//  RichMarkdownEditor.swift
//  i-cant-miss
//
//  Created by Codex on 26/03/24.
//

import Combine
import SwiftUI
import UIKit

/// UIKit-backed Markdown editor that understands inline Memory attachments and keeps the SwiftUI view model in sync.
struct RichMarkdownEditor: UIViewRepresentable {
    @Binding var text: String
    var attachments: [MemoryModel.Attachment]
    var formatter: MemoryRichTextFormatter
    @ObservedObject var controller: RichTextEditorController
    var onReferencedAttachmentChange: (Set<UUID>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> RichMarkdownTextView {
        let textView = RichMarkdownTextView()
        textView.delegate = context.coordinator
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.backgroundColor = .clear
        textView.keyboardDismissMode = .interactive
        textView.isScrollEnabled = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.formatter = formatter
        textView.syntaxHighlighter = MarkdownSyntaxHighlighter(baseFont: UIFont.preferredFont(forTextStyle: .body))
        _ = textView.updateIfNeeded(markdown: text, attachments: attachments, maintainSelection: false)
        controller.attach(textView)
        return textView
    }

    func updateUIView(_ uiView: RichMarkdownTextView, context: Context) {
        context.coordinator.parent = self
        if uiView.formatter == nil {
            uiView.formatter = formatter
        }
        if uiView.syntaxHighlighter == nil {
            uiView.syntaxHighlighter = MarkdownSyntaxHighlighter(baseFont: UIFont.preferredFont(forTextStyle: .body))
        }

        context.coordinator.isProgrammaticChange = true
        _ = uiView.updateIfNeeded(markdown: text,
                                  attachments: attachments,
                                  maintainSelection: !context.coordinator.didProgrammaticallyUpdateSelection)
        context.coordinator.isProgrammaticChange = false
        controller.attach(uiView)
    }
}

extension RichMarkdownEditor {
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichMarkdownEditor
        var isProgrammaticChange = false
        var didProgrammaticallyUpdateSelection = false

        init(parent: RichMarkdownEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isProgrammaticChange,
                  let textView = textView as? RichMarkdownTextView,
                  !textView.isPerformingProgrammaticUpdate else {
                return
            }

            let (markdown, referenced) = parent.formatter.markdownString(from: textView.attributedText)
            if parent.text != markdown {
                parent.text = markdown
            }
            parent.onReferencedAttachmentChange(referenced)
            textView.syntaxHighlighter?.apply(to: textView.textStorage)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let textView = textView as? RichMarkdownTextView else { return }
            parent.controller.selectedRange = textView.selectedRange
            didProgrammaticallyUpdateSelection = false
        }
    }
}

@MainActor
final class RichTextEditorController: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    fileprivate weak var textView: RichMarkdownTextView?
    fileprivate(set) var selectedRange: NSRange = NSRange(location: 0, length: 0)

    func attach(_ textView: RichMarkdownTextView) {
        self.textView = textView
    }

    @discardableResult
    func insertAttachment(_ attachment: MemoryModel.Attachment) -> Bool {
        guard let textView else { return false }
        textView.insertAttachment(attachment)
        selectedRange = textView.selectedRange
        objectWillChange.send()
        return true
    }
}

/// UITextView subclass that keeps Markdown + attachment state aligned with SwiftUI bindings.
final class RichMarkdownTextView: UITextView {
    var formatter: MemoryRichTextFormatter?
    var syntaxHighlighter: MarkdownSyntaxHighlighter?

    private(set) var isPerformingProgrammaticUpdate = false
    private var lastAppliedMarkdown: String = ""
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
    }

    @discardableResult
    func updateIfNeeded(markdown: String,
                        attachments: [MemoryModel.Attachment],
                        maintainSelection: Bool) -> Bool {
        guard let formatter, let syntaxHighlighter else { return false }

        let attachmentIDs = attachments.map(\.id)
        let shouldUpdate = markdown != lastAppliedMarkdown || attachmentIDs != lastAttachmentIDs
        guard shouldUpdate else { return false }

        let baseFont = syntaxHighlighter.baseFont
        let currentSelection = selectedRange
        let (attributedText, _) = formatter.makeAttributedString(from: markdown,
                                                                 attachments: attachments,
                                                                 baseFont: baseFont)

        isPerformingProgrammaticUpdate = true
        self.attributedText = attributedText
        syntaxHighlighter.apply(to: textStorage)
        if maintainSelection {
            let location = min(currentSelection.location, textStorage.length)
            selectedRange = NSRange(location: location, length: 0)
        } else {
            selectedRange = NSRange(location: textStorage.length, length: 0)
        }
        isPerformingProgrammaticUpdate = false
        lastAppliedMarkdown = markdown
        lastAttachmentIDs = attachmentIDs
        return true
    }

    func insertAttachment(_ attachment: MemoryModel.Attachment) {
        guard let syntaxHighlighter else { return }
        guard let image = UIImage(data: attachment.data) else { return }

        let newAttachment = MemoryImageAttachment(id: attachment.id, image: image)
        let insertionRange = selectedRange
        let mutable = NSMutableAttributedString()

        if shouldPrependLineBreak(before: insertionRange.location) {
            mutable.append(NSAttributedString(string: "\n"))
        }
        mutable.append(NSAttributedString(attachment: newAttachment))
        mutable.append(NSAttributedString(string: "\n"))

        isPerformingProgrammaticUpdate = true
        textStorage.replaceCharacters(in: insertionRange, with: mutable)
        let newCursorLocation = insertionRange.location + mutable.length
        selectedRange = NSRange(location: min(newCursorLocation, textStorage.length), length: 0)
        syntaxHighlighter.apply(to: textStorage)
        isPerformingProgrammaticUpdate = false

        lastAppliedMarkdown = ""
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

    func makeAttributedString(from markdown: String,
                              attachments: [MemoryModel.Attachment],
                              baseFont: UIFont) -> (NSMutableAttributedString, Set<UUID>) {
        let attributed = NSMutableAttributedString(string: markdown,
                                                   attributes: [
                                                    .font: baseFont,
                                                    .foregroundColor: UIColor.label
                                                   ])
        let nsString = markdown as NSString
        var usedAttachmentIDs = Set<UUID>()
        let attachmentMap = Dictionary(uniqueKeysWithValues: attachments.map { ($0.id, $0) })
        let matches = Self.attachmentRegex.matches(in: markdown,
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
            let attachmentText = NSAttributedString(attachment: MemoryImageAttachment(id: uuid, image: image))
            attributed.replaceCharacters(in: match.range, with: attachmentText)
        }

        return (attributed, usedAttachmentIDs)
    }

    func markdownString(from attributed: NSAttributedString) -> (String, Set<UUID>) {
        var markdown = ""
        var usedIDs = Set<UUID>()

        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length),
                                       options: []) { attributes, range, _ in
            if let attachment = attributes[.attachment] as? MemoryImageAttachment {
                let token = Self.attachmentToken(for: attachment.attachmentID)
                markdown.append(token)
                usedIDs.insert(attachment.attachmentID)
            } else {
                let substring = attributed.attributedSubstring(from: range).string
                markdown.append(substring)
            }
        }

        return (markdown, usedIDs)
    }
}

final class MarkdownSyntaxHighlighter {
    let baseFont: UIFont
    private let boldFont: UIFont
    private let italicFont: UIFont
    private let codeFont: UIFont
    private let headingFonts: [UIFont]
    private let bulletColor = UIColor.systemBlue
    private let codeBackground = UIColor.secondarySystemBackground

    init(baseFont: UIFont) {
        self.baseFont = baseFont
        self.boldFont = UIFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? baseFont.fontDescriptor,
                               size: baseFont.pointSize)
        self.italicFont = UIFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) ?? baseFont.fontDescriptor,
                                 size: baseFont.pointSize)
        self.codeFont = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.95, weight: .regular)
        self.headingFonts = (1...6).map { level in
            let multiplier = max(1.1, 1.5 - CGFloat(level - 1) * 0.1)
            return UIFont.systemFont(ofSize: baseFont.pointSize * multiplier, weight: .semibold)
        }
    }

    func apply(to textStorage: NSTextStorage) {
        guard textStorage.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.setAttributes([
            .font: baseFont,
            .foregroundColor: UIColor.label
        ], range: fullRange)

        applyHeadingHighlight(to: textStorage)
        applyBoldHighlight(to: textStorage)
        applyItalicHighlight(to: textStorage)
        applyInlineCodeHighlight(to: textStorage)
        applyBulletHighlight(to: textStorage)
    }

    private func applyHeadingHighlight(to textStorage: NSTextStorage) {
        let pattern = #"^(#{1,6})\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        let string = textStorage.string as NSString
        let matches = regex.matches(in: textStorage.string,
                                    options: [],
                                    range: NSRange(location: 0, length: string.length))

        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let levelRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let level = min(max(1, levelRange.length), headingFonts.count)
            let font = headingFonts[level - 1]
            textStorage.addAttributes([
                .font: font,
                .foregroundColor: UIColor.label
            ], range: levelRange)
            textStorage.addAttributes([
                .font: font,
                .foregroundColor: UIColor.label
            ], range: contentRange)
        }
    }

    private func applyBoldHighlight(to textStorage: NSTextStorage) {
        let pattern = #"\*\*(.+?)\*\*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let string = textStorage.string as NSString
        let matches = regex.matches(in: textStorage.string,
                                    options: [],
                                    range: NSRange(location: 0, length: string.length))

        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let contentRange = match.range(at: 1)
            textStorage.addAttributes([.font: boldFont], range: contentRange)
        }
    }

    private func applyItalicHighlight(to textStorage: NSTextStorage) {
        let pattern = #"(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let string = textStorage.string as NSString
        let matches = regex.matches(in: textStorage.string,
                                    options: [],
                                    range: NSRange(location: 0, length: string.length))

        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let contentRange = match.range(at: 1)
            textStorage.addAttributes([.font: italicFont], range: contentRange)
        }
    }

    private func applyInlineCodeHighlight(to textStorage: NSTextStorage) {
        let pattern = #"`([^`]+)`"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let string = textStorage.string as NSString
        let matches = regex.matches(in: textStorage.string,
                                    options: [],
                                    range: NSRange(location: 0, length: string.length))

        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let contentRange = match.range(at: 1)
            textStorage.addAttributes([
                .font: codeFont,
                .foregroundColor: UIColor.systemOrange
            ], range: contentRange)
            textStorage.addAttributes([
                .backgroundColor: codeBackground
            ], range: match.range)
        }
    }

    private func applyBulletHighlight(to textStorage: NSTextStorage) {
        let pattern = #"(?m)^\s*([-*+])\s+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let string = textStorage.string as NSString
        let matches = regex.matches(in: textStorage.string,
                                    options: [],
                                    range: NSRange(location: 0, length: string.length))

        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let symbolRange = match.range(at: 1)
            textStorage.addAttributes([
                .foregroundColor: bulletColor,
                .font: boldFont
            ], range: symbolRange)
        }
    }
}
