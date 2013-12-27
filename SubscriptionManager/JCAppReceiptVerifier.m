//
//  JCAppReceiptVerifier.m
//  SubscriptionManager
//
//  Created by Joseph Chen on 12/17/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//

#import "JCAppReceiptVerifier.h"

// frameworks
#import <StoreKit/StoreKit.h>

// uses RMAppStore
#import "RMAppReceipt.h"
#import "RMStoreAppReceiptVerificator.h"

// uses Lockbox
#import "Lockbox.h"

@interface JCAppReceiptVerifier () <SKRequestDelegate>

@property (strong, nonatomic) RMStoreAppReceiptVerificator *verifier;
@property (strong, nonatomic) SKReceiptRefreshRequest *receiptRefreshRequest;

@end

NSTimeInterval const kRefreshInvalidReceiptRetryInterval = 30.0;
NSString *const kLockboxLatestProductIdentifierKey = @"latest-product-identifier";

@implementation JCAppReceiptVerifier

+ (NSString *)latestProductIdentifier
{
    return [Lockbox stringForKey:kLockboxLatestProductIdentifierKey];
}

+ (BOOL)setLatestProductIdentifier:(NSString *)identifier
{
    return [Lockbox setString:identifier forKey:kLockboxLatestProductIdentifierKey];
}

- (RMStoreAppReceiptVerificator *)verifier
{
    if (!_verifier) {
        _verifier = [[RMStoreAppReceiptVerificator alloc] init];
    }
    return _verifier;
}

- (void)verifyAppReceipt
{
    [self verifyAppReceiptForProduct:[self.class latestProductIdentifier]];
}

- (void)verifyAppReceiptForProduct:(NSString *)productIdentifier
{
    BOOL isAppReceiptValid = [self.verifier verifyAppReceipt];
    
    if (!isAppReceiptValid) {
        [self refreshAppReceipt];
        return;
    }
    
    // check expiration
    NSNumber *expiration = nil;
    if (productIdentifier) {
        RMAppReceipt *bundleReceipt = [RMAppReceipt bundleReceipt];
        NSDate *expirationDate = [bundleReceipt expirationDateOfLatestAutoRenewableSubscriptionOfProductIdentifier:productIdentifier];
        NSTimeInterval expirationSince1970 = [expirationDate timeIntervalSince1970];
        
        if (expirationSince1970 > [[NSDate date] timeIntervalSince1970] && productIdentifier) {
            [self.class setLatestProductIdentifier:productIdentifier];
        }
        
        expiration = @(expirationSince1970);
    }
    
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(JCReceiptVerifierDelegate)] && [self.delegate respondsToSelector:@selector(receiptVerifier:verifiedExpiration:)]) {
        [self.delegate receiptVerifier:self
                    verifiedExpiration:expiration];
    }
}

- (void)refreshAppReceipt
{
    if (self.receiptRefreshRequest) {
        return;
    }
    
    self.receiptRefreshRequest = [[SKReceiptRefreshRequest alloc] init];
    self.receiptRefreshRequest.delegate = self;
    [self.receiptRefreshRequest start];
}

#pragma mark - SKRequestDelegate

- (void)requestDidFinish:(SKRequest *)request
{
    if (request == self.receiptRefreshRequest) {
        self.receiptRefreshRequest = nil;
        [self verifyAppReceipt];
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    if (request == self.receiptRefreshRequest) {
        self.receiptRefreshRequest = nil;
        
        // try again later
        [self performSelector:@selector(refreshAppReceipt)
                   withObject:nil
                   afterDelay:kRefreshInvalidReceiptRetryInterval];
    }
}

#pragma mark - Testing

- (void)clearPurchaseInfo
{
    [self.class setLatestProductIdentifier:nil];
}

@end

#pragma mark - RMStore

@implementation RMAppReceipt (JCSubscriptionManager)

- (RMAppReceiptIAP *)lastReceiptForAutoRenewableSubscriptionOfProductIdentifier:(NSString *)productIdentifier
{
    if (!productIdentifier) {
        return nil;
    }
    
    RMAppReceiptIAP *lastTransaction = nil;
    NSTimeInterval lastInterval = 0;
    for (RMAppReceiptIAP *iap in [self inAppPurchases])
    {
        if (![iap.productIdentifier isEqualToString:productIdentifier]) continue;
        
        NSTimeInterval thisInterval = [iap.subscriptionExpirationDate timeIntervalSince1970];
        if (!lastTransaction || thisInterval > lastInterval)
        {
            lastTransaction = iap;
            lastInterval = thisInterval;
        }
    }
    return lastTransaction;
}

- (NSDate *)expirationDateOfLatestAutoRenewableSubscriptionOfProductIdentifier:(NSString *)productIdentifier
{
    if (!productIdentifier) {
        return nil;
    }
    
    RMAppReceiptIAP *lastTransaction = [self lastReceiptForAutoRenewableSubscriptionOfProductIdentifier:productIdentifier];
    return lastTransaction.subscriptionExpirationDate;
}

@end

