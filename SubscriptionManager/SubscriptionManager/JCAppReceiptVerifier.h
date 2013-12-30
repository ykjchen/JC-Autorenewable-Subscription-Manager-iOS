//
//  JCAppReceiptVerifier.h
//  SubscriptionManager
//
//  Created by Joseph Chen on 12/17/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JCReceiptVerifier.h"
#import "RMAppReceipt.h"

@interface JCAppReceiptVerifier : NSObject

@property (weak, nonatomic) id<JCReceiptVerifierDelegate> delegate;

- (void)verifyAppReceipt;
- (void)verifyAppReceiptForProduct:(NSString *)productIdentifier;
- (void)refreshAppReceipt;

/*!
 * Clear purchase information (for testing)
 */
- (void)clearPurchaseInfo;

@end

@interface RMAppReceipt (JCSubscriptionManager)

- (RMAppReceiptIAP *)lastReceiptForAutoRenewableSubscriptionOfProductIdentifier:(NSString *)productIdentifier;
- (NSDate *)expirationDateOfLatestAutoRenewableSubscriptionOfProductIdentifier:(NSString *)productIdentifier;

@end
