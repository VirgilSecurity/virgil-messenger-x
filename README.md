# Virgil Demo Messenger

![VirgilSDK](https://cloud.githubusercontent.com/assets/6513916/19643783/bfbf78be-99f4-11e6-8d5a-a43394f2b9b2.png)

## Getting Started

Start with clonning repository to your PC. Open *terminal*, go to folder you want to locate application and execute
```bash
$ git clone -b develop https://github.com/VirgilSecurity/virgil-demo-messenger.git

$ cd virgil-demo-messenger
```

## Prerequisites
**Virgil Messenger** uses several modules, including **Virgil PFS SDK**. These packages are distributed via Carthage and CocoaPods. Since Carthage is RECOMMENDED way to integrate those packeges into project, this application's dependencies is managed by it. Carthage integration is easy, convenient and you can simultaniously use CocoaPods to manage all other dependencies.

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

#### Updating dependencies
This example already have Carthage file with all required dependencies. All you need to do is to go to the project folder and update those dependencies.

```bash 
$ cd PathToProjectFolder/virgil-demo-messenger
$ carthage update
```

The project should now be built without errors.

## Creating your Virgil + Twilio Application
Messenger uses [virgil-demo-twilio](https://github.com/VirgilSecurity/virgil-demo-twilio/tree/v2-backend) as a server to obtain **Twilio Token** and make new Virgil and Twilio accounts. You can make your own server. To do that you'll need to:
- Create your own account in [Dashboard](https://developer.virgilsecurity.com/account/signin) to get **Virgil Access Token** and *App Private key*.
- Set up your server to provide [creating Twilio Tokens](https://www.twilio.com/docs/api/chat/guides/create-tokens) and registering new users using [Virgil SDK](https://developer.virgilsecurity.com/docs/swift/get-started/encrypted-communication) and [Passwordless authentication](https://developer.virgilsecurity.com/docs/ruby/get-started/passwordless-authentication#setup-your-server)
- Change server endpoints and **Virgil Access Token** in client messenger app . All that you can find in `VirgilHelper` class.

## Documentation

Virgil Security has a powerful set of APIs, and the documentation is there to get you started today.

* [Get Started][_getstarted_root] documentation
  * [Initialize the SDK][_initialize_root]
  * [Encrypted storage][_getstarted_storage]
  * [Encrypted communication][_getstarted_encryption]
  * [Data integrity][_getstarted_data_integrity]
  * [Passwordless login][_getstarted_passwordless_login]
* [Guides][_guides]
  * [Virgil Cards][_guide_virgil_cards]
  * [Virgil Keys][_guide_virgil_keys]
* [Reference API][_reference_api]

## Support

Our developer support team is here to help you. You can find us on [Twitter](https://twitter.com/virgilsecurity) or send us email support@virgilsecurity.com

[__support_email]: https://google.com.ua/
[_getstarted_root]: https://developer.virgilsecurity.com/docs/swift/get-started
[_getstarted]: https://developer.virgilsecurity.com/docs/swift/guides
[_getstarted_encryption]: https://developer.virgilsecurity.com/docs/swift/get-started/encrypted-communication
[_getstarted_storage]: https://developer.virgilsecurity.com/docs/swift/get-started/encrypted-storage
[_getstarted_data_integrity]: https://developer.virgilsecurity.com/docs/swift/get-started/data-integrity
[_getstarted_passwordless_login]: https://developer.virgilsecurity.com/docs/swift/get-started/passwordless-authentication
[_guides]: https://developer.virgilsecurity.com/docs/swift/guides
[_guide_initialization]: https://developer.virgilsecurity.com/docs/swift/guides/settings/install-sdk
[_guide_virgil_cards]: https://developer.virgilsecurity.com/docs/swift/guides/virgil-card/creating
[_guide_virgil_keys]: https://developer.virgilsecurity.com/docs/swift/guides/virgil-key/generating
[_guide_encryption]: https://developer.virgilsecurity.com/docs/swift/guides/encryption/encrypting
[_initialize_root]: https://developer.virgilsecurity.com/docs/swift/guides/settings/initialize-sdk-on-client
[_reference_api]: http://virgilsecurity.github.io/virgil-sdk-x/
