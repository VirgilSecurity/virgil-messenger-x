//
//  Client+Files.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/13/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import VirgilSDK

public protocol LoadDelegate: class {
    func progressChanged(to percent: Double)
    func failed(with error: Error)
    func completed(dataHash: String)
}

extension Client {
    // FIXME: remove useless dataHash
    func upload(data: Data, with request: URLRequest, loadDelegate: LoadDelegate, dataHash: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                // FIXME make sync for ui
                let request = try Request(urlRequest: request)
                
                let response = try self.connection.upload(data: data, with: request).startSync().get()
            
                try self.validateResponse(response)
                            
                loadDelegate.completed(dataHash: dataHash)
                                        
                completion((), nil)
            }
            catch {
                // FIXME: logs
                loadDelegate.failed(with: error)
                completion(nil, error)
            }
        }
//
//        // FIXME
//        _ = uploadOperation.task?.progress.observe(\.fractionCompleted) { progress, _ in
//            Log.debug("Upload progress: \(progress.fractionCompleted)")
//
//            loadDelegate.progressChanged(to: progress.fractionCompleted)
//        }
    }
    
    public func startDownload(from url: URL,
                              loadDelegate: LoadDelegate,
                              dataHash: String,
                              saveFileCallback: @escaping (URL) throws -> Void) throws {
        let request = Request(url: url, method: .get)
        
        let downloadOperation = try self.connection.downloadFile(with: request, saveFileCallback: saveFileCallback)
        
        downloadOperation.start { response, error in
            do {
                if let error = error {
                    throw error
                }
                else if let response = response {
                    try self.validateResponse(response)
                    
                    loadDelegate.completed(dataHash: dataHash)
                }
                else {
                    throw NSError()
                }
            }
            catch {
                loadDelegate.failed(with: error)
            }
        }
        
        // FIXME
        _ = downloadOperation.task?.progress.observe(\.fractionCompleted) { progress, _ in
            Log.debug("Download progress: \(progress.fractionCompleted)")

            loadDelegate.progressChanged(to: progress.fractionCompleted)
        }
    }
}