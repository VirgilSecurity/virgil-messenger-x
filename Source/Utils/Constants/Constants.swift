//
//  Constants.swift
//  VirgilSigner iOS
//
//  Created by Oleksandr Deundiak on 9/25/17.
//  Copyright © 2017 Virgil Security. All rights reserved.
//

import UIKit
import VirgilCrypto
import XMPPFrameworkSwift

enum Constants {
    enum EnvPrefix: String {
        case dev = "-dev"
        case stg = "-stg"
        case prod = ""
    }

    enum PushBodyType: String {
        case base64Encoded = "BASE64"
        case plaintext = "PLAIN"
    }

    static let alertTopic: String = KeychainGroup
    static let pushesNode: String = "node"
    static let keyPairType: KeyPairType = .curve25519Round5Ed25519Falcon

#if DEBUG
    static let pushMode: String = "dev"
#else
    static let pushMode: String = "prod"
#endif

    static let pushBodyType: PushBodyType = .plaintext
}

enum URLConstants {
    // Ejabberd
    static let ejabberdHostPort: UInt16 = 5222
    static let ejabberdPushHost: String = "push-notifications-proxy"

    // Backend
    static let virgilJwtEndpoint = URL(string: "\(URLConstants.serviceBaseURL)/virgil-jwt/")!
    static let ejabberdJwtEndpoint = URL(string: "\(URLConstants.serviceBaseURL)/ejabberd-jwt/")!
    static let signUpEndpoint = URL(string: "\(URLConstants.serviceBaseURL)/signup/")!
    static let reportEndpoint = URL(string: "\(URLConstants.serviceBaseURL)/report-content/")!

    // Other links
    static let termsAndConditionsURL = "https://virgilsecurity.com/terms-of-service"
    static let privacyURL = "https://virgilsecurity.com/privacy-policy"

    // Public
    static let publicStunServers = ["stun:stun.l.google.com:19302",
                                    "stun:stun1.l.google.com:19302",
                                    "stun:stun2.l.google.com:19302",
                                    "stun:stun3.l.google.com:19302",
                                    "stun:stun4.l.google.com:19302"]
}

enum ChatConstants {
    static let limitLength = 32
    static let characterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,-()/='+:?!%&*<>;{}#_")
    static let chatMaxCharactersCount: UInt = 1000
    static let chatPageSize = 20
}

enum UIConstants {
    static let TransitionAnimationDuration: TimeInterval = 0.3

    static var colorPairs: [ColorPair] = [ColorPair(UIColor(rgb: 0x009DFF), UIColor(rgb: 0x6AC7FF)),
                                          ColorPair(UIColor(rgb: 0x541C12), UIColor(rgb: 0x9E3621)),
                                          ColorPair(UIColor(rgb: 0x156363), UIColor(rgb: 0x21999E)),
                                          ColorPair(UIColor(rgb: 0x54CB68), UIColor(rgb: 0x9ADD7D)),          // light green
                                          ColorPair(UIColor(rgb: 0x665FFF), UIColor(rgb: 0x81ADFF)),          // strange
                                          ColorPair(UIColor(rgb: 0xFFA95C), UIColor(rgb: 0xFFCB66))]          // orange-yellow
}
