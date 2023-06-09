//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

// This entity has responsibility for blocking the device from sleeping if
// certain behaviors (e.g. recording or playing voice messages) are in progress.
// 
// Sleep blocking is keyed using "block objects" whose lifetime corresponds to
// the duration of the block.  For example, sleep blocking during audio playback
// can be keyed to the audio player.  This provides a measure of robustness.
// On the one hand, we can use weak references to track block objects and stop
// blocking if the block object is deallocated even if removeBlock() is not
// called.  On the other hand, we will also get correct behavior to addBlock()
// being called twice with the same block object.
@objc
public class DeviceSleepManager: NSObject {

    @objc
    public static let shared = DeviceSleepManager()

    let serialQueue = DispatchQueue(label: "DeviceSleepManager")

    private class SleepBlock: CustomDebugStringConvertible {
        weak var blockObject: NSObject?

        var debugDescription: String {
            return "SleepBlock(\(String(reflecting: blockObject)))"
        }

        init(blockObject: NSObject) {
            self.blockObject = blockObject
        }
    }
    private var blocks: [SleepBlock] = []

    private override init() {
        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    private func didEnterBackground() {

        serialQueue.sync {
            ensureSleepBlocking()
        }
    }

    @objc
    public func addBlock(blockObject: NSObject) {
        serialQueue.sync {
            blocks.append(SleepBlock(blockObject: blockObject))
            ensureSleepBlocking()
        }
    }

    @objc
    public func removeBlock(blockObject: NSObject) {
        serialQueue.sync {
            blocks = blocks.filter {
                $0.blockObject != nil && $0.blockObject != blockObject
            }

            ensureSleepBlocking()
        }
    }

    private func ensureSleepBlocking() {

        // Cull expired blocks.
        blocks = blocks.filter {
            $0.blockObject != nil
        }
        let shouldBlock = blocks.count > 0

        let description: String
        switch blocks.count {
        case 0:
            description = "no blocking objects"
        case 1:
            description = "\(blocks[0])"
        default:
            description = "\(blocks[0]) and \(blocks.count - 1) others"
        }
    }
}
