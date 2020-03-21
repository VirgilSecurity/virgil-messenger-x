//
//  Log.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 8/23/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import Crashlytics

/// Class used for logging
public enum Log {
    /// Log with DEBUG level
    ///
    /// - Parameters:
    ///   - closure: fake closure to caprute loging details
    ///   - functionName: functionName
    ///   - file: file
    ///   - line: line
    public static func debug(_ closure: @autoclosure () -> String,
                             functionName: String = #function,
                             file: String = #file,
                             line: UInt = #line) {
        #if DEBUG
        self.log("<DEBUG>: \(closure())", functionName: functionName, file: file, line: line)
        #endif
    }

    /// Log with ERROR level
    ///
    /// - Parameters:
    ///   - closure: fake closure to caprute loging details
    ///   - functionName: functionName
    ///   - file: file
    ///   - line: line
    public static func error(_ error: Error,
                             message closure: @autoclosure () -> String,
                             functionName: String = #function,
                             file: String = #file,
                             line: UInt = #line) {
        let info = ["message": closure(),
                    "localizedDescription": error.localizedDescription,
                    "functionName": String(functionName),
                    "file": String(file),
                    "line": String(line)]
        
        Crashlytics.sharedInstance().recordError(error, withAdditionalUserInfo: info)

        self.log("<ERROR>: \(error.localizedDescription), message: \(closure())",
                 functionName: functionName,
                 file: file,
                 line: line)
    }

    private static func log(_ closure: @autoclosure () -> String,
                            functionName: String = #function,
                            file: String = #file,
                            line: UInt = #line) {
        let str = "VIRGILMESSENGER_LOG: \(functionName) : \(closure())"
        Log.writeInLog(str)
    }

    private static func writeInLog(_ message: String) {
        NSLogv("%@", getVaList([message]))
    }
}
