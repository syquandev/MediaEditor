//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalServiceKit
import SignalCoreKit

public class CVMediaCache: NSObject {

    private let stillMediaCache = LRUCache<String, AnyObject>(maxSize: 16,
                                                              shouldEvacuateInBackground: true)
    private let animatedMediaCache = LRUCache<String, AnyObject>(maxSize: 8,
                                                                 shouldEvacuateInBackground: true)

    private typealias MediaViewCache = LRUCache<String, ThreadSafeCacheHandle<ReusableMediaView>>
    private let stillMediaViewCache = MediaViewCache(maxSize: 12, shouldEvacuateInBackground: true)
    private let animatedMediaViewCache = MediaViewCache(maxSize: 6, shouldEvacuateInBackground: true)


    public required override init() {
        AssertIsOnMainThread()

        super.init()
    }

    public func getMedia(_ key: String, isAnimated: Bool) -> AnyObject? {
        let cache = isAnimated ? animatedMediaCache : stillMediaCache
        return cache.get(key: key)
    }

    public func setMedia(_ value: AnyObject, forKey key: String, isAnimated: Bool) {
        let cache = isAnimated ? animatedMediaCache : stillMediaCache
        cache.set(key: key, value: value)
    }

    public func getMediaView(_ key: String, isAnimated: Bool) -> ReusableMediaView? {
        let cache = isAnimated ? animatedMediaViewCache : stillMediaViewCache
        return cache.get(key: key)?.value
    }

    public func setMediaView(_ value: ReusableMediaView, forKey key: String, isAnimated: Bool) {
        let cache = isAnimated ? animatedMediaViewCache : stillMediaViewCache
        cache.set(key: key, value: ThreadSafeCacheHandle(value))
    }
    public func removeAllObjects() {
        AssertIsOnMainThread()

        stillMediaCache.removeAllObjects()
        animatedMediaCache.removeAllObjects()

        stillMediaViewCache.removeAllObjects()
        animatedMediaViewCache.removeAllObjects()
    }
}
