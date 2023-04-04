//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import UIKit
import SignalServiceKit
import SignalCoreKit

public enum ConversationUIMode: UInt {
    case normal
    case search
    case selection

    // These two modes are used to select interactions.
    public var hasSelectionUI: Bool {
        switch self {
        case .normal, .search:
            return false
        case .selection:
            return true
        }
    }
}

// MARK: -

public class ConversationViewController: OWSViewController {
//    public let layout: ConversationViewLayout
    public var collectionView = UICollectionView()

    var otherUsersProfileDidChangeEvent: DebouncedEvent?
    private var leases = [ModelReadCacheSizeLease]()

    // MARK: - View Lifecycle

    public override func viewDidLoad() {
        AssertIsOnMainThread()
    }

    private func createContents() {
        AssertIsOnMainThread()


        // We use the root view bounds as the initial frame for the collection
        // view so that its contents can be laid out immediately.
        //
        // TODO: To avoid relayout, it'd be better to take into account safeAreaInsets,
        //       but they're not yet set when this method is called.
        self.collectionView.frame = view.bounds
        self.collectionView.showsVerticalScrollIndicator = true
        self.collectionView.showsHorizontalScrollIndicator = false
        self.collectionView.keyboardDismissMode = .interactive
        self.collectionView.allowsMultipleSelection = true
        self.collectionView.backgroundColor = .clear

        // To minimize time to initial apearance, we initially disable prefetching, but then
        // re-enable it once the view has appeared.
        self.collectionView.isPrefetchingEnabled = false

        self.view.addSubview(self.collectionView)
        self.collectionView.autoPinEdge(toSuperviewEdge: .top)
        self.collectionView.autoPinEdge(toSuperviewEdge: .bottom)
        self.collectionView.autoPinEdge(toSuperviewSafeArea: .leading)
        self.collectionView.autoPinEdge(toSuperviewSafeArea: .trailing)

        self.collectionView.accessibilityIdentifier = "collectionView"
    }

    public override var canBecomeFirstResponder: Bool {
        return true
    }

    public override func becomeFirstResponder() -> Bool {
        return true
    }

    public func dismissPresentedViewControllerIfNecessary() {
        guard let presentedViewController = self.presentedViewController else {
            Logger.verbose("presentedViewController was nil")
            return
        }

        if presentedViewController is ActionSheetController ||
            presentedViewController is UIAlertController {
            Logger.verbose("Dismissing presentedViewController: \(type(of: presentedViewController))")
            dismiss(animated: false, completion: nil)
            return
        }
    }

    public override func viewWillAppear(_ animated: Bool) {

        Logger.verbose("viewWillAppear")

        super.viewWillAppear(animated)

        self.isViewVisible = true
    }

    private func acquireCacheLeases(_ groupThread: TSGroupThread) {
        guard leases.isEmpty else {
            // Hold leases for the CVC's lifetime because a view controller may "viewDidAppear" more than once without
            // leaving the navigation controller's stack.
            return
        }
        let numberOfGroupMembers = groupThread.groupModel.groupMembers.count
    }

    public override func viewDidAppear(_ animated: Bool) {

        InstrumentsMonitor.trackEvent(name: "ConversationViewController.viewDidAppear")
        Logger.verbose("viewDidAppear")

        super.viewDidAppear(animated)

        // recover status bar when returning from PhotoPicker, which is dark (uses light status bar)
        self.setNeedsStatusBarAppearanceUpdate()
    }

    // `viewWillDisappear` is called whenever the view *starts* to disappear,
    // but, as is the case with the "pan left for message details view" gesture,
    // this can be canceled. As such, we shouldn't tear down anything expensive
    // until `viewDidDisappear`.
    public override func viewWillDisappear(_ animated: Bool) {
        Logger.verbose("")

        super.viewWillDisappear(animated)
    }

    public override func viewDidDisappear(_ animated: Bool) {
        Logger.verbose("")

        super.viewDidDisappear(animated)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    public override var shouldAutorotate: Bool {
        // Don't allow orientation changes while recording voice messages
        return super.shouldAutorotate
    }

    public override func themeDidChange() {
        super.themeDidChange()

        self.updateThemeIfNecessary()
    }

    private func updateThemeIfNecessary() {
        AssertIsOnMainThread()

        self.applyTheme()
    }

    public override func applyTheme() {
        AssertIsOnMainThread()

        super.applyTheme()

        // make sure toolbar extends below iPhoneX home button.
        self.view.backgroundColor = Theme.toolbarBackgroundColor
    }

    func reloadCollectionViewForReset() {
        AssertIsOnMainThread()
    }

    var isViewVisible: Bool = true

    func updateCellsVisible() {
        AssertIsOnMainThread()

        let isAppInBackground = CurrentAppContext().isInBackground()
        let isCellVisible = self.isViewVisible && !isAppInBackground
    }

    // MARK: - Orientation

    public override func viewWillTransition(to size: CGSize,
                                            with coordinator: UIViewControllerTransitionCoordinator) {
        AssertIsOnMainThread()

        super.viewWillTransition(to: size, with: coordinator)
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        AssertIsOnMainThread()
    }

    public override func viewSafeAreaInsetsDidChange() {
        AssertIsOnMainThread()

        super.viewSafeAreaInsetsDidChange()
    }
}
