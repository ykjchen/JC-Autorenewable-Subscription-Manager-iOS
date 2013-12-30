JCSubscriptionManager
=====================

The JCSubscriptionManager class provides a singleton that manages autorenewable subscriptions for an iOS app. It is a simple solution for apps with only one 'family' of autorenewable subscriptions. 

JCSubscriptionManager uses the following:
* [RMStore](https://github.com/robotmedia/RMStore) for app receipt verification (submodule).
* [Lockbox](https://github.com/granoff/Lockbox) for keychain storage (submodule).
* [NSData+Base64](http://www.cocoawithlove.com/2009/06/base64-encoding-options-on-mac-and.html) for base-64 encoding/decoding.
* [Reachability](https://developer.apple.com/library/ios/samplecode/Reachability/Introduction/Intro.html) for internet connectivity checking.
* [MKStoreKit](https://github.com/MugunthKumar/MKStoreKit) for inspiration.

ARC is required.

###Add to your project
1. Link `StoreKit.framework` and `Security.framework`.
2. Drag the `SubscriptionManager`, `RMStore`, `Lockbox`, and `Reachability` directories to your project.
3. Edit `ProductIdentifiers.plist` to include product identifiers for your autorenewable subscriptions.
4. Edit `JCSubscriptionManagerConfigs.h` to customize settings.
5. Add to app delegate's `-didFinishLaunching:withOptions:`
                      
        [JCSubscriptionManager sharedManager];

###Set up server-side receipt verification
Skip this step if your app supports only >= iOS 7, where the local app receipt is used for verification.

1. Edit `<<YOUR APPLE APP SECRET>>` in `verifyReceipt.php` to your autorenewable subscription shared secret (from iTunesConnect > Manage Your Apps > Manage In-App Purchases).
2. Upload `verifyReceipt.php` to your verification server, the one you list as `OWN_VERIFICATION_SERVER` in `JCSubscriptionManagerConfigs.h`.

###Get product data

Use this to populate your buy screen. Product data may not always be available (depending on connectivity) and the notification `JCProductDataWasFetchedNotification` is sent on retrieval of product data.

```objective-c
- (NSArray *)products;
```

Also, a category on SKProduct to conveniently get a product's price formatted and localized.

```objective-c
- (NSString *)formattedPrice;
```

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

If you have multiple subscriptions in a 'family', this checks if any of them is active.

###Notifications

1. `JCSubscriptionWasMadeNotification`: sent if an active subscription was verified when no previous subscription was found or a previous subscription lapsed.
2. `JCSubscriptionExpiredNotification`: sent if an active subscription has expired. JCSubscriptionManager will subsequently check if the subscription has been renewed.
3. `JCProductDataWasFetchedNotification`: sent when data on your subscriptions has been retrieved from iTunesConnect. This is when it is possible to populate your buy screen with info.

###Testing

Edit `ProductIdentifiers.plist` and `JCSubscriptionManagerConfigs.h` in the example project, upload `verifyReceipt.php` to your server (for < iOS7), and run the example project on a physical device to test your subscriptions.

A few things to point out:
* You will need to create a Test User on iTunesConnect with which to make the sandbox purchases.
* 1 month subscriptions are 5 minutes long in the sandbox, 6 month subscriptions are 30 minutes long, etc.
* Subscriptions auto-renew a max of 6 times a day in the sandbox.
* Nearly-expired subscriptions get renewed when the app launches in the 24 hours prior to the expiration date. In the sandbox, this may be hard to replicate, and when a subscription expires JCSubscriptionManager tries to refresh the saved receipt to check for a renewal. However, there may be a lapses between expiration and renewal verification.



