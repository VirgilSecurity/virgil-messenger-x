//
//  MediaStorage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/2/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import VirgilSDK

// TODO: Check if needed
public class FileMediaStorage {
    internal let identity: String

    private let fileSystem: FileSystem

    internal init(identity: String) {
        self.identity = identity

        self.fileSystem = FileSystem(prefix: "VIRGIL-MESSENGER",
                                     userIdentifier: identity,
                                     pathComponents: ["MEDIA"])

    }
    
    public func store(_ media: Data, name: String) throws {
        try self.fileSystem.write(data: media, name: name)
    }
    
    public func reset() throws {
        try self.fileSystem.delete()
    }
    
    public func copy(from url: URL, name: String) throws {
        let newUrl = try self.fileSystem.getFullUrl(name: name, subdir: nil)
        
        try self.fileSystem.fileManager.copyItem(at: url, to: newUrl)
    }

//    public func retrieve(hash: Data) throws -> Data {
//        let subdir = "\(sessionId.hexEncodedString())/\(self.ticketsSubdir)"
//        let name = String(epoch)
//
//        let data = try self.fileSystem.read(name: name, subdir: subdir)
//
//        guard !data.isEmpty else {
//            throw FileGroupStorageError.emptyFile
//        }
//
//        return try Ticket.deserialize(data)
//    }
}
