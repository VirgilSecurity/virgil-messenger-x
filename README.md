# Virgil Messenger

## Getting Started

Start with cloning repository to your PC. Open *terminal*, navigate to the folder where you want to store the application and execute
```bash
$ git clone https://github.com/VirgilSecurity/virgil-messenger-x.git

$ cd virgil-messenger-x
```

## Prerequisites
**Virgil Messenger** uses several modules, including **Virgil E3kit**. These packages are distributed via Carthage and CocoaPods. Since Carthage is a RECOMMENDED way to integrate those packages into the project, these application's dependencies are managed by it. Carthage integration is easy, convenient and you can simultaneously use CocoaPods to manage all other dependencies.

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

#### Updating dependencies
This example already has Carthage file with all required dependencies. All you need to do is to go to the project folder and update these dependencies.

```bash 
$ cd PathToProjectFolder/virgil-messenger-x
$ carthage bootstrap --platform iOS
```

### Crashlytics
Crashlytics is used for error reporting from the application. To run application you need to put corresponding `GoogleService-Info.plist` file into `PathToProjectFolder/virgil-messenger-x/VirgilMessenger` path.

## Backend
You can find full backend description [here](https://github.com/VirgilSecurity/virgil-devops-environment/blob/master/instructions/virgil-messenger.md)

## Frameworks

To build this app were used next third-party frameworks

* [XMPPFramework](https://github.com/robbiehanson/XMPPFramework) - transmitting messages and handling channel events via XMPP.
* [Chatto](https://github.com/badoo/Chatto) - representing UI of chatting. 
* [VirgilE3Kit](https://github.com/VirgilSecurity/virgil-e3kit-x) - encrypting, decrypting messages and passwordless authentication.
* [Crashlytics](https://firebase.google.com/docs/crashlytics/?gclid=CjwKCAjwvOHzBRBoEiwA48i6AoRSMkUm5XbMUKntGYv5akNU7kkHZhrBXonf5Q_s7I3shRxK302DYxoCLrAQAvD_BwE) - crashes and errors reporting.
* [PKHUD](https://github.com/pkluz/PKHUD) - reimplementing Apple's HUD.

## Support

Our developer support team is here to help you. Find out more information on our [Help Center](https://help.virgilsecurity.com/).

You can find us on [Twitter](https://twitter.com/VirgilSecurity) or send us email support@VirgilSecurity.com.

Also, get extra help from our support team on [Slack](https://virgilsecurity.com/join-community).

[_getstarted_root]: https://developer.virgilsecurity.com/docs/swift/get-started
[_getstarted_encryption]: https://developer.virgilsecurity.com/docs/swift/get-started/encrypted-communication
[_getstarted_storage]: https://developer.virgilsecurity.com/docs/swift/get-started/encrypted-storage
[_getstarted_data_integrity]: https://developer.virgilsecurity.com/docs/swift/get-started/data-integrity
[_guides]: https://developer.virgilsecurity.com/docs/swift/guides
[_guide_initialization]: https://developer.virgilsecurity.com/docs/swift/how-to/setup/v5/install-sdk
[_guide_virgil_cards]: https://developer.virgilsecurity.com/docs/swift/how-to/public-key-management/v5/create-card
[_guide_virgil_keys]: https://developer.virgilsecurity.com/docs/swift/how-to/public-key-management/v5/create-card
[_guide_encryption]: https://developer.virgilsecurity.com/docs/swift/how-to/public-key-management/v5/use-card-for-crypto-operation
[_reference_api]: https://developer.virgilsecurity.com/docs/api-reference
