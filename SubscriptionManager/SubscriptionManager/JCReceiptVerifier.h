//
//  Created by Joseph Chen on 10/23/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//

//
// It is JCReceiptVerifier's responsibility to verify receipt on startup and whenever a purchase is made.
// It will send a message to its delegate when verification has completed.
//

#import <Foundation/Foundation.h>

@protocol JCReceiptVerifierDelegate <NSObject>

/*!
 * Delegates should wait for this message, which includes a verified expiration date in the form
 * of the expiration date's time interval since 1970. Returns nil if no valid expiration date was found.
 */
- (void)receiptVerifier:(id)verifier
     verifiedExpiration:(NSNumber *)expirationIntervalSince1970;

@end

@interface JCReceiptVerifier : NSObject

@property (weak, nonatomic) id<JCReceiptVerifierDelegate> delegate;

/*!
 * Verifies current/latest stored receipt (<= iOS6) or
 * verifies app receipt locally (>= iOS7).
 */
- (void)verifySavedReceipt;

/*!
 * Verifies receipt for a new purchase/restore transaction.
 */
- (void)verifyReceipt:(NSData *)receipt
           forProduct:(NSString *)productIdentifier;

/*!
 * Checks if subscription has been renewed since last time app started.
 * Call this when a subscription has just expired.
 */
- (void)checkForRenewedSubscription;

/*!
 * Clears purchase info (for testing).
 */
- (void)clearPurchaseInfo;

@end
