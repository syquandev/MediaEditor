//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDB

// Any enum used by SDS extensions must be declared to conform
// to Codable and DatabaseValueConvertible.

extension TSOutgoingMessageState: Codable { }
extension TSOutgoingMessageState: DatabaseValueConvertible { }

extension OWSVerificationState: Codable { }
extension OWSVerificationState: DatabaseValueConvertible { }

extension TSGroupMetaMessage: Codable { }
extension TSGroupMetaMessage: DatabaseValueConvertible { }

extension TSAttachmentType: Codable { }
extension TSAttachmentType: DatabaseValueConvertible { }

extension TSAttachmentPointerType: Codable { }
extension TSAttachmentPointerType: DatabaseValueConvertible { }

extension TSAttachmentPointerState: Codable { }
extension TSAttachmentPointerState: DatabaseValueConvertible { }

extension SDSRecordType: Codable { }
extension SDSRecordType: DatabaseValueConvertible { }

