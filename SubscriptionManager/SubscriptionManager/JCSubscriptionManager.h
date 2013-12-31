//
//  JCSubscriptionManager.h
//  SubscriptionManager
//
//  Created by Joseph Chen on 11/17/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//

// Additional setup required:
// Requires frameworks: Security and StoreKit.
// Set correct search paths for headers and libraries.

#import <StoreKit/StoreKit.h>

/*!
 * Notifications that you might want to respond to.
 */
extern NSString *const JCSubscriptionExpiredNotification;
extern NSString *const JCSubscriptionWasMadeNotification;
extern NSString *const JCProductDataWasFetchedNotification;

/*!
 * Convenience.
 */
// Formatted logs.
// http://stackoverflow.com/questions/2770307/nslog-the-method-name-with-objective-c-in-iphone

#if DEBUG
#define JCLog(format, ...) JCLogIfEnabled(@"<%@:%@> %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [NSString stringWithFormat:(format), ##__VA_ARGS__])
#else
#define JCLog(format, ...)
#endif

void JCLogIfEnabled(NSString *format, ...);

/*!
 * Subscription Manager.
 */
@interface JCSubscriptionManager : NSObject

/*!
 * Singleton.
 */
+ (JCSubscriptionManager *)sharedManager;

/*!
 * Checks if any subscription is active.
 */
- (BOOL)isSubscriptionActive;

/*!
 * Get an array of SKProduct objects, whose information you can use to populate your buy screen. Returns nil if not fetched yet.
 */
- (NSArray *)products;

/*!
 * Purchase a subscription. Returns NO if method fails before purchase is attempted.
 */
- (BOOL)buyProductWithIdentifier:(NSString *)productIdentifier
                      completion:(void (^)(BOOL success, NSError *error))completion;

/*!
 * Restore purchases. Returns NO if method fails before restore is attempted.
 */
- (BOOL)restorePreviousTransactionsWithCompletion:(void (^)(BOOL success, NSError *error))completion;

/*
 * Remove all stored purchase information (e.g. for testing)
 */
- (void)clearPurchaseInfo;

@end


/*!
 * Category on SKProduct for convenience.
 */
@interface SKProduct (JCSubscriptionManager)

/*!
 * Get formatted price for a product.
 */
- (NSString *)formattedPrice;

@end
