//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

struct CDSRegisteredContact: Hashable {
    let signalUuid: UUID
    let e164PhoneNumber: String
}

/// Fetches contact info from the ContactDiscoveryService
/// Intended to be used by ContactDiscoveryTask. You probably don't want to use this directly.
class SGXContactDiscoveryOperation: ContactDiscovering {
    func perform(on queue: DispatchQueue){
    }
    
    static let batchSize = 2048
    
    private let e164sToLookup: Set<String>
    required init(e164sToLookup: Set<String>) {
        self.e164sToLookup = e164sToLookup
        Logger.debug("with e164sToLookup.count: \(e164sToLookup.count)")
        
        
        func uuidArray(from data: Data) -> [UUID] {
            return data.withUnsafeBytes {
                [uuid_t]($0.bindMemory(to: uuid_t.self))
                    .map { UUID(uuid: $0) }
            }
        }
        
        /// Parse the error and, if appropriate, construct an error appropriate to return upwards
        /// May return the provided error unchanged.
        func prepareExternalError(from error: Error) -> Error {
            return error
        }
    }
}
