//
//  NetworkUploadOperation.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/17/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import VirgilSDK

/// Network Operation
open class NetworkUploadOperation: GenericOperation<Response> {
    /// Task to execute
    public let request: URLRequest

    /// Url Sesssion
    public let session: URLSession

    // Data to upload
    public let data: Data

    /// Task
    public private(set) var task: URLSessionTask?

    /// Initializer
    ///
    /// - Parameter task: task to execute
    public init(request: URLRequest, session: URLSession, data: Data) {
        self.request = request
        self.session = session
        self.data = data

        super.init()
    }

    /// Main function
    override open func main() {
        let task = self.session.uploadTask(with: self.request,
                                           from: self.data)
        { [unowned self] data, response, error in
            defer {
                self.finish()
            }

            if let error = error {
                self.result = .failure(error)
                return
            }

            guard let response = response as? HTTPURLResponse else {
                self.result = .failure(ServiceConnectionError.wrongResponseType)
                return
            }

            Log.debug("NetworkOperation: response URL: \(response.url?.absoluteString ?? "")")
            Log.debug("NetworkOperation: response HTTP status code: \(response.statusCode)")
            Log.debug("NetworkOperation: response headers: \(response.allHeaderFields as AnyObject)")

            if let body = data, let str = String(data: body, encoding: .utf8) {
                Log.debug("NetworkOperation: response body: \(str)")
            }

            let result = Response(statusCode: response.statusCode, response: response, body: data)

            self.result = .success(result)
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
