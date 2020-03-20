//
//  Log.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 8/23/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation

/// Class used for logging
public enum Log {
    /// Log with DEBUG level
    ///
    /// - Parameters:
    ///   - closure: fake closure to caprute loging details
    ///   - functionName: functionName
    ///   - file: file
    ///   - line: line
    public static func debug(_ closure: @autoclosure () -> String, functionName: String = #function,
                             file: String = #file, line: UInt = #line) {
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
    public static func error(_ closure: @autoclosure () -> String, functionName: String = #function,
                             file: String = #file, line: UInt = #line) {
        self.log("<ERROR>: \(closure())", functionName: functionName, file: file, line: line)
    }

    /// Log with WARNING level
    ///
    /// - Parameters:
    ///   - closure: fake closure to caprute loging details
    ///   - functionName: functionName
    ///   - file: file
    ///   - line: line
    public static func warning(_ closure: @autoclosure () -> String, functionName: String = #function,
                             file: String = #file, line: UInt = #line) {
        self.log("<WARNING>: \(closure())", functionName: functionName, file: file, line: line)
    }

    private static func log(_ closure: @autoclosure () -> String, functionName: String = #function,
                            file: String = #file, line: UInt = #line) {
        let str = "VIRGILMESSENGER_LOG: \(functionName) : \(closure())"
        Log.writeInLog(str)
    }

    private static func writeInLog(_ message: String) {
        NSLogv("%@", getVaList([message]))
    }
}
