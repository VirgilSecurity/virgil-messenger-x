# Virgil Demo Messenger

![VirgilSDK](https://cloud.githubusercontent.com/assets/6513916/19643783/bfbf78be-99f4-11e6-8d5a-a43394f2b9b2.png)


# Get Started
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

