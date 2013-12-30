JCSubscriptionManager
=====================

The JCSubscriptionManager class provides a singleton that manages autorenewable subscriptions for an iOS app. JCSubscriptionManager uses the following submodules:
[RMStore](https://github.com/robotmedia/RMStore) for app receipt verification and [Lockbox](https://github.com/granoff/Lockbox) for keychain storage.

###Add to your project
1. Link `StoreKit.framework` and `Security.framework`.
2. Drag the `SubscriptionManager`, `RMStore`, `Lockbox`, and `Reachability` directories to your project.
3. Edit `ProductIdentifiers.plist` to include product identifiers for your autorenewable subscriptions.
4. Edit `JCSubscriptionManagerConfigs.h` to customize settings.
5. Add to app delegate's `-didFinishLaunching:withOptions:`

```objective-c
[JCSubscriptionManager sharedManager];
```
###Set up server-side receipt verification
Skip this step if your app supports only >= iOS 7, where the local app receipt is used for verification.


###Purchase a subscription

###Restore previous purchases

###Check if user is subscribed
