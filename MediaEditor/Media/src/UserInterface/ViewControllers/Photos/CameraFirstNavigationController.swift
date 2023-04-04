//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalServiceKit
import SignalCoreKit

@objc
public protocol CameraFirstCaptureDelegate: AnyObject {
    func cameraFirstCaptureSendFlowDidComplete(_ cameraFirstCaptureSendFlow: CameraFirstCaptureSendFlow)
    func cameraFirstCaptureSendFlowDidCancel(_ cameraFirstCaptureSendFlow: CameraFirstCaptureSendFlow)
}

@objc
public class CameraFirstCaptureSendFlow: NSObject {
    @objc
    public weak var delegate: CameraFirstCaptureDelegate?

    var approvedAttachments: [SignalAttachment]?
    var approvalMessageBody: MessageBody?

    var mentionCandidates: [SignalServiceAddress] = []

    private func updateMentionCandidates() {
        AssertIsOnMainThread()
    }
}

extension CameraFirstCaptureSendFlow: SendMediaNavDelegate {
    func sendMediaNavDidCancel(_ sendMediaNavigationController: SendMediaNavigationController) {
        delegate?.cameraFirstCaptureSendFlowDidCancel(self)
    }

    func sendMediaNav(_ sendMediaNavigationController: SendMediaNavigationController, didApproveAttachments attachments: [SignalAttachment], messageBody: MessageBody?) {
        self.approvedAttachments = attachments
        self.approvalMessageBody = messageBody

//        let pickerVC = ConversationPickerViewController(selection: selection)
//        pickerVC.pickerDelegate = self
//        sendMediaNavigationController.pushViewController(pickerVC, animated: true)
    }

    func sendMediaNavInitialMessageBody(_ sendMediaNavigationController: SendMediaNavigationController) -> MessageBody? {
        return approvalMessageBody
        
    }

    func sendMediaNav(_ sendMediaNavigationController: SendMediaNavigationController, didChangeMessageBody newMessageBody: MessageBody?) {
        self.approvalMessageBody = newMessageBody
    }

    var sendMediaNavApprovalButtonImageName: String {
        return "arrow-right-24"
    }

    var sendMediaNavCanSaveAttachments: Bool {
        return true
    }

    var sendMediaNavTextInputContextIdentifier: String? {
        return nil
    }

    var sendMediaNavRecipientNames: [String] {
        return [""]
    }

    var sendMediaNavMentionableAddresses: [SignalServiceAddress] {
        mentionCandidates
    }
}

// MARK: -

//extension CameraFirstCaptureSendFlow: ConversationPickerDelegate {
//    public func conversationPickerSelectionDidChange(_ conversationPickerViewController: ConversationPickerViewController) {
//        updateMentionCandidates()
//    }
//
//    public func conversationPickerDidCompleteSelection(_ conversationPickerViewController: ConversationPickerViewController) {
//        guard let approvedAttachments = self.approvedAttachments else {
//            owsFailDebug("approvedAttachments was unexpectedly nil")
//            delegate?.cameraFirstCaptureSendFlowDidCancel(self)
//            return
//        }
//    }
//
//    public func conversationPickerCanCancel(_ conversationPickerViewController: ConversationPickerViewController) -> Bool {
//        return false
//    }
//
//    public func conversationPickerDidCancel(_ conversationPickerViewController: ConversationPickerViewController) {
//        owsFailDebug("Camera-first capture flow should never cancel conversation picker.")
//    }
//
//    public func conversationPickerDidBeginEditingText() {}
//
//    public func conversationPickerSearchBarActiveDidChange(_ conversationPickerViewController: ConversationPickerViewController) {}
//}
