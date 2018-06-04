# Virgil Demo Messenger

![VirgilSDK](https://cloud.githubusercontent.com/assets/6513916/19643783/bfbf78be-99f4-11e6-8d5a-a43394f2b9b2.png)

## Getting Started

Start with cloning repository to your PC. Open *terminal*, navigate to the folder where you want to store the application and execute
```bash
$ git clone https://github.com/VirgilSecurity/chat-twilio-ios.git -b sample-v5

$ cd chat-twilio-ios
```

## Prerequisites
**Virgil Messenger** uses several modules, including **Virgil SDK**. These packages are distributed via Carthage and CocoaPods. Since Carthage is a RECOMMENDED way to integrate those packages into the project, these application's dependencies are managed by it. Carthage integration is easy, convenient and you can simultaneously use CocoaPods to manage all other dependencies.

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
$ cd PathToProjectFolder/chat-twilio-ios
$ carthage bootstrap --platform iOS --no-use-binaries
```

### Set Up Backend
Follow instructions [here](https://github.com/VirgilSecurity/demo-twilio-chat-js/tree/v5) for setting up your own backend.

## Build and Run
At this point you are ready to build and run the application on iPhone and/or Simulator.

## Credentials

To build this sample were used next third-party frameworks

* [Twilio Programmable Chat](https://www.twilio.com/chat) - transmitting messages and handling channel events.
* [Chatto](https://github.com/badoo/Chatto) - representing UI of chatting. 
* [Virgil SDK](https://github.com/VirgilSecurity/virgil-sdk-x) - encrypting, decrypting messages and passwordless authentication.
* [PKHUD](https://github.com/pkluz/PKHUD) - reimplementing Apple's HUD.

## Documentation

Virgil Security has a powerful set of APIs, and the documentation is there to get you started today.

* [Configure the SDK][_getstarted_root] documentation
* [Usage examples][_guides]
  * [Create & publish a Card][_create_card] on Virgil Cards Service
  * [Search user's Card by user's identity][_search_card]
  * [Get user's Card by its ID][_get_card]
  * [Use Card for crypto operations][_use_card]
* [Reference API][_reference_api]

## Support

Our developer support team is here to help you. You can find us on [Twitter](https://twitter.com/virgilsecurity) or send us email support@virgilsecurity.com

[_getstarted_root]: https://developer.virgilsecurity.com/docs/how-to#sdk-configuration
[_guides]: https://developer.virgilsecurity.com/docs/how-to#public-key-management
[_use_card]: https://developer.virgilsecurity.com/docs/swift/how-to/public-key-management/v5/use-card-for-crypto-operation
[_get_card]: https://developer.virgilsecurity.com/docs/swift/how-to/public-key-management/v5/get-card
[_search_card]: https://developer.virgilsecurity.com/docs/swift/how-to/public-key-management/v5/search-card
[_create_card]: https://developer.virgilsecurity.com/docs/swift/how-to/public-key-management/v5/create-card
[_reference_api]: https://developer.virgilsecurity.com/docs/api-reference
