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

    public enum MediaType {
        case photo
        case voice
    }

    internal init(identity: String) {
        self.identity = identity

        self.fileSystem = FileSystem(prefix: "VIRGIL-MESSENGER",
                                     userIdentifier: identity,
                                     pathComponents: ["MEDIA"])

    }

    public func store(_ media: Data, name: String, type: MediaType) throws {
        let subdir = self.getSubDir(for: type)

        try self.fileSystem.write(data: media, name: name, subdir: subdir)
    }

    public func getURL(name: String, type: MediaType) throws -> URL {
        let subdir = self.getSubDir(for: type)

        return try self.fileSystem.getFullUrl(name: name, subdir: subdir)
    }

    public func getPath(name: String, type: MediaType) throws -> String {
        try self.getURL(name: name, type: type).path
    }

    public func exists(path: String) -> Bool {
        self.fileSystem.fileManager.fileExists(atPath: path)
    }

    public func reset() throws {
        try self.fileSystem.delete()
    }

    private func getSubDir(for type: MediaType) -> String {
        let subdir: String

        switch type {
        case .photo:
            subdir = ""
        case .voice:
            subdir = ""
        }

        return subdir
    }
}
