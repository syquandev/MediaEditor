//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer
import Photos
import CoreServices
import SignalCoreKit
import SignalServiceKit
import UIKit

@objc
public protocol AttachmentApprovalViewControllerDelegate: AnyObject {
    // In the media send flow, partially swiping to go back from AttachmentApproval,
    // then cancelling would render the mediaSend bottom buttons behind the attachment approval
    // input toolbar.
    //
    // I erroneously thought that this would have been prevented the UINavigationControllerDelegate
    // `didShowViewController` method but `didShowViewController" is not called upon canceling
    // navigation, while that view controllers `didAppear` method is.
    func attachmentApprovalDidAppear(_ attachmentApproval: AttachmentApprovalViewController)
    
    func attachmentApproval(_ attachmentApproval: AttachmentApprovalViewController,
                            didApproveAttachments attachments: [SignalAttachment], messageBody: MessageBody?)
    
    func attachmentApprovalDidCancel(_ attachmentApproval: AttachmentApprovalViewController)
    
    func attachmentApproval(_ attachmentApproval: AttachmentApprovalViewController,
                            didChangeMessageBody newMessageBody: MessageBody?)
    
    @objc
    optional func attachmentApproval(_ attachmentApproval: AttachmentApprovalViewController, didRemoveAttachment attachment: SignalAttachment)
    
    @objc
    optional func attachmentApprovalDidTapAddMore(_ attachmentApproval: AttachmentApprovalViewController)
    
    @objc
    optional func attachmentApprovalBackButtonTitle() -> String
    
    @objc var attachmentApprovalTextInputContextIdentifier: String? { get }
    
    @objc var attachmentApprovalRecipientNames: [String] { get }
    
    @objc var attachmentApprovalMentionableAddresses: [SignalServiceAddress] { get }
}

// MARK: -

public struct AttachmentApprovalViewControllerOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let canAddMore = AttachmentApprovalViewControllerOptions(rawValue: 1 << 0)
    public static let hasCancel = AttachmentApprovalViewControllerOptions(rawValue: 1 << 1)
    public static let canToggleViewOnce = AttachmentApprovalViewControllerOptions(rawValue: 1 << 2)
    public static let canChangeQualityLevel = AttachmentApprovalViewControllerOptions(rawValue: 1 << 3)
}

// MARK: -

@objc
public class AttachmentApprovalViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    
    // MARK: - Properties
    
    private let receivedOptions: AttachmentApprovalViewControllerOptions
    
    public var messageBody: MessageBody? {
        get {
            return attachmentTextToolbar.messageBody
        }
        set {
            attachmentTextToolbar.messageBody = newValue
        }
    }
    
    private var options: AttachmentApprovalViewControllerOptions {
        var options = receivedOptions
        
        if attachmentApprovalItemCollection.attachmentApprovalItems.count == 1,
           let firstItem = attachmentApprovalItemCollection.attachmentApprovalItems.first,
           firstItem.attachment.isValidImage || firstItem.attachment.isValidVideo {
            options.insert(.canToggleViewOnce)
        }
        
        if ImageQualityLevel.max == .high && attachmentApprovalItemCollection.attachmentApprovalItems.filter({ $0.attachment.isValidImage }).count > 0 {
            options.insert(.canChangeQualityLevel)
        }
        
        return options
    }
    
    var isAddMoreVisible: Bool {
        return options.contains(.canAddMore) && !isViewOnceEnabled
    }
    
    var isViewOnceEnabled = false
    lazy var outputQualityLevel: ImageQualityLevel = .one {
        didSet { updateContents(isApproved: false) }
    }
    
    public weak var approvalDelegate: AttachmentApprovalViewControllerDelegate?
    
    public var isEditingCaptions = false {
        didSet {
            updateContents(isApproved: false)
        }
    }
    
    func outputAttachmentsPromise() -> Promise<[SignalAttachment]> {
        var promises = [Promise<SignalAttachment>]()
        for attachmentApprovalItem in attachmentApprovalItems {
            let outputQualityLevel = self.outputQualityLevel
            promises.append(outputAttachmentPromise(for: attachmentApprovalItem).map(on: .global()) { attachment in
                attachment.preparedForOutput(qualityLevel: outputQualityLevel)
            })
        }
        return Promise.when(fulfilled: promises)
    }
    
    // MARK: - Initializers
    
    @available(*, unavailable, message: "use attachment: constructor instead.")
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let kSpacingBetweenItems: CGFloat = 20
    
    required public init(options: AttachmentApprovalViewControllerOptions,
                         sendButtonImageName: String,
                         attachmentApprovalItems: [AttachmentApprovalItem]) {
        assert(attachmentApprovalItems.count > 0)
        self.receivedOptions = options
        self.bottomToolView = AttachmentApprovalToolbar(options: options, sendButtonImageName: sendButtonImageName)
        
        let pageOptions: [UIPageViewController.OptionsKey: Any] = [.interPageSpacing: kSpacingBetweenItems]
        super.init(transitionStyle: .scroll,
                   navigationOrientation: .horizontal,
                   options: pageOptions)
        
        attachmentTextToolbar.attachmentTextToolbarDelegate = self
        
        let isAddMoreVisibleBlock = { [weak self] in
            return self?.isAddMoreVisible ?? false
        }
        self.attachmentApprovalItemCollection = AttachmentApprovalItemCollection(attachmentApprovalItems: attachmentApprovalItems, isAddMoreVisible: isAddMoreVisibleBlock)
        self.dataSource = self
        self.delegate = self
        bottomToolView.delegate = self
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActive),
                                               name: .OWSApplicationDidBecomeActive,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    public class func wrappedInNavController(attachments: [SignalAttachment],
                                             approvalDelegate: AttachmentApprovalViewControllerDelegate)
    -> OWSNavigationController {
        
        let attachmentApprovalItems = attachments.map { AttachmentApprovalItem(attachment: $0, canSave: false) }
        let vc = AttachmentApprovalViewController(options: [.hasCancel],
                                                  sendButtonImageName: "send-solid-24",
                                                  attachmentApprovalItems: attachmentApprovalItems)
        vc.approvalDelegate = approvalDelegate
        let navController = OWSNavigationController(rootViewController: vc)
        navController.ows_prefersStatusBarHidden = true
        
        guard let navigationBar = navController.navigationBar as? OWSNavigationBar else {
            return navController
        }
        navigationBar.switchToStyle(.alwaysDarkAndClear)
        
        return navController
    }
    
    // MARK: - Notifications
    
    @objc func didBecomeActive() {
        AssertIsOnMainThread()
        updateContents(isApproved: false)
    }
    
    // MARK: - Subviews
    
    var galleryRailView: GalleryRailView {
        return bottomToolView.galleryRailView
    }
    
    var attachmentTextToolbar: AttachmentTextToolbar {
        return bottomToolView.attachmentTextToolbar
    }
    
    let bottomToolView: AttachmentApprovalToolbar
    private var bottomToolViewBottomConstraint: NSLayoutConstraint?
    
    private lazy var inputAccessoryPlaceholder: InputAccessoryViewPlaceholder = {
        let placeholder = InputAccessoryViewPlaceholder()
        placeholder.delegate = self
        placeholder.referenceView = view
        return placeholder
    }()
    
    lazy var touchInterceptorView = UIView()
    
    // MARK: - View Lifecycle
    
    public override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .black
        
        // avoid an unpleasant "bounce" which doesn't make sense in the context of a single item.
        pagerScrollView?.isScrollEnabled = attachmentApprovalItems.count > 1
        
        // Bottom Toolbar
        galleryRailView.delegate = self
        
        // Navigation
        
        self.navigationItem.title = nil
        
        guard let firstItem = attachmentApprovalItems.first else {
            return
        }
        
        self.setCurrentItem(firstItem, direction: .forward, animated: false)
        
        // layout immediately to avoid animating the layout process during the transition
        self.currentPageViewController.view.layoutIfNeeded()
        
        view.addSubview(touchInterceptorView)
        touchInterceptorView.autoPinEdgesToSuperviewEdges()
        touchInterceptorView.isHidden = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapTouchInterceptorView(gesture:)))
        touchInterceptorView.addGestureRecognizer(tapGesture)
        
        let bottomToolViewWidth = view.bounds.width
        let bottomToolViewHeight = bottomToolView.systemLayoutSizeFitting(view.bounds.size, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        bottomToolView.frame = CGRect(x: 0, y: view.bounds.maxY - bottomToolViewHeight, width: bottomToolViewWidth, height: bottomToolViewHeight)
        UIView.performWithoutAnimation {
            bottomToolView.setNeedsLayout()
            bottomToolView.layoutIfNeeded()
        }
        view.addSubview(bottomToolView)
        bottomToolView.autoPinWidthToSuperview()
        bottomToolViewBottomConstraint =  bottomToolView.autoPinEdge(toSuperviewEdge: .bottom)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIViewController.attemptRotationToDeviceOrientation()
        
        guard let navigationBar = navigationController?.navigationBar as? OWSNavigationBar else {
            return
        }
        navigationBar.switchToStyle(.alwaysDarkAndClear)
        
        updateContents(isApproved: false)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        updateContents(isApproved: false)
        approvalDelegate?.attachmentApprovalDidAppear(self)
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    private func updateContents(isApproved: Bool) {
        updateNavigationBar()
        updateBottomToolView(isApproved: isApproved)
        
        touchInterceptorView.isHidden = !isEditingCaptions
        
        updateMediaRail()
        bottomToolView.options = options
    }
    
    // MARK: - Input Accessory
    
    public override var canBecomeFirstResponder: Bool {
        return true
    }
    
    public override var inputAccessoryView: UIView? {
        return inputAccessoryPlaceholder
    }
    
    public override var textInputContextIdentifier: String? {
        return approvalDelegate?.attachmentApprovalTextInputContextIdentifier
    }
    
    public func updateBottomToolView(isApproved: Bool) {
        var currentPageViewController: AttachmentPrepViewController?
        if pageViewControllers.count == 1 {
            currentPageViewController = pageViewControllers.first
        }
        let currentAttachmentItem: AttachmentApprovalItem? = currentPageViewController?.attachmentApprovalItem
        
        bottomToolView.isHidden = shouldHideControls
        bottomToolView.isUserInteractionEnabled = !shouldHideControls
        
        bottomToolView.update(isEditingCaptions: isEditingCaptions,
                              currentAttachmentItem: currentAttachmentItem,
                              shouldHideControls: shouldHideControls,
                              isApproved: isApproved,
                              recipientNames: approvalDelegate?.attachmentApprovalRecipientNames ?? [])
    }
    
    // MARK: - Navigation Bar
    
    lazy var saveButton: UIView = {
        return OWSButton.navigationBarButton(imageName: "save-24") { [weak self] in
            self?.didTapSave()
        }
    }()
    
    public func updateNavigationBar() {
        guard !shouldHideControls else {
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.rightBarButtonItem = nil
            return
        }
        
        guard !isEditingCaptions else {
            // Hide all navigation bar items while the caption view is open.
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "CAPTION_TITLE", style: .plain, target: nil, action: nil)
            
            let doneButton = navigationBarButton(imageName: "image_editor_checkmark_full",
                                                 selector: #selector(didTapCaptionDone(sender:)))
            let navigationBarItems = [doneButton]
            updateNavigationBar(navigationBarItems: navigationBarItems)
            return
        }
        
        var navigationBarItems = [UIView]()
        
        if let viewControllers = viewControllers,
           viewControllers.count == 1,
           let firstViewController = viewControllers.first as? AttachmentPrepViewController {
            navigationBarItems.append(contentsOf: firstViewController.navigationBarItems())
            if firstViewController.attachmentApprovalItem.canSave &&
                !firstViewController.hasCustomSaveButton {
                navigationBarItems.append(saveButton)
            }
            
            // Show the caption UI if there's more than one attachment
            // OR if the attachment already has a caption.
            let attachmentCount = attachmentApprovalItemCollection.count
            var shouldShowCaptionUI = attachmentCount > 1
            if let captionText = firstViewController.attachmentApprovalItem.captionText, captionText.count > 0 {
                shouldShowCaptionUI = true
            }
            if shouldShowCaptionUI {
                let addCaptionButton = navigationBarButton(imageName: "image_editor_add_caption",
                                                           selector: #selector(didTapCaption(sender:)))
                navigationBarItems.append(addCaptionButton)
            }
        }
        
        updateNavigationBar(navigationBarItems: navigationBarItems)
        
        if options.contains(.hasCancel) {
            let cancelButton = OWSButton.shadowedCancelButton { [weak self] in
                self?.cancelPressed()
            }
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: cancelButton)
        }
    }
    
    // MARK: - Control Visibility
    
    public var shouldHideControls: Bool {
        guard let pageViewController = pageViewControllers.first else {
            return false
        }
        return pageViewController.shouldHideControls
    }
    
    // MARK: - View Helpers
    
    func remove(attachmentApprovalItem: AttachmentApprovalItem) {
        if attachmentApprovalItem == currentItem {
            if let nextItem = attachmentApprovalItemCollection.itemAfter(item: attachmentApprovalItem) {
                setCurrentItem(nextItem, direction: .forward, animated: true)
            } else if let prevItem = attachmentApprovalItemCollection.itemBefore(item: attachmentApprovalItem) {
                setCurrentItem(prevItem, direction: .reverse, animated: true)
            } else {
                return
            }
        }
        
        guard let cell = galleryRailView.cellViews.first(where: { cellView in
            guard let item = cellView.item else { return false }
            return item.isEqualToGalleryRailItem(attachmentApprovalItem)
        }) else {
            return
        }
        
        UIView.animate(withDuration: 0.2,
                       animations: {
            // shrink stack view item until it disappears
            cell.isHidden = true
            
            // simultaneously fade out
            cell.alpha = 0
        },
                       completion: { _ in
            self.attachmentApprovalItemCollection.remove(item: attachmentApprovalItem)
            self.approvalDelegate?.attachmentApproval?(self, didRemoveAttachment: attachmentApprovalItem.attachment)
            self.updateMediaRail()
        })
    }
    
    lazy var pagerScrollView: UIScrollView? = {
        // This is kind of a hack. Since we don't have first class access to the superview's `scrollView`
        // we traverse the view hierarchy until we find it.
        let pagerScrollView = view.subviews.first { $0 is UIScrollView } as? UIScrollView
        assert(pagerScrollView != nil)
        
        return pagerScrollView
    }()
    
    // MARK: - UIPageViewControllerDelegate
    
    public func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        
        assert(pendingViewControllers.count == 1)
        pendingViewControllers.forEach { viewController in
            guard let pendingPage = viewController as? AttachmentPrepViewController else {
                return
            }
            
            // use compact scale when keyboard is popped.
            let scale: AttachmentPrepViewController.AttachmentViewScale = self.bottomToolView.isEditing ? .compact : .fullsize
            pendingPage.setAttachmentViewScale(scale, animated: false)
        }
    }
    
    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted: Bool) {
        
        assert(previousViewControllers.count == 1)
        previousViewControllers.forEach { viewController in
            guard let previousPage = viewController as? AttachmentPrepViewController else {
                return
            }
            
            if transitionCompleted {
                previousPage.zoomOut(animated: false)
                updateMediaRail()
            }
        }
    }
    
    // MARK: - UIPageViewControllerDataSource
    
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentViewController = viewController as? AttachmentPrepViewController else {
            return nil
        }
        
        let currentItem = currentViewController.attachmentApprovalItem
        guard let previousItem = attachmentApprovalItem(before: currentItem) else {
            return nil
        }
        
        guard let previousPage: AttachmentPrepViewController = buildPage(item: previousItem) else {
            return nil
        }
        
        return previousPage
    }
    
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        guard let currentViewController = viewController as? AttachmentPrepViewController else {
            return nil
        }
        
        let currentItem = currentViewController.attachmentApprovalItem
        guard let nextItem = attachmentApprovalItem(after: currentItem) else {
            return nil
        }
        
        guard let nextPage: AttachmentPrepViewController = buildPage(item: nextItem) else {
            return nil
        }
        
        return nextPage
    }
    
    public var currentPageViewController: AttachmentPrepViewController {
        return pageViewControllers.first!
    }
    
    public var pageViewControllers: [AttachmentPrepViewController] {
        return super.viewControllers!.map { $0 as! AttachmentPrepViewController }
    }
    
    @objc
    public override func setViewControllers(_ viewControllers: [UIViewController]?, direction: UIPageViewController.NavigationDirection, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        super.setViewControllers(viewControllers,
                                 direction: direction,
                                 animated: animated) { [weak self] (finished) in
            if let completion = completion {
                completion(finished)
            }
            self?.updateContents(isApproved: false)
        }
    }
    
    var currentItem: AttachmentApprovalItem! {
        get {
            return currentPageViewController.attachmentApprovalItem
        }
        set {
            setCurrentItem(newValue, direction: .forward, animated: false)
        }
    }
    
    private var cachedPages: [AttachmentApprovalItem: AttachmentPrepViewController] = [:]
    private func buildPage(item: AttachmentApprovalItem) -> AttachmentPrepViewController? {
        
        if let cachedPage = cachedPages[item] {
            return cachedPage
        }
        
        let viewController = AttachmentPrepViewController(attachmentApprovalItem: item)
        viewController.prepDelegate = self
        cachedPages[item] = viewController
        
        return viewController
    }
    
    private func setCurrentItem(_ item: AttachmentApprovalItem, direction: UIPageViewController.NavigationDirection, animated isAnimated: Bool) {
        guard let page = self.buildPage(item: item) else {
            return
        }
        
        page.loadViewIfNeeded()
        
        self.setViewControllers([page], direction: direction, animated: isAnimated, completion: nil)
        updateMediaRail()
    }
    
    func updateMediaRail(animated: Bool = false, isTypingMention: Bool = false) {
        guard let currentItem = self.currentItem else {
            return
        }
        
        let cellViewBuilder: (GalleryRailItem) -> GalleryRailCellView = { [weak self] railItem in
            switch railItem {
            case is AddMoreRailItem:
                return GalleryRailCellView()
            case is AttachmentApprovalItem:
                let cell = ApprovalRailCellView()
                cell.approvalRailCellDelegate = self
                return cell
            default:
                return GalleryRailCellView()
            }
        }
        
        galleryRailView.configureCellViews(itemProvider: isTypingMention ? nil : attachmentApprovalItemCollection,
                                           focusedItem: currentItem,
                                           cellViewBuilder: cellViewBuilder,
                                           animated: animated)
    }
    
    var attachmentApprovalItemCollection: AttachmentApprovalItemCollection!
    
    var attachmentApprovalItems: [AttachmentApprovalItem] {
        return attachmentApprovalItemCollection.attachmentApprovalItems
    }
    
    func outputAttachmentPromise(for attachmentApprovalItem: AttachmentApprovalItem) -> Promise<SignalAttachment> {
        if let imageEditorModel = attachmentApprovalItem.imageEditorModel, imageEditorModel.isDirty() {
            return editedAttachmentPromise(imageEditorModel: imageEditorModel,
                                           attachmentApprovalItem: attachmentApprovalItem)
        }
        return Promise.value(attachmentApprovalItem.attachment)
    }
    
    // For any attachments edited with the image editor, returns a
    // new SignalAttachment that reflects those changes.
    //
    // If any errors occurs in the export process, we fail over to
    // sending the original attachment.  This seems better than trying
    // to involve the user in resolving the issue.
    func editedAttachmentPromise(imageEditorModel: ImageEditorModel,
                                 attachmentApprovalItem: AttachmentApprovalItem) -> Promise<SignalAttachment> {
        assert(imageEditorModel.isDirty())
        return DispatchQueue.main.async(.promise) { () -> UIImage in
            guard let dstImage = imageEditorModel.renderOutput() else {
                throw OWSAssertionError("Could not render for output.")
            }
            return dstImage
        }.map(on: .global()) { (dstImage: UIImage) -> SignalAttachment in
            var dataUTI = kUTTypeImage as String
            guard let dstData: Data = {
                let isLossy: Bool = attachmentApprovalItem.attachment.mimeType.caseInsensitiveCompare(OWSMimeTypeImageJpeg) == .orderedSame
                if isLossy {
                    dataUTI = kUTTypeJPEG as String
                    return dstImage.jpegData(compressionQuality: 0.9)
                } else {
                    dataUTI = kUTTypePNG as String
                    return dstImage.pngData()
                }
            }() else {
                owsFailDebug("Could not export for output.")
                return attachmentApprovalItem.attachment
            }
            guard let dataSource = DataSourceValue.dataSource(with: dstData, utiType: dataUTI) else {
                owsFailDebug("Could not prepare data source for output.")
                return attachmentApprovalItem.attachment
            }
            
            // Rewrite the filename's extension to reflect the output file format.
            var filename: String? = attachmentApprovalItem.attachment.sourceFilename
            if let sourceFilename = attachmentApprovalItem.attachment.sourceFilename {
                if let fileExtension: String = MIMETypeUtil.fileExtension(forUTIType: dataUTI) {
                    filename = (sourceFilename as NSString).deletingPathExtension.appendingFileExtension(fileExtension)
                }
            }
            dataSource.sourceFilename = filename
            
            let dstAttachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: dataUTI)
            if let attachmentError = dstAttachment.error {
                owsFailDebug("Could not prepare attachment for output: \(attachmentError).")
                return attachmentApprovalItem.attachment
            }
            // Preserve caption text.
            dstAttachment.captionText = attachmentApprovalItem.captionText
            return dstAttachment
        }
    }
    
    // For any attachments edited with the video editor, returns a
    // new SignalAttachment that reflects those changes.
    //
    // If any errors occurs in the export process, we fail over to
    // sending the original attachment.  This seems better than trying
    // to involve the user in resolving the issue.
    func renderedAttachmentPromise(videoEditorModel: VideoEditorModel,
                                   attachmentApprovalItem: AttachmentApprovalItem) -> Promise<SignalAttachment> {
        assert(videoEditorModel.needsRender)
        return videoEditorModel.ensureCurrentRender().result.map(on: .sharedUserInitiated) { result in
            let filePath = try result.consumeResultPath()
            guard let fileExtension = filePath.fileExtension else {
                throw OWSAssertionError("Missing fileExtension.")
            }
            guard let dataUTI = MIMETypeUtil.utiType(forFileExtension: fileExtension) else {
                throw OWSAssertionError("Missing dataUTI.")
            }
            let dataSource = try DataSourcePath.dataSource(withFilePath: filePath, shouldDeleteOnDeallocation: true)
            // Rewrite the filename's extension to reflect the output file format.
            var filename: String? = attachmentApprovalItem.attachment.sourceFilename
            if let sourceFilename = attachmentApprovalItem.attachment.sourceFilename {
                filename = (sourceFilename as NSString).deletingPathExtension.appendingFileExtension(fileExtension)
            }
            dataSource.sourceFilename = filename
            
            let dstAttachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: dataUTI)
            if let attachmentError = dstAttachment.error {
                throw OWSAssertionError("Could not prepare attachment for output: \(attachmentError).")
            }
            // Preserve caption text.
            dstAttachment.captionText = attachmentApprovalItem.captionText
            dstAttachment.isViewOnceAttachment = attachmentApprovalItem.attachment.isViewOnceAttachment
            return dstAttachment
        }
    }
    func attachmentApprovalItem(before currentItem: AttachmentApprovalItem) -> AttachmentApprovalItem? {
        guard let currentIndex = attachmentApprovalItems.firstIndex(of: currentItem) else {
            return nil
        }
        
        let index: Int = attachmentApprovalItems.index(before: currentIndex)
        guard let previousItem = attachmentApprovalItems[safe: index] else {
            // already at first item
            return nil
        }
        
        
        return previousItem
    }
    
    func attachmentApprovalItem(after currentItem: AttachmentApprovalItem) -> AttachmentApprovalItem? {
        guard let currentIndex = attachmentApprovalItems.firstIndex(of: currentItem) else {
            return nil
        }
        
        let index: Int = attachmentApprovalItems.index(after: currentIndex)
        guard let nextItem = attachmentApprovalItems[safe: index] else {
            // already at first item
            return nil
        }
        
        return nextItem
    }
    
    // MARK: - Event Handlers
    
    @objc
    func didTapTouchInterceptorView(gesture: UITapGestureRecognizer) {
        
        isEditingCaptions = false
    }
    
    private func cancelPressed() {
        self.approvalDelegate?.attachmentApprovalDidCancel(self)
    }
    
    @objc func didTapCaption(sender: UIButton) {
        
        isEditingCaptions = true
    }
    
    @objc func didTapCaptionDone(sender: UIButton) {
        
        isEditingCaptions = false
    }
    
    public func didTapSave() {
        let errorText = "Lưu thất bại"
        do {
            let saveableAsset: SaveableAsset = try SaveableAsset(attachmentApprovalItem: self.currentItem)
            
            self.ows_askForMediaLibraryPermissions { isGranted in
                guard isGranted else {
                    return
                }
                
                PHPhotoLibrary.shared().performChanges({
                    switch saveableAsset {
                    case .image(let image):
                        PHAssetCreationRequest.creationRequestForAsset(from: image)
                    case .imageUrl(let imageUrl):
                        PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: imageUrl)
                    case .videoUrl(let videoUrl):
                        PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: videoUrl)
                    }
                }) { didSucceed, error in
                    DispatchQueue.main.async {
                        if didSucceed {
                            let toastController = ToastController(text: "Đã lưu")
                            let inset = self.bottomToolView.height + 16
                            toastController.presentToastView(fromBottomOfView: self.view, inset: inset)
                        } else {
                            OWSActionSheets.showErrorAlert(message: errorText)
                        }
                    }
                }
            }
        } catch {
            OWSActionSheets.showErrorAlert(message: errorText)
        }
    }
}

// MARK: -

extension AttachmentApprovalViewController: AttachmentTextToolbarDelegate {
    func attachmentTextToolbarDidBeginEditing(_ attachmentTextToolbar: AttachmentTextToolbar) {
        currentPageViewController.setAttachmentViewScale(.compact, animated: true)
    }
    
    func attachmentTextToolbarDidEndEditing(_ attachmentTextToolbar: AttachmentTextToolbar) {
        currentPageViewController.setAttachmentViewScale(.fullsize, animated: true)
    }
    
    func attachmentTextToolbarDidTapSend(_ attachmentTextToolbar: AttachmentTextToolbar) {
        // Toolbar flickers in and out if there are errors
        // and remains visible momentarily after share extension is dismissed.
        // It's easiest to just hide it at this point since we're done with it.
        currentPageViewController.shouldAllowAttachmentViewResizing = false
        updateContents(isApproved: true)
        
        // Generate the attachments once, so that any changes we
        // make below are reflected afterwards.
        ModalActivityIndicatorViewController.present(fromViewController: self, canCancel: false) { modalVC in
            self.outputAttachmentsPromise()
                .done(on: .main) { attachments in
                    AssertIsOnMainThread()
                    modalVC.dismiss {
                        AssertIsOnMainThread()
                        
                        if self.options.contains(.canToggleViewOnce), self.isViewOnceEnabled {
                            for attachment in attachments {
                                attachment.isViewOnceAttachment = true
                                
                            }
                            
                            assert(attachments.count <= 1)
                        }
                        print("------",attachments)
                        self.approvalDelegate?.attachmentApproval(self, didApproveAttachments: attachments, messageBody: attachmentTextToolbar.messageBody)
                    }
                }.catch { error in
                    AssertIsOnMainThread()
                    owsFailDebug("Error: \(error)")
                    
                    modalVC.dismiss {
                        let actionSheet = ActionSheetController(
                            title: CommonStrings.errorAlertTitle,
                            message: OWSLocalizedString(
                                "ATTACHMENT_APPROVAL_FAILED_TO_EXPORT",
                                comment: "Error that outgoing attachments could not be exported."))
                        actionSheet.addAction(ActionSheetAction(title: CommonStrings.okButton, style: .default))
                        
                        self.present(actionSheet, animated: true) {
                            // We optimistically hide the toolbar at the beginning of the function
                            // Since we failed, show it again.
                            self.updateContents(isApproved: false)
                        }
                    }
                }
        }
    }
    
    func attachmentTextToolbarDidChange(_ attachmentTextToolbar: AttachmentTextToolbar) {
        approvalDelegate?.attachmentApproval(self, didChangeMessageBody: attachmentTextToolbar.messageBody)
    }
    
    func attachmentTextToolbarDidViewOnce(_ attachmentTextToolbar: AttachmentTextToolbar) {
        updateContents(isApproved: false)
        
        if isViewOnceEnabled {
            attachmentTextToolbar.textView.stopTypingMention()
        }
    }
    
    func attachmentTextToolbarDidTapQualityButton(_ attachmentTextToolbar: AttachmentTextToolbar) {
        AssertIsOnMainThread()
        
        let actionSheet = ActionSheetController(theme: .translucentDark)
        actionSheet.isCancelable = true
        
        let buttonStack = UIStackView(arrangedSubviews: [
            buildOutputQualityButton(
                title: ImageQualityLevel.standard.localizedString,
                subtitle: OWSLocalizedString(
                    "ATTACHMENT_APPROVAL_MEDIA_QUALITY_STANDARD_OPTION_SUBTITLE",
                    comment: "Subtitle for the 'standard' option for media quality."
                ),
                isSelected: outputQualityLevel == .standard,
                action: { [weak self] in
                    self?.outputQualityLevel = .standard
                    actionSheet.dismiss(animated: true)
                }
            ),
            buildOutputQualityButton(
                title: ImageQualityLevel.high.localizedString,
                subtitle: OWSLocalizedString(
                    "Phụ đề",
                    comment: "Subtitle for the 'high' option for media quality."
                ),
                isSelected: outputQualityLevel == .high,
                action: { [weak self] in
                    self?.outputQualityLevel = .high
                    actionSheet.dismiss(animated: true)
                }
            )
        ])
        buttonStack.isLayoutMarginsRelativeArrangement = true
        buttonStack.layoutMargins = UIEdgeInsets(hMargin: 24, vMargin: 24)
        buttonStack.axis = .horizontal
        buttonStack.spacing = 20
        buttonStack.distribution = .fillEqually
        
        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 15)
        titleLabel.textColor = Theme.darkThemePrimaryColor
        titleLabel.textAlignment = .center
        titleLabel.text = OWSLocalizedString(
            "Tiêu đề",
            comment: "Title for the attachment approval media quality sheet"
        )
        
        let headerStack = UIStackView(arrangedSubviews: [buttonStack, titleLabel])
        headerStack.spacing = 4
        headerStack.axis = .vertical
        
        actionSheet.customHeader = headerStack
        
        presentActionSheet(actionSheet)
    }
    
    func buildOutputQualityButton(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> UIView {
        let button = OWSButton(block: action)
        
        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 15)
        titleLabel.textColor = Theme.darkThemePrimaryColor
        titleLabel.text = title
        
        let subtitleLabel = UILabel()
        subtitleLabel.font = UIFont.systemFont(ofSize: 15)
        subtitleLabel.textColor = Theme.darkThemePrimaryColor
        subtitleLabel.text = subtitle
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.numberOfLines = 0
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stackView.alignment = .center
        stackView.axis = .vertical
        stackView.spacing = 2
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(hMargin: 24, vMargin: 8)
        
        button.addSubview(stackView)
        stackView.isUserInteractionEnabled = false
        stackView.autoPinEdgesToSuperviewEdges()
        
        if isSelected {
            button.layer.cornerRadius = 18
            button.layer.borderWidth = 1
            button.layer.borderColor = Theme.darkThemePrimaryColor.cgColor
        } else {
            button.alpha = 0.7
        }
        
        return button
    }
    
    public func textViewDidBeginTypingMention(_ textView: MentionTextView) {
        
        updateMediaRail(animated: true, isTypingMention: true)
    }
    
    public func textViewDidEndTypingMention(_ textView: MentionTextView) {
        
        updateMediaRail(animated: true, isTypingMention: false)
    }
    
    public func textViewMentionPickerParentView(_ textView: MentionTextView) -> UIView? {
        return view
    }
    
    public func textViewMentionPickerReferenceView(_ textView: MentionTextView) -> UIView? {
        return bottomToolView
    }
    
    public func textView(_ textView: MentionTextView, didDeleteMention mention: Mention) {}
    
    public func textViewMentionStyle(_ textView: MentionTextView) -> Mention.Style {
        return .composingAttachment
    }
}


// MARK: -

extension AttachmentApprovalViewController: AttachmentPrepViewControllerDelegate {
    func prepViewControllerUpdateNavigationBar() {
        updateNavigationBar()
    }
    
    func prepViewControllerUpdateControls() {
        updateBottomToolView(isApproved: false)
    }
    
    var prepViewControllerShouldIgnoreTapGesture: Bool {
        guard bottomToolView.isEditing else { return false }
        _ = bottomToolView.resignFirstResponder()
        return true
    }
}

// MARK: GalleryRail

extension AttachmentApprovalItem: GalleryRailItem {
    public func buildRailItemView() -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = getThumbnailImage()
        return imageView
    }
}

// MARK: -

extension AttachmentApprovalItemCollection: GalleryRailItemProvider {
    var railItems: [GalleryRailItem] {
        if isAddMoreVisible() {
            return self.attachmentApprovalItems + [AddMoreRailItem()]
        } else {
            return self.attachmentApprovalItems
        }
    }
}

// MARK: -

extension AttachmentApprovalViewController: GalleryRailViewDelegate {
    public func galleryRailView(_ galleryRailView: GalleryRailView, didTapItem imageRailItem: GalleryRailItem) {
        if imageRailItem is AddMoreRailItem {
            self.approvalDelegate?.attachmentApprovalDidTapAddMore?(self)
            return
        }
        guard let targetItem = imageRailItem as? AttachmentApprovalItem else {
            return
        }
        
        guard let currentIndex = attachmentApprovalItems.firstIndex(of: currentItem) else {
            return
        }
        
        guard let targetIndex = attachmentApprovalItems.firstIndex(of: targetItem) else {
            return
        }
        
        let direction: UIPageViewController.NavigationDirection = currentIndex < targetIndex ? .forward : .reverse
        
        self.setCurrentItem(targetItem, direction: direction, animated: true)
    }
}

// MARK: -

extension AttachmentApprovalViewController: ApprovalRailCellViewDelegate {
    func approvalRailCellView(_ approvalRailCellView: ApprovalRailCellView, didRemoveItem attachmentApprovalItem: AttachmentApprovalItem) {
        remove(attachmentApprovalItem: attachmentApprovalItem)
    }
    
    func canRemoveApprovalRailCellView(_ approvalRailCellView: ApprovalRailCellView) -> Bool {
        return self.attachmentApprovalItems.count > 1
    }
}

extension AttachmentApprovalViewController: InputAccessoryViewPlaceholderDelegate {
    public func inputAccessoryPlaceholderKeyboardIsPresenting(animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve) {
        handleKeyboardStateChange(animationDuration: animationDuration, animationCurve: animationCurve)
    }
    
    public func inputAccessoryPlaceholderKeyboardDidPresent() {
        updateBottomToolViewPosition()
    }
    
    public func inputAccessoryPlaceholderKeyboardIsDismissing(animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve) {
        handleKeyboardStateChange(animationDuration: animationDuration, animationCurve: animationCurve)
    }
    
    public func inputAccessoryPlaceholderKeyboardDidDismiss() {
        updateBottomToolViewPosition()
    }
    
    public func inputAccessoryPlaceholderKeyboardIsDismissingInteractively() {
        updateBottomToolViewPosition()
    }
    
    func handleKeyboardStateChange(animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve) {
        guard animationDuration > 0 else { return updateBottomToolViewPosition() }
        
        UIView.beginAnimations("keyboardStateChange", context: nil)
        UIView.setAnimationBeginsFromCurrentState(true)
        UIView.setAnimationCurve(animationCurve)
        UIView.setAnimationDuration(animationDuration)
        updateBottomToolViewPosition()
        UIView.commitAnimations()
    }
    
    func updateBottomToolViewPosition() {
        bottomToolViewBottomConstraint?.constant = -inputAccessoryPlaceholder.keyboardOverlap
        
        // We always want to apply the new bottom bar position immediately,
        // as this only happens during animations (interactive or otherwise)
        bottomToolView.superview?.layoutIfNeeded()
    }
}

// MARK: -

extension AttachmentApprovalViewController: AttachmentApprovalToolbarDelegate {
    public func attachmentApprovalToolbarUpdateMediaRail() {
        updateMediaRail()
    }
    
    public func attachmentApprovalToolbarStartEditingCaptions() {
        isEditingCaptions = true
    }
    
    public func attachmentApprovalToolbarStopEditingCaptions() {
        isEditingCaptions = false
    }
}

private enum SaveableAsset {
    case image(_ image: UIImage)
    case imageUrl(_ url: URL)
    case videoUrl(_ url: URL)
}

private extension SaveableAsset {
    init(attachmentApprovalItem: AttachmentApprovalItem) throws {
        if let imageEditorModel = attachmentApprovalItem.imageEditorModel {
            try self.init(imageEditorModel: imageEditorModel)
        } else {
            try self.init(attachment: attachmentApprovalItem.attachment)
        }
    }
    
    init(imageEditorModel: ImageEditorModel) throws {
        guard let image = imageEditorModel.renderOutput() else {
            throw OWSAssertionError("failed to render image")
        }
        
        self = .image(image)
    }
    
    init(attachment: SignalAttachment) throws {
        if attachment.isValidImage {
            guard let imageUrl = attachment.dataUrl else {
                throw OWSAssertionError("imageUrl was unexpectedly nil")
            }
            
            self = .imageUrl(imageUrl)
        } else if attachment.isValidVideo {
            guard let videoUrl = attachment.dataUrl else {
                throw OWSAssertionError("videoUrl was unexpectedly nil")
            }
            
            self = .videoUrl(videoUrl)
        } else {
            throw OWSAssertionError("unsaveable media")
        }
    }
}
