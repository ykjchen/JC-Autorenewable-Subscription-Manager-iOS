//
//  Created by Joseph Chen on 12/17/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//

//
// JCLegacyReceiptVerifier verifies receipts prior to iOS7.
// The preferred method of verification is with your remote server.
// The backup method of verification is directly with Apple's receipt verification server.
//
// If verification fails because of internet connectivity, the verifier will monitor internet and
// attempt to verify the receipt whenever the internet comes back online.
//

#import <Foundation/Foundation.h>
#import "JCReceiptVerifier.h"

@class JCLegacyReceiptVerifier;

//@protocol JCReceiptVerifierDelegate;

@interface JCLegacyReceiptVerifier : NSObject

@property (weak, nonatomic) id<JCReceiptVerifierDelegate> delegate;

- (void)verifyLatestReceipt;
- (void)verifyReceipt:(NSData *)receipt;
- (void)clearPurchaseInfo;

@end

@interface JCURLConnection : NSURLConnection

@property (strong, nonatomic) NSData *receipt;
@property (strong, nonatomic) NSMutableData *data;
@property (nonatomic) BOOL usingAppleServer;

@end


