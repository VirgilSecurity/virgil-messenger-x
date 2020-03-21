//
//  NetworkDownloadOperation.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/17/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import VirgilSDK

/// Network Operation
open class NetworkDownloadOperation: GenericOperation<Response> {
    /// Task to execute
    public let request: URLRequest

    /// Url Sesssion
    public let session: URLSession

    // Callback to be called after file downloaded in order to move it to persistant storage
    public let saveFileCallback: (URL) throws -> Void

    /// Task
    public private(set) var task: URLSessionTask?

    /// Initializer
    ///
    /// - Parameter task: task to execute
    public init(request: URLRequest, session: URLSession, saveFileCallback: @escaping (URL) throws -> Void) {
        self.request = request
        self.session = session
        self.saveFileCallback = saveFileCallback

        super.init()
    }

    /// Main function
    override open func main() {
        let task = self.session.downloadTask(with: self.request) { [unowned self] tempFileUrl, response, error in
            defer {
                self.finish()
            }

            do {
                if let error = error {
                    throw error
                }

                guard let response = response as? HTTPURLResponse else {
                    throw ServiceConnectionError.wrongResponseType
                }

                guard let tempFileUrl = tempFileUrl else {
                    throw ServiceConnectionError.fileAllocationFailed
                }

                Log.debug("NetworkOperation: response URL: \(response.url?.absoluteString ?? "")")
                Log.debug("NetworkOperation: response HTTP status code: \(response.statusCode)")
                Log.debug("NetworkOperation: response headers: \(response.allHeaderFields as AnyObject)")

                let result = Response(statusCode: response.statusCode, response: response, body: nil)

                try self.saveFileCallback(tempFileUrl)

                self.result = .success(result)
            } catch {
                self.result = .failure(error)
            }
        }

        self.task = task

        task.resume()
    }

    /// Cancel
    override open func cancel() {
        self.task?.cancel()

        super.cancel()
    }
}
