JCSubscriptionManager
=====================

The JCSubscriptionManager class provides a singleton that manages autorenewable subscriptions for an iOS app. It is a simple solution for apps with only one 'family' of autorenewable subscriptions. 
JCSubscriptionManager uses the following submodules:
[RMStore](https://github.com/robotmedia/RMStore) for app receipt verification and [Lockbox](https://github.com/granoff/Lockbox) for keychain storage.
ARC is required.

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

1. Edit `<<YOUR APPLE APP SECRET>>` in `verifyReceipt.php` to your autorenewable subscription shared secret (from iTunesConnect).
2. Upload `verifyReceipt.php` to your verification server, the one you list as `OWN_VERIFICATION_SERVER` in `JCSubscriptionManagerConfigs.h`.

###Purchase a subscription

To purchase a subscription, use:

```objective-c
- (BOOL)buyProductWithIdentifier:(NSString *)productIdentifier
                      completion:(void (^)(BOOL success, NSError *error))completion;]
```

You may also provide/remove access to subscription features by responding to the notifications `JCSubscriptionWasMadeNotification` and `JCSubscriptionExpiredNotification`, described below.

###Restore previous purchases

Restore previous transactions with:

```objective-c
- (BOOL)restorePreviousTransactionsWithCompletion:(void (^)(BOOL success, NSError *error))completion;
```

Again, you will also be notified of changes in subscription status through the notifications described below.

###Check if user is subscribed

```objective-c
- (BOOL)isSubscriptionActive;
```

###Notifications

1. `JCSubscriptionWasMadeNotification`: sent if an active subscription was verified when no previous subscription was found or a previous subscription lapsed.
2. `JCSubscriptionExpiredNotification`: sent if an active subscription has expired. JCSubscriptionManager will subsequently check if the subscription has been renewed.
3. `JCProductDataWasFetchedNotification`: sent when data on your subscriptions has been retrieved from iTunesConnect. This is when it is possible to populate your buy screen with info.

###Test
