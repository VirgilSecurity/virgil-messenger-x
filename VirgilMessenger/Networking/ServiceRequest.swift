//
//  ServiceRequest.swift
//  VirgilSDK
//
//  Created by Oleksandr Deundiak on 9/19/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation

public class ServiceRequest: NSObject, HTTPRequest {
    let url: URL
    let method: Method
    let params: Any?
    
    @objc public static let DefaultTimeout: TimeInterval = 45
    
    public enum Method: String {
        case get    = "GET"
        case post   = "POST"
        case put    = "PUT"
        case delete = "DELETE"
    }
    
    public init(url: URL, method: Method, params: Any? = nil) throws {
        self.url = url
        self.method = method
        self.params = params
        
        super.init()
    }
    
    public func getNativeRequest() throws -> URLRequest {
        var request: URLRequest
        switch self.method {
        case .get:
            let url: URL
            if let p = self.params {
                guard let p = p as? [String : String] else {
                    throw NSError()
                }
            
                var components = URLComponents(string: self.url.absoluteString)
                components?.queryItems = p.map({
                    URLQueryItem(name: $0.key, value: $0.value)
                })
                
                guard let u = components?.url else {
                    throw NSError()
                }
                
                url = u
            }
            else {
                url = self.url
            }
            
            request = URLRequest(url: url)
            
        case .post, .put, .delete:
            request = URLRequest(url: self.url)
            
            let httpBody: Data?
            if let params = self.params {
                httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
            }
            else {
                httpBody = nil
            }
            
            request.httpBody = httpBody
        }
        
        request.timeoutInterval = ServiceRequest.DefaultTimeout
        request.httpMethod = self.method.rawValue
        
        return request
    }
}

extension NSURLRequest: HTTPRequest {
    public func getNativeRequest() -> URLRequest {
        return self as URLRequest
    }
}
