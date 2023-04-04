//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import UIKit
import SignalServiceKit

protocol AttachmentCaptionDelegate: AnyObject {
    func captionView(_ captionView: AttachmentCaptionViewController, didChangeCaptionText captionText: String?, attachmentApprovalItem: AttachmentApprovalItem)
    func captionViewDidCancel()
}

// MARK: -

class AttachmentCaptionViewController: OWSViewController {

    weak var delegate: AttachmentCaptionDelegate?

    private let attachmentApprovalItem: AttachmentApprovalItem

    private let originalCaptionText: String?

    private let textView = UITextView()

    private var textViewHeightConstraint: NSLayoutConstraint?

    private let kMaxCaptionCharacterCount = 240

    init(delegate: AttachmentCaptionDelegate,
         attachmentApprovalItem: AttachmentApprovalItem) {
        self.delegate = delegate
        self.attachmentApprovalItem = attachmentApprovalItem
        self.originalCaptionText = attachmentApprovalItem.captionText

        super.init()

        self.addObserver(textView, forKeyPath: "contentSize", options: .new, context: nil)
    }

    deinit {
        self.removeObserver(textView, forKeyPath: "contentSize")
    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        updateTextView()
    }

    // MARK: - View Lifecycle

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        textView.becomeFirstResponder()

        updateTextView()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        textView.becomeFirstResponder()

        updateTextView()
    }

    public override func loadView() {
        self.view = UIView()
        self.view.backgroundColor = UIColor(white: 0, alpha: 0.25)
        self.view.isOpaque = false

        self.view.isUserInteractionEnabled = true
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backgroundTapped)))

        configureTextView()

        let doneIcon = UIImage(named: "image_editor_checkmark_full")?.withRenderingMode(.alwaysTemplate)
        let doneButton = UIBarButtonItem(image: doneIcon, style: .plain,
                                                            target: self,
                                                            action: #selector(didTapDone))
        doneButton.tintColor = .white
        navigationItem.rightBarButtonItem = doneButton

        self.view.layoutMargins = .zero

        lengthLimitLabel.setContentHuggingHigh()
        lengthLimitLabel.setCompressionResistanceHigh()

        let stackView = UIStackView(arrangedSubviews: [lengthLimitLabel, textView])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        stackView.isLayoutMarginsRelativeArrangement = true
        self.view.addSubview(stackView)
        stackView.autoPinEdge(toSuperviewEdge: .leading)
        stackView.autoPinEdge(toSuperviewEdge: .trailing)
        self.autoPinView(toBottomOfViewControllerOrKeyboard: stackView, avoidNotch: true)

        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        view.addSubview(backgroundView)
        view.sendSubviewToBack(backgroundView)
        backgroundView.autoPinEdge(toSuperviewEdge: .leading)
        backgroundView.autoPinEdge(toSuperviewEdge: .trailing)
        backgroundView.autoPinEdge(toSuperviewEdge: .bottom)
        backgroundView.autoPinEdge(.top, to: .top, of: stackView)

        let minTextHeight: CGFloat = textView.font?.lineHeight ?? 0
        textViewHeightConstraint = textView.autoSetDimension(.height, toSize: minTextHeight)

        view.addSubview(placeholderTextView)
        placeholderTextView.autoAlignAxis(.horizontal, toSameAxisOf: textView)
        placeholderTextView.autoPinEdge(.leading, to: .leading, of: textView)
        placeholderTextView.autoPinEdge(.trailing, to: .trailing, of: textView)
    }

    private func configureTextView() {
        textView.delegate = self

        textView.text = attachmentApprovalItem.captionText
        textView.font = UIFont.systemFont(ofSize: 15)
        textView.textColor = .white

        textView.isEditable = true
        textView.backgroundColor = .clear
        textView.isOpaque = false
        // We use a white cursor since we use a dark background.
        textView.tintColor = .white
        textView.isScrollEnabled = true
        textView.scrollsToTop = false
        textView.isUserInteractionEnabled = true
        textView.textAlignment = .left
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.contentInset = .zero
    }

    // MARK: - Events

    @objc func backgroundTapped(sender: UIGestureRecognizer) {
        completeAndDismiss(didCancel: false)
    }

    @objc public func didTapCancel() {
        completeAndDismiss(didCancel: true)
    }

    @objc public func didTapDone() {
        completeAndDismiss(didCancel: false)
    }

    private func completeAndDismiss(didCancel: Bool) {
        if didCancel {
            self.delegate?.captionViewDidCancel()
        } else {
            self.delegate?.captionView(self, didChangeCaptionText: self.textView.text, attachmentApprovalItem: attachmentApprovalItem)
        }

        self.dismiss(animated: true) {
            // Do nothing.
        }
    }

    // MARK: - Length Limit

    private lazy var lengthLimitLabel: UILabel = {
        let lengthLimitLabel = UILabel()

        // Length Limit Label shown when the user inputs too long of a message
        lengthLimitLabel.textColor = UIColor.ows_accentRed
        lengthLimitLabel.text = "ATTACHMENT_APPROVAL_CAPTION_LENGTH_LIMIT_REACHED"
        lengthLimitLabel.textAlignment = .center

        // Add shadow in case overlaid on white content
        lengthLimitLabel.layer.shadowColor = UIColor.black.cgColor
        lengthLimitLabel.layer.shadowOffset = .zero
        lengthLimitLabel.layer.shadowOpacity = 0.8
        lengthLimitLabel.isHidden = true

        return lengthLimitLabel
    }()

    // MARK: - Text Height

    // TODO: We need to revisit this with Myles.
    func updatePlaceholderTextViewVisibility() {
        let isHidden: Bool = {
            guard !self.textView.isFirstResponder else {
                return true
            }

            guard let captionText = self.textView.text else {
                return false
            }

            guard captionText.count > 0 else {
                return false
            }

            return true
        }()

        placeholderTextView.isHidden = isHidden
    }

    private lazy var placeholderTextView: UIView = {
        let placeholderTextView = UITextView()
        placeholderTextView.text = "ATTACHMENT_APPROVAL_CAPTION_PLACEHOLDER"
        placeholderTextView.isEditable = false

        placeholderTextView.backgroundColor = .clear
        placeholderTextView.font = UIFont.systemFont(ofSize: 15)

        placeholderTextView.textColor = Theme.darkThemePrimaryColor
        placeholderTextView.tintColor = Theme.darkThemePrimaryColor
        placeholderTextView.returnKeyType = .done

        return placeholderTextView
    }()

    // MARK: - Text Height

    private func updateTextView() {
        guard let textViewHeightConstraint = textViewHeightConstraint else {
            return
        }

        let contentSize = textView.sizeThatFits(CGSize(width: textView.width, height: CGFloat.greatestFiniteMagnitude))

        // `textView.contentSize` isn't accurate when restoring a multiline draft, so we compute it here.
        textView.contentSize = contentSize

        let minHeight: CGFloat = textView.font?.lineHeight ?? 0
        let maxHeight: CGFloat = 300
        let newHeight = contentSize.height.clamp(minHeight, maxHeight)

        textViewHeightConstraint.constant = newHeight
        textView.invalidateIntrinsicContentSize()
        textView.superview?.invalidateIntrinsicContentSize()

        textView.isScrollEnabled = contentSize.height > maxHeight

        updatePlaceholderTextViewVisibility()
    }
}

extension AttachmentCaptionViewController: UITextViewDelegate {

    public func textViewDidChange(_ textView: UITextView) {
        updateTextView()
    }

    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let existingText: String = textView.text ?? ""
        let proposedText: String = (existingText as NSString).replacingCharacters(in: range, with: text)

        // After verifying the byte-length is sufficiently small, verify the character count is within bounds.
        // Normally this character count should entail *much* less byte count.
        guard proposedText.count <= kMaxCaptionCharacterCount else {

            self.lengthLimitLabel.isHidden = false

            // `range` represents the section of the existing text we will replace. We can re-use that space.
            let charsAfterDelete: Int = (existingText as NSString).replacingCharacters(in: range, with: "").count

            // Accept as much of the input as we can
            let charBudget: Int = Int(kMaxCaptionCharacterCount) - charsAfterDelete
            if charBudget >= 0 {
                let acceptableNewText = text.safePrefix(charBudget)
                textView.text = (existingText as NSString).replacingCharacters(in: range, with: acceptableNewText)
            }

            return false
        }

        self.lengthLimitLabel.isHidden = true
        return true
    }

    public func textViewDidBeginEditing(_ textView: UITextView) {
        updatePlaceholderTextViewVisibility()
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
        updatePlaceholderTextViewVisibility()
    }
}
