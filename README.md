JCSubscriptionManager
=====================

The JCSubscriptionManager class provides a singleton that manages autorenewable subscriptions for an iOS app. 

1. 

1. Add to app delegate's -didFinishLaunching:withOptions:

```objective-c
[JCSubscriptionManager sharedManager];

```



JCSubscriptionManager uses the following submodules:
[RMStore](https://github.com/robotmedia/RMStore) for app receipt verification. [Lockbox](https://github.com/granoff/Lockbox) for keychain storage.
