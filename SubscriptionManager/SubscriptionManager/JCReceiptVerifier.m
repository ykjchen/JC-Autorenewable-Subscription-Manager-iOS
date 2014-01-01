//
//  Created by Joseph Chen on 10/23/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//


#import "JCReceiptVerifier.h"

#import "JCSubscriptionManager.h"

// for < iOS7
#import "JCLegacyReceiptVerifier.h"

// for >= iOS7
#import "JCAppReceiptVerifier.h"

@interface JCReceiptVerifier () <JCReceiptVerifierDelegate>

// Independent verifiers for <iOS7 and >= iOS7.
@property (strong, nonatomic) JCLegacyReceiptVerifier *legacyReceiptVerifier;
@property (strong, nonatomic) JCAppReceiptVerifier *appReceiptVerifier;

// Store this so that delegate is not sent frivolous responses.
@property (strong, nonatomic) NSNumber *latestVerifiedExpirationIntervalSince1970;

@end

static NSNumber *_appReceiptAvailable = nil;

@implementation JCReceiptVerifier

#pragma mark - Private

+ (BOOL)isAppReceiptAvailable
{
    if (!_appReceiptAvailable) {
        _appReceiptAvailable = [NSNumber numberWithBool:(floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)];
    }
    return [_appReceiptAvailable boolValue];
}

- (JCLegacyReceiptVerifier *)legacyReceiptVerifier
{
    if (!_legacyReceiptVerifier) {
        _legacyReceiptVerifier = [[JCLegacyReceiptVerifier alloc] init];
        _legacyReceiptVerifier.delegate = self;
    }
    return _legacyReceiptVerifier;
}

- (JCAppReceiptVerifier *)appReceiptVerifier
{
    if (!_appReceiptVerifier) {
        _appReceiptVerifier = [[JCAppReceiptVerifier alloc] init];
        _appReceiptVerifier.delegate = self;
    }
    return _appReceiptVerifier;
}

#pragma mark - Public

- (void)verifySavedReceipt
{
    if (![self.class isAppReceiptAvailable]) {
        [self.legacyReceiptVerifier verifyLatestReceipt];
    } else {
        [self.appReceiptVerifier verifyAppReceipt];
    }
}

- (void)verifyReceipt:(NSData *)receipt forProduct:(NSString *)productIdentifier
{
    if (![self.class isAppReceiptAvailable]) {
        [self.legacyReceiptVerifier verifyReceipt:receipt];
    } else {
        [self.appReceiptVerifier verifyAppReceiptForProduct:productIdentifier];
    }
}

- (void)checkForRenewedSubscription
{
    JCLog(@"Checking if renewed subscription available.");
    
    if (![self.class isAppReceiptAvailable]) {
        [self.legacyReceiptVerifier verifyLatestReceipt];
    } else {
        [self.appReceiptVerifier refreshAppReceipt];
    }
}

#pragma mark - JCLegacyReceiptVerifierDelegate

- (void)receiptVerifier:(id)verifier
     verifiedExpiration:(NSNumber *)expirationIntervalSince1970
{
    BOOL expirationValid = (expirationIntervalSince1970.doubleValue > [[NSDate date] timeIntervalSince1970]);
    
    // Don't report an expired receipt if a valid one has been verified.
    if (!expirationValid &&
        self.latestVerifiedExpirationIntervalSince1970.doubleValue > [[NSDate date] timeIntervalSince1970]) {
            return;
    }
    
    // Don't report this expiration if it is dated (e.g. from an older receipt).
    if (expirationIntervalSince1970.doubleValue <= self.latestVerifiedExpirationIntervalSince1970.doubleValue) {
        return;
    }
    self.latestVerifiedExpirationIntervalSince1970 = expirationIntervalSince1970;

    if (self.delegate &&
        [self.delegate conformsToProtocol:@protocol(JCReceiptVerifierDelegate)] &&
        [self.delegate respondsToSelector:@selector(receiptVerifier:verifiedExpiration:)]) {
        [self.delegate receiptVerifier:self
                    verifiedExpiration:(expirationValid ? expirationIntervalSince1970 : nil)];
    }
}

#pragma mark - Testing

- (void)clearPurchaseInfo
{
    if (![self.class isAppReceiptAvailable]) {
        [self.legacyReceiptVerifier clearPurchaseInfo];
    } else {
        [self.appReceiptVerifier clearPurchaseInfo];
    }
}

@end
