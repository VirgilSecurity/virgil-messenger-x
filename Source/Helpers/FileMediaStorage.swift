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
    
    // FIXME: Differentiate photo & voice data
    public func store(_ media: Data, name: String) throws {
        try self.fileSystem.write(data: media, name: name)
    }
    
    public func getURL(name: String) throws -> URL {
        try self.fileSystem.getFullUrl(name: name, subdir: nil)
    }
    
    public func getPath(name: String) throws -> String {
        try self.getURL(name: name).path
    }
    
    public func exists(path: String) throws -> Bool {
        try self.fileSystem.fileManager.fileExists(atPath: path)
    }
    
    public func retrieve(name: String) throws -> Data {
        let data = try self.fileSystem.read(name: name)

        guard !data.isEmpty else {
            throw NSError()
        }

        return data
    }
    
    public func reset() throws {
        try self.fileSystem.delete()
    }
}