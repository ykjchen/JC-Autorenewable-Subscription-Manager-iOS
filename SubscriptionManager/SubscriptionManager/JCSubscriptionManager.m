//
//  JCSubscriptionManager.m
//  SubscriptionManager
//
//  Created by Joseph Chen on 11/17/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//

#import "JCSubscriptionManager.h"

// StoreKit
#import <StoreKit/StoreKit.h>
#import "JCStoreKitHelper.h"

// Keychain Storage
#import "Lockbox.h"

// Receipt Verification
#import "JCReceiptVerifier.h"

// Internet Reachability
#import "Reachability.h"

#pragma mark - Notifications

NSString *const JCSubscriptionExpiredNotification = @"JCSubscriptionExpiredNotification";
NSString *const JCSubscriptionWasMadeNotification = @"JCSubscriptionWasMadeNotification";
NSString *const JCProductDataWasFetchedNotification = @"JCProductDataWasFetchedNotification";

#pragma mark - Convenience

// Function allows logging only when enabled.
// http://stackoverflow.com/questions/17758042/create-custom-variadic-logging-function
void JCLogIfEnabled(NSString *format, ...) {
#if LOGGING_ENABLED
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSLog(@"%@", msg);
#endif
}

#pragma mark - Constants

static JCSubscriptionManager *_sharedManager = nil;
NSString *const kLockboxSubscriptionExpirationIntervalKey = @"subscription-expiration-interval";

#pragma mark - JCSubscriptionManager

@interface JCSubscriptionManager () <JCReceiptVerifierDelegate, JCStoreKitHelperDelegate>

// receipt verification
@property (strong, nonatomic) JCReceiptVerifier *receiptVerifier;
@property (nonatomic, getter = isReceiptVerifiedOnce) BOOL receiptVerifiedOnce;

// making purchases
@property (strong, nonatomic) JCStoreKitHelper *storeKitHelper;

@end

@implementation JCSubscriptionManager

#pragma mark - Singleton

+ (JCSubscriptionManager *)sharedManager
{
    if (_sharedManager) {
        return _sharedManager;
    }

    // www.johnwordsworth.com/2010/04/iphone-code-snippet-the-singleton-pattern
    // For a thread-safe singleton.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[super allocWithZone:NULL] init];
    });
    return _sharedManager;
}

// Prevent creation of additional instances.
+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedManager];
}

- (id)init
{
    if (_sharedManager) {
        return _sharedManager;
    }

    self = [super init];
    if (self) {
        // Custom initialization here.
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self.storeKitHelper];
        [self.storeKitHelper requestProductData];
    }
    return self;
}

#if !__has_feature(objc_arc)
- (id)retain
{
    return self;
}

- (oneway void)release
{
    // Do nothing.
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;
}
#endif

#pragma mark - Accessors

- (JCReceiptVerifier *)receiptVerifier
{
    if (!_receiptVerifier) {
        _receiptVerifier = [[JCReceiptVerifier alloc] init];
        _receiptVerifier.delegate = self;
    }
    return _receiptVerifier;
}

- (JCStoreKitHelper *)storeKitHelper
{
    if (!_storeKitHelper) {
        _storeKitHelper = [[JCStoreKitHelper alloc] init];
        _storeKitHelper.delegate = self;
    }
    return _storeKitHelper;
}

#pragma mark - Public Methods

- (NSArray *)products
{
    NSArray *products = self.storeKitHelper.products;
    if (!products) {
        [self.storeKitHelper requestProductData];
    }
    return products;
}

- (BOOL)isSubscriptionActive
{
    // Check once that saved receipt is valid.
    if (!self.isReceiptVerifiedOnce) {
        [self.receiptVerifier verifySavedReceipt];
    }

    // If valid expiration date is found/saved, user is subscribed.
    NSNumber *expirationInterval = [self subscriptionExpirationIntervalSince1970];
    return (expirationInterval && expirationInterval.doubleValue > [[NSDate date] timeIntervalSince1970]);
}

- (BOOL)buyProductWithIdentifier:(NSString *)productIdentifier
                      completion:(void (^)(BOOL, NSError *))completion
{
    // forward to storeKitHelper
    return [self.storeKitHelper buyProductWithIdentifier:productIdentifier
                                              completion:completion];
}

- (BOOL)restorePreviousTransactionsWithCompletion:(void (^)(BOOL, NSError *))completion
{
    // forward to storeKitHelper
    return [self.storeKitHelper restorePreviousTransactionsWithCompletion:completion];
}

#pragma mark - JCReceiptVerifierDelegate

- (void)receiptVerifier:(id)verifier
     verifiedExpiration:(NSNumber *)expirationIntervalSince1970
{
    self.receiptVerifiedOnce = YES;
    [self setSubscriptionExpirationIntervalSince1970:expirationIntervalSince1970];
}

#pragma mark - JCStoreKitHelperDelegate

- (void)storeKitHelper:(JCStoreKitHelper *)helper didCompleteTransaction:(SKPaymentTransaction *)transaction
{
    NSData *receipt = nil;
    if ([transaction respondsToSelector:@selector(transactionReceipt)]) {
        receipt = transaction.transactionReceipt;
    }
    
    [self.receiptVerifier verifyReceipt:receipt
                             forProduct:transaction.payment.productIdentifier];
}

#pragma mark - Keychain Storage

- (NSNumber *)subscriptionExpirationIntervalSince1970
{
    NSString *string = [Lockbox stringForKey:kLockboxSubscriptionExpirationIntervalKey];
    if (!string) {
        return nil;
    }
    return @([string integerValue]);
}

- (BOOL)setSubscriptionExpirationIntervalSince1970:(NSNumber *)interval
{
    NSNumber *currentExpiration = [self subscriptionExpirationIntervalSince1970];
    BOOL wasSubscribed = (currentExpiration != nil);
    BOOL isSubscribed = (interval != nil); // this is set to nil when there is no valid subscription
    
    BOOL returnValue;
    if (interval == nil) {
        returnValue = [Lockbox setString:nil forKey:kLockboxSubscriptionExpirationIntervalKey];
    } else {
        returnValue = [Lockbox setString:[interval stringValue] forKey:kLockboxSubscriptionExpirationIntervalKey];
    }
    
    if (wasSubscribed && !isSubscribed) {
        // Should check if a new receipt is available.
        [self.receiptVerifier checkForRenewedSubscription];
        
        // Notify
        [[NSNotificationCenter defaultCenter] postNotificationName:JCSubscriptionExpiredNotification object:nil];
    } else if (isSubscribed && !wasSubscribed) {
        [[NSNotificationCenter defaultCenter] postNotificationName:JCSubscriptionWasMadeNotification object:nil];
    }
    
    return returnValue;
}

- (void)clearPurchaseInfo
{
    [Lockbox setString:nil forKey:kLockboxSubscriptionExpirationIntervalKey];
    [self.receiptVerifier clearPurchaseInfo];
}

@end


@implementation SKProduct (JCSubscriptionManager)

- (NSString *)formattedPrice
{
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:self.priceLocale];
    NSString *formattedString = [numberFormatter stringFromNumber:self.price];
    
#if !__has_feature(objc_arc)
    [numberFormatter release];
#endif
    
    return formattedString;
}

@end

