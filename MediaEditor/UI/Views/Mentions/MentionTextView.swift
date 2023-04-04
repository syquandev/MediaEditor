//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import SignalServiceKit

@objc
public protocol MentionTextViewDelegate: UITextViewDelegate {
    func textViewDidBeginTypingMention(_ textView: MentionTextView)
    func textViewDidEndTypingMention(_ textView: MentionTextView)

    func textViewMentionPickerParentView(_ textView: MentionTextView) -> UIView?
    func textViewMentionPickerReferenceView(_ textView: MentionTextView) -> UIView?

    func textView(_ textView: MentionTextView, didDeleteMention: Mention)
    func textViewMentionStyle(_ textView: MentionTextView) -> Mention.Style
}

@objc
open class MentionTextView: OWSTextView {
    @objc
    public weak var mentionDelegate: MentionTextViewDelegate? {
        didSet { updateMentionState() }
    }

    public override var delegate: UITextViewDelegate? {
        didSet {
            if let delegate = delegate {
            }
        }
    }

    public required init() {
        super.init(frame: .zero, textContainer: nil)
        delegate = self
    }


    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: -
    public func replaceCharacters(
        in range: NSRange,
        with mention: Mention
    ) {
        if let mentionDelegate = mentionDelegate{
            let replacementString: NSAttributedString
            replacementString = NSAttributedString(string: mention.text, attributes: defaultAttributes)
            replaceCharacters(in: range, with: replacementString)
        }
    }

    public func replaceCharacters(in range: NSRange, with string: String) {
        replaceCharacters(in: range, with: NSAttributedString(string: string, attributes: defaultAttributes))
    }

    public func replaceCharacters(in range: NSRange, with attributedString: NSAttributedString) {
        let previouslySelectedRange = selectedRange

        textStorage.replaceCharacters(in: range, with: attributedString)

        updateSelectedRangeAfterReplacement(
            previouslySelectedRange: previouslySelectedRange,
            replacedRange: range,
            replacementLength: attributedString.length
        )

        textViewDidChange(self)
    }

    private func updateSelectedRangeAfterReplacement(previouslySelectedRange: NSRange, replacedRange: NSRange, replacementLength: Int) {
        let replacedRangeEnd = replacedRange.location + replacedRange.length

        let replacedRangeIntersectsSelectedRange = previouslySelectedRange.location <= replacedRange.location
            && previouslySelectedRange.location < replacedRangeEnd

        let replacedRangeIsEntirelyBeforeSelectedRange = replacedRangeEnd <= previouslySelectedRange.location

        // If the replaced range intersected the selected range, move the cursor after the replacement text
        if replacedRangeIntersectsSelectedRange {
            selectedRange = NSRange(location: replacedRange.location + replacementLength, length: 0)

        // If the replaced range was entirely before the selected range, shift the selected range to
        // account for our newly inserted text.
        } else if replacedRangeIsEntirelyBeforeSelectedRange {
            selectedRange = NSRange(
                location: previouslySelectedRange.location + (replacementLength - replacedRange.length),
                length: previouslySelectedRange.length
            )
        }
    }

    public var currentlyTypingMentionText: String? {
        guard case .typingMention(let range) = state else { return nil }
        guard textStorage.length >= range.location + range.length else { return nil }
        guard range.length > 0 else { return "" }

        return attributedText.attributedSubstring(from: range).string
    }

    public var defaultAttributes: [NSAttributedString.Key: Any] {
        var defaultAttributes = [NSAttributedString.Key: Any]()
        if let font = font { defaultAttributes[.font] = font }
        if let textColor = textColor { defaultAttributes[.foregroundColor] = textColor }
        return defaultAttributes
    }
    
    @objc
    public var messageBody: MessageBody? {
        get { MessageBody(attributedString: attributedText) }
        set {
            guard let newValue = newValue else {
                replaceCharacters(
                    in: textStorage.entireRange,
                    with: ""
                )
                typingAttributes = defaultAttributes
                return
            }
        }
    }

    @objc
    public func stopTypingMention() {
        state = .notTypingMention
    }

    @objc
    public func reloadMentionState() {
        stopTypingMention()
        updateMentionState()
    }

    // MARK: - Mention State

    private enum State: Equatable {
        case typingMention(range: NSRange)
        case notTypingMention
    }
    private var state: State = .notTypingMention {
        didSet {
            switch state {
            case .notTypingMention:
                if oldValue != .notTypingMention { didEndTypingMention() }
            case .typingMention:
                if oldValue == .notTypingMention {
                    didBeginTypingMention()
                } else {
                    guard let currentlyTypingMentionText = currentlyTypingMentionText else {
                        return
                    }

                    didUpdateMentionText(currentlyTypingMentionText)
                }
            }
        }
    }

    private weak var pickerReferenceBackdrop: UIView?
    private weak var pickerViewTopConstraint: NSLayoutConstraint?
    private func didBeginTypingMention() {
        guard let mentionDelegate = mentionDelegate else { return }

        mentionDelegate.textViewDidBeginTypingMention(self)

    }

    private func didEndTypingMention() {
        mentionDelegate?.textViewDidEndTypingMention(self)
        self.pickerReferenceBackdrop = nil
        self.pickerViewTopConstraint = nil
    }

    private func didUpdateMentionText(_ text: String) {
    }

    private func shouldUpdateMentionText(in range: NSRange, changedText text: String) -> Bool {
        var deletedMentions = [NSRange: Mention]()

        if range.length > 0 {
            // Locate any mentions in the edited range.
            textStorage.enumerateMentions(in: range) { mention, subrange, _ in
                guard let mention = mention else { return }

                // Get the full range of the mention, we may only be editing a part of it.
                var uniqueMentionRange = NSRange()

                guard textStorage.attribute(
                    .mention,
                    at: subrange.location,
                    longestEffectiveRange: &uniqueMentionRange,
                    in: textStorage.entireRange
                ) != nil else {
                    return
                }

                deletedMentions[uniqueMentionRange] = mention
            }
        } else if range.location > 0,
            let leftMention = textStorage.attribute(
                .mention,
                at: range.location - 1,
                effectiveRange: nil
            ) as? Mention {
            // If there is a mention to the left, the typing attributes will
            // be the mention's attributes. We don't want that, so we need
            // to reset them here.
            typingAttributes = defaultAttributes

            // If we're not at the start of the string, and we're not replacing
            // any existing characters, check if we're typing in the middle of
            // a mention. If so, we need to delete it.
            var uniqueMentionRange = NSRange()
            if range.location < textStorage.length - 1,
                let rightMention = textStorage.attribute(
                    .mention,
                    at: range.location,
                    longestEffectiveRange: &uniqueMentionRange,
                    in: textStorage.entireRange
                ) as? Mention,
                leftMention == rightMention {
                deletedMentions[uniqueMentionRange] = leftMention
            }
        }

        for (deletedMentionRange, deletedMention) in deletedMentions {
            mentionDelegate?.textView(self, didDeleteMention: deletedMention)

            // Convert the mention to plain-text, in case we only deleted part of it
            textStorage.setAttributes(defaultAttributes, range: deletedMentionRange)
        }

        return true
    }

    private func updateMentionState() {
        // If we don't yet have a delegate, we can ignore any updates.
        // We'll check again when the delegate is assigned.
        guard mentionDelegate != nil else { return }

        guard selectedRange.length == 0, selectedRange.location > 0, textStorage.length > 0 else {
            state = .notTypingMention
            return
        }

        // We checked everything, so we're not typing
        state = .notTypingMention
    }
}


// MARK: - Cut/Copy/Paste

extension MentionTextView {
    open override func cut(_ sender: Any?) {
        copy(sender)
        replaceCharacters(in: selectedRange, with: "")
    }

    @objc
    public class func copyAttributedStringToPasteboard(_ attributedString: NSAttributedString) {
        guard let plaintextData = attributedString.string.data(using: .utf8) else {
            return
        }

        UIPasteboard.general.addItems([["public.utf8-plain-text": plaintextData]])
    }

    public static var pasteboardType: String { SignalAttachment.mentionPasteboardType }

    open override func copy(_ sender: Any?) {
        Self.copyAttributedStringToPasteboard(attributedText.attributedSubstring(from: selectedRange))
    }

    open override func paste(_ sender: Any?) {

        if !textStorage.isEmpty {
            // Pasting very long text generates an obscure UI error producing an UITextView where the lower
            // part contains invisible characters. The exact root of the issue is still unclear but the following
            // lines of code work as a workaround.
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) { [weak self] in
                if let self = self {
                    let oldRange = self.selectedRange
                    self.selectedRange = NSRange.init(location: 0, length: 0)
                    // inserting blank text into the text storage will remove the invisible characters
                    self.textStorage.insert(NSAttributedString(string: ""), at: 0)
                    // setting the range (again) will ensure scrolling to the correct position
                    self.selectedRange = oldRange
                }
            }
        }
    }
}

// MARK: - UITextViewDelegate

extension MentionTextView: UITextViewDelegate {
    open func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard shouldUpdateMentionText(in: range, changedText: text) else { return false }
        return mentionDelegate?.textView?(textView, shouldChangeTextIn: range, replacementText: text) ?? true
    }

    open func textViewDidChangeSelection(_ textView: UITextView) {
        mentionDelegate?.textViewDidChangeSelection?(textView)
        updateMentionState()
    }

    open func textViewDidChange(_ textView: UITextView) {
        mentionDelegate?.textViewDidChange?(textView)
        if textStorage.length == 0 { updateMentionState() }
    }

    open func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return mentionDelegate?.textViewShouldBeginEditing?(textView) ?? true
    }

    open func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        return mentionDelegate?.textViewShouldEndEditing?(textView) ?? true
    }

    open func textViewDidBeginEditing(_ textView: UITextView) {
        mentionDelegate?.textViewDidBeginEditing?(textView)
    }

    open func textViewDidEndEditing(_ textView: UITextView) {
        mentionDelegate?.textViewDidEndEditing?(textView)
    }

    open func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        return mentionDelegate?.textView?(textView, shouldInteractWith: URL, in: characterRange, interaction: interaction) ?? true
    }

    open func textView(_ textView: UITextView, shouldInteractWith textAttachment: NSTextAttachment, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        return mentionDelegate?.textView?(textView, shouldInteractWith: textAttachment, in: characterRange, interaction: interaction) ?? true
    }
}
