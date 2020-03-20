//
//  MediaStorage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/2/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import VirgilSDK

public class FileMediaStorage {
    internal let identity: String

    private let fileSystem: FileSystem

    public enum Error: String, Swift.Error {
        case outputStreamToPathFailed
        case imageFromFileFailed
    }
    
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
    
    public func exists(path: String) -> Bool {
        self.fileSystem.fileManager.fileExists(atPath: path)
    }
    
    public func reset() throws {
        try self.fileSystem.delete()
    }
}
