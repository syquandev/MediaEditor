//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import UIKit

@objc
public enum LinkPreviewError: Int, Error {
    /// A preview could not be generated from available input
    case noPreview
    /// A preview should have been generated, but something unexpected caused it to fail
    case invalidPreview
    /// A preview could not be generated due to an issue fetching a network resource
    case fetchFailure
    /// A preview could not be generated because the feature is disabled
    case featureDisabled
}

// MARK: - OWSLinkPreviewDraft

// This contains the info for a link preview "draft".
public class OWSLinkPreviewDraft: NSObject {
    @objc
    public var url: URL

    @objc
    public var urlString: String {
        return url.absoluteString
    }

    @objc
    public var title: String?

    @objc
    public var imageData: Data?

    @objc
    public var imageMimeType: String?

    @objc
    public var previewDescription: String?

    @objc
    public var date: Date?

    public init(url: URL, title: String?, imageData: Data? = nil, imageMimeType: String? = nil) {
        self.url = url
        self.title = title
        self.imageData = imageData
        self.imageMimeType = imageMimeType

        super.init()
    }

    fileprivate func isValid() -> Bool {
        var hasTitle = false
        if let titleValue = title {
            hasTitle = titleValue.count > 0
        }
        let hasImage = imageData != nil && imageMimeType != nil
        return hasTitle || hasImage
    }

    @objc
    public func displayDomain() -> String? {
        return OWSLinkPreviewManager.displayDomain(forUrl: urlString)
    }
}

// MARK: - OWSLinkPreview

@objc
public class OWSLinkPreview: MTLModel, Codable {

    @objc
    public var urlString: String?

    @objc
    public var title: String?

    @objc
    public var imageAttachmentId: String?

    @objc
    public var previewDescription: String?

    @objc
    public var date: Date?

    @objc
    public init(urlString: String, title: String?, imageAttachmentId: String?) {
        self.urlString = urlString
        self.title = title
        self.imageAttachmentId = imageAttachmentId

        super.init()
    }

    @objc
    public override init() {
        super.init()
    }

    @objc
    public required init!(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc
    public required init(dictionary dictionaryValue: [String: Any]!) throws {
        try super.init(dictionary: dictionaryValue)
    }

    @objc
    public class func isNoPreviewError(_ error: Error) -> Bool {
        guard let error = error as? LinkPreviewError else {
            return false
        }
        return error == .noPreview
    }

    @objc
    public class func buildValidatedLinkPreview(fromInfo info: OWSLinkPreviewDraft,
                                                transaction: SDSAnyWriteTransaction) throws -> OWSLinkPreview {
        guard SSKPreferences.areLinkPreviewsEnabled(transaction: transaction) else {
            throw LinkPreviewError.featureDisabled
        }
        let imageAttachmentId = OWSLinkPreview.saveAttachmentIfPossible(imageData: info.imageData,
                                                                        imageMimeType: info.imageMimeType,
                                                                        transaction: transaction)

        let linkPreview = OWSLinkPreview(urlString: info.urlString, title: info.title, imageAttachmentId: imageAttachmentId)
        linkPreview.previewDescription = info.previewDescription
        linkPreview.date = info.date

        guard linkPreview.isValid() else {
            owsFailDebug("Preview has neither title nor image.")
            throw LinkPreviewError.invalidPreview
        }

        return linkPreview
    }

    private class func saveAttachmentIfPossible(imageData: Data?,
                                                imageMimeType: String?,
                                                transaction: SDSAnyWriteTransaction) -> String? {
        guard let imageData = imageData else {
            return nil
        }
        guard let imageMimeType = imageMimeType else {
            return nil
        }
        guard let fileExtension = MIMETypeUtil.fileExtension(forMIMEType: imageMimeType) else {
            return nil
        }
        let fileSize = imageData.count
        guard fileSize > 0 else {
            owsFailDebug("Invalid file size for image data.")
            return nil
        }
        let contentType = imageMimeType

        let fileUrl = OWSFileSystem.temporaryFileUrl(fileExtension: fileExtension)
        do {
            try imageData.write(to: fileUrl)
            let dataSource = try DataSourcePath.dataSource(with: fileUrl, shouldDeleteOnDeallocation: true)
            let attachment = TSAttachmentStream(contentType: contentType, byteCount: UInt32(fileSize), sourceFilename: nil, caption: nil, albumMessageId: nil)
            try attachment.writeConsumingDataSource(dataSource)
            attachment.anyInsert(transaction: transaction)

            return attachment.uniqueId
        } catch {
            owsFailDebug("Could not write data source for: \(fileUrl), error: \(error)")
            return nil
        }
    }

    private func isValid() -> Bool {
        var hasTitle = false
        if let titleValue = title {
            hasTitle = titleValue.count > 0
        }
        let hasImage = imageAttachmentId != nil
        return hasTitle || hasImage
    }

    @objc
    public func removeAttachment(transaction: SDSAnyWriteTransaction) {
        guard let imageAttachmentId = imageAttachmentId else {
            owsFailDebug("No attachment id.")
            return
        }
        guard let attachment = TSAttachment.anyFetch(uniqueId: imageAttachmentId, transaction: transaction) else {
            owsFailDebug("Could not load attachment.")
            return
        }
        attachment.anyRemove(transaction: transaction)
    }

    @objc
    public func displayDomain() -> String? {
        return OWSLinkPreviewManager.displayDomain(forUrl: urlString)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case urlString, title, imageAttachmentId, previewDescription, date
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        urlString = try container.decodeIfPresent(String.self, forKey: .urlString)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        imageAttachmentId = try container.decodeIfPresent(String.self, forKey: .imageAttachmentId)
        previewDescription = try container.decodeIfPresent(String.self, forKey: .previewDescription)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        super.init()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let urlString = urlString {
            try container.encode(urlString, forKey: .urlString)
        }
        if let title = title {
            try container.encode(title, forKey: .title)
        }
        if let imageAttachmentId = imageAttachmentId {
            try container.encode(imageAttachmentId, forKey: .imageAttachmentId)
        }
        if let previewDescription = previewDescription {
            try container.encode(previewDescription, forKey: .previewDescription)
        }
        if let date = date {
            try container.encode(date, forKey: .date)
        }
    }
}

// MARK: -

@objc
public class OWSLinkPreviewManager: NSObject, Dependencies {

    // Although link preview fetches are non-blocking, the user may still end up
    // waiting for the fetch to complete. Because of this, UserInitiated is likely
    // most appropriate QoS.
    static let workQueue: DispatchQueue = .sharedUserInitiated

    // MARK: - Public

    @objc(findFirstValidUrlInSearchString:)
    public func findFirstValidUrl(in searchString: String) -> URL? {
        guard areLinkPreviewsEnabledWithSneakyTransaction() else { return nil }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            owsFailDebug("Could not create NSDataDetector")
            return nil
        }

        let allMatches = detector.matches(
            in: searchString,
            options: [],
            range: searchString.entireRange)

        return allMatches.first(where: {
            guard let parsedUrl = $0.url else { return false }
            guard let matchedRange = Range($0.range, in: searchString) else { return false }
            let matchedString = String(searchString[matchedRange])
            return parsedUrl.isPermittedLinkPreviewUrl(parsedFrom: matchedString)
        })?.url
    }

    @objc(fetchLinkPreviewForUrl:)
    @available(swift, obsoleted: 1.0)
    public func fetchLinkPreview(for url: URL) -> AnyPromise {
        let promise: Promise<OWSLinkPreviewDraft> = fetchLinkPreview(for: url)
        return AnyPromise(promise)
    }

    public func fetchLinkPreview(for url: URL) -> Promise<OWSLinkPreviewDraft> {
        guard areLinkPreviewsEnabledWithSneakyTransaction() else {
            return Promise(error: LinkPreviewError.featureDisabled)
        }

        return Promise(error: LinkPreviewError.featureDisabled)
    }

    // MARK: - Private

    private func fetchLinkPreview(forGenericUrl url: URL) -> Promise<OWSLinkPreviewDraft> {
        let (promise, _) = Promise<OWSLinkPreviewDraft>.pending()
        return promise
    }

    // MARK: - Private, Utilities

    func areLinkPreviewsEnabledWithSneakyTransaction() -> Bool {
        return databaseStorage.read { transaction in
            SSKPreferences.areLinkPreviewsEnabled(transaction: transaction)
        }
    }

    private func fetchImageResource(from url: URL) -> Promise<Data> {
        let (promise, _) = Promise<Data>.pending()
        return promise
    }

    // MARK: - Private, Constants

    private static let maxFetchedContentSize = 2 * 1024 * 1024
    private static let allowedMIMETypes: Set = [OWSMimeTypeImagePng, OWSMimeTypeImageJpeg]

    // MARK: - Preview Thumbnails

    private struct PreviewThumbnail {
        let imageData: Data
        let mimetype: String
    }

    private static func previewThumbnail(srcImageData: Data?, srcMimeType: String?) -> Promise<PreviewThumbnail?> {
        guard let srcImageData = srcImageData else {
            return Promise.value(nil)
        }
        return firstly(on: Self.workQueue) { () -> PreviewThumbnail? in
            let imageMetadata = (srcImageData as NSData).imageMetadata(withPath: nil, mimeType: srcMimeType)
            guard imageMetadata.isValid else {
                return nil
            }
            let hasValidFormat = imageMetadata.imageFormat != .unknown
            guard hasValidFormat else {
                return nil
            }

            let maxImageSize: CGFloat = 2400

            switch imageMetadata.imageFormat {
            case .unknown:
                owsFailDebug("Invalid imageFormat.")
                return nil
            case .webp:
                guard let stillImage = (srcImageData as NSData).stillForWebpData() else {
                    owsFailDebug("Couldn't derive still image for Webp.")
                    return nil
                }

                var stillThumbnail = stillImage
                let imageSize = stillImage.pixelSize
                let shouldResize = imageSize.width > maxImageSize || imageSize.height > maxImageSize
                if shouldResize {
                    guard let resizedImage = stillImage.resized(withMaxDimensionPixels: maxImageSize) else {
                        owsFailDebug("Couldn't resize image.")
                        return nil
                    }
                    stillThumbnail = resizedImage
                }

                guard let stillData = stillThumbnail.pngData() else {
                    owsFailDebug("Couldn't derive still image for Webp.")
                    return nil
                }
                return PreviewThumbnail(imageData: stillData, mimetype: OWSMimeTypeImagePng)
            default:
                guard let mimeType = imageMetadata.mimeType else {
                    owsFailDebug("Unknown mimetype for thumbnail.")
                    return nil
                }

                let imageSize = imageMetadata.pixelSize
                let shouldResize = imageSize.width > maxImageSize || imageSize.height > maxImageSize
                if (imageMetadata.imageFormat == .jpeg || imageMetadata.imageFormat == .png),
                    !shouldResize {
                    // If we don't need to resize or convert the file format,
                    // return the original data.
                    return PreviewThumbnail(imageData: srcImageData, mimetype: mimeType)
                }

                guard let srcImage = UIImage(data: srcImageData) else {
                    owsFailDebug("Could not parse image.")
                    return nil
                }

                guard let dstImage = srcImage.resized(withMaxDimensionPixels: maxImageSize) else {
                    owsFailDebug("Could not resize image.")
                    return nil
                }
                if imageMetadata.hasAlpha {
                    guard let dstData = dstImage.pngData() else {
                        owsFailDebug("Could not write resized image to PNG.")
                        return nil
                    }
                    return PreviewThumbnail(imageData: dstData, mimetype: OWSMimeTypeImagePng)
                } else {
                    guard let dstData = dstImage.jpegData(compressionQuality: 0.8) else {
                        owsFailDebug("Could not write resized image to JPEG.")
                        return nil
                    }
                    return PreviewThumbnail(imageData: dstData, mimetype: OWSMimeTypeImageJpeg)
                }
            }
        }
    }

    // MARK: - Stickers

    private func linkPreviewDraft(forStickerShare url: URL) -> Promise<OWSLinkPreviewDraft> {
        Logger.verbose("url: \(url)")
        let (promise, _) = Promise<OWSLinkPreviewDraft>.pending()
        return promise
    }
}

fileprivate extension URL {
    private static let schemeAllowSet: Set = ["https"]
    private static let tldRejectSet: Set = ["onion", "i2p"]
    private static let urlDelimeters: Set<Character> = Set(":/?#[]@")

    var mimeType: String? {
        guard pathExtension.count > 0 else {
            return nil
        }
        guard let mimeType = MIMETypeUtil.mimeType(forFileExtension: pathExtension) else {
            Logger.error("Image url has unknown content type: \(pathExtension).")
            return nil
        }
        return mimeType
    }

    /// Helper method that validates:
    /// - TLD is permitted
    /// - Comprised of valid character set
    static private func isValidHostname(_ hostname: String) -> Bool {
        // Technically, a TLD separator can be something other than a period (e.g. https://一二三。中国)
        // But it looks like NSURL/NSDataDetector won't even parse that. So we'll require periods for now
        let hostnameComponents = hostname.split(separator: ".")
        guard hostnameComponents.count >= 2, let tld = hostnameComponents.last?.lowercased() else {
            return false
        }
        let isValidTLD = !Self.tldRejectSet.contains(tld)
        let isAllASCII = hostname.allSatisfy { $0.isASCII }
        let isAllNonASCII = hostname.allSatisfy { !$0.isASCII || $0 == "." }

        return isValidTLD && (isAllASCII || isAllNonASCII)
    }

    /// - Parameter sourceString: The raw string that this URL was parsed from
    /// The source string will be parsed to ensure that the parsed hostname has only ASCII or non-ASCII characters
    /// to avoid homograph URLs.
    ///
    /// The source string is necessary, since NSURL and NSDataDetector will automatically punycode any returned
    /// URLs. The source string will be used to verify that the originating string's host only contained ASCII or
    /// non-ASCII characters to avoid homographs.
    ///
    /// If no sourceString is provided, the validated host will be whatever is returned from `host`, which will always
    /// be ASCII.
    func isPermittedLinkPreviewUrl(parsedFrom sourceString: String? = nil) -> Bool {
        guard let scheme = scheme?.lowercased(), scheme.count > 0 else { return false }
        guard user == nil else { return false }
        guard password == nil else { return false }
        let rawHostname: String?

        if let sourceString = sourceString {
            let schemePrefix = "\(scheme)://"
            rawHostname = sourceString
                .dropFirst(schemePrefix.count)
                .split(maxSplits: 1, whereSeparator: { Self.urlDelimeters.contains($0) }).first
                .map { String($0) }
        } else {
            // The hostname will be punycode and all ASCII
            rawHostname = host
        }

        guard let hostnameToValidate = rawHostname else { return false }
        return Self.schemeAllowSet.contains(scheme) && Self.isValidHostname(hostnameToValidate)
    }
}

// MARK: - To be moved
// Everything after this line should find a new home at some point

public extension OWSLinkPreviewManager {
    @objc
    class func displayDomain(forUrl urlString: String?) -> String? {
        guard let urlString = urlString else {
            owsFailDebug("Missing url.")
            return nil
        }
        guard let url = URL(string: urlString) else {
            owsFailDebug("Invalid url.")
            return nil
        }

        return url.host
    }

    private class func stickerPackShareDomain(forUrl url: URL) -> String? {
        guard let domain = url.host?.lowercased() else {
            return nil
        }
        guard url.path.count > 1 else {
            // Url must have non-empty path.
            return nil
        }
        return domain
    }
}

private func normalizeString(_ string: String, maxLines: Int) -> String {
    var result = string
    var components = result.components(separatedBy: .newlines)
    if components.count > maxLines {
        components = Array(components[0..<maxLines])
        result =  components.joined(separator: "\n")
    }
    let maxCharacterCount = 2048
    if result.count > maxCharacterCount {
        let endIndex = result.index(result.startIndex, offsetBy: maxCharacterCount)
        result = String(result[..<endIndex])
    }
    return result.filterStringForDisplay()
}
