//
//  HttpConnection.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/17/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import VirgilSDK

/// Declares error types and codes
///
/// - noUrlInRequest: Provided URLRequest doesn't have url
/// - wrongResponseType: Response is not of HTTPURLResponse type
/// - fileAllocationFailed: DownloadTask is unable to allocate downloaded file
@objc(VSSServiceConnectionError) public enum ServiceConnectionError: Int, LocalizedError {
    case noUrlInRequest = 1
    case wrongResponseType = 2
    case fileAllocationFailed = 3

    /// Human-readable localized description
    public var errorDescription: String? {
        switch self {
        case .noUrlInRequest:
            return "Provided URLRequest doesn't have url"
        case .wrongResponseType:
            return "Response is not of HTTPURLResponse type"
        case .fileAllocationFailed:
            return "DownloadTask is unable to allocate downloaded file"
        }
    }
}

/// Simple HttpConnection implementation
open class HttpConnection: HttpConnectionProtocol {
    /// Default number of maximum concurrent operations
    public static let defaulMaxConcurrentOperationCount = 10
    /// Url session used to create network tasks
    private let session: URLSession

    private let adapters: [HttpRequestAdapter]

    /// Init
    ///
    /// - Parameters:
    ///   - adapters: request adapters
    public init(adapters: [HttpRequestAdapter] = []) {
        let config = URLSessionConfiguration.ephemeral
        self.session = URLSession(configuration: config)

        self.adapters = adapters
    }

    /// Sends Request and returns Response over http
    ///
    /// - Parameter request: Request to send
    /// - Returns: Obtained response
    /// - Throws: ServiceConnectionError.noUrlInRequest if provided URLRequest doesn't have url
    ///           ServiceConnectionError.wrongResponseType if response is not of HTTPURLResponse type
    public func send(_ request: Request) throws -> GenericOperation<Response> {
        let nativeRequest = try self.prepare(request)

        return NetworkOperation(request: nativeRequest, session: self.session)
    }

    public func upload(data: Data, with request: Request) throws -> NetworkUploadOperation {
        let nativeRequest = try self.prepare(request)

        return NetworkUploadOperation(request: nativeRequest, session: self.session, data: data)
    }

    public func downloadFile(with request: Request,
                             saveFileCallback: @escaping (URL) throws -> Void) throws -> NetworkDownloadOperation {
        let nativeRequest = try self.prepare(request)

        return NetworkDownloadOperation(request: nativeRequest,
                                        session: self.session,
                                        saveFileCallback: saveFileCallback)
    }

    private func prepare(_ request: Request) throws -> URLRequest {
        let nativeRequest = try self.adapters
            .reduce(request) { _, adapter -> Request in
                try adapter.adapt(request)
            }
            .getNativeRequest()

        guard let url = nativeRequest.url else {
            throw ServiceConnectionError.noUrlInRequest
        }

        let className = String(describing: type(of: self))

        Log.debug("\(className): request method: \(nativeRequest.httpMethod ?? "")")
        Log.debug("\(className): request url: \(url.absoluteString)")
        if let data = nativeRequest.httpBody, !data.isEmpty, let str = String(data: data, encoding: .utf8) {
            Log.debug("\(className): request body: \(str)")
        }
        Log.debug("\(className): request headers: \(nativeRequest.allHTTPHeaderFields ?? [:])")
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in cookies {
                Log.debug("*******COOKIE: \(cookie.name): \(cookie.value)")
            }
        }

        return nativeRequest
    }

    deinit {
        self.session.invalidateAndCancel()
    }
}
